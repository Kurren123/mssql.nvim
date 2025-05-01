local downloader = require("mssql.tools_downloader")
local utils = require("mssql.utils")
local query = require("mssql.query")

local joinpath = vim.fs.joinpath

-- creates the directory if it doesn't exist
local function make_directory(path)
	if vim.fn.isdirectory(path) == 0 then
		vim.fn.mkdir(path, "p")
	end
end

local function read_json_file(path)
	local file = io.open(path, "r")
	if not file then
		return {}
	end
	local content = file:read("*a")
	file:close()
	return vim.json.decode(content)
end

local function write_json_file(path, table)
	local file = io.open(path, "w")
	local text = vim.json.encode(table)
	if file then
		file:write(text)
		file:close()
	else
		error("Could not open file: " .. path, 0)
	end
end

local get_handlers = function()
	return {
		["connection/complete"] = function(_, result)
			if result.errorMessage then
				utils.log_error("Could not connect: " .. result.errorMessage)
				return result,
					vim.lsp.rpc.rpc_response_error(
						vim.lsp.protocol.ErrorCodes.UnknownErrorCode,
						result.errorMessage,
						nil
					)
			else
				utils.log_info("Connected")
				return result, nil
			end
		end,

		["textDocument/intelliSenseReady"] = function(err, result)
			if err then
				utils.log_error("Could not start intellisense: " .. vim.inspect(err))
			else
				utils.log_info("Intellisense ready")
			end
			return result, err
		end,
	}
end

local function enable_lsp(opts)
	local default_path = joinpath(opts.data_dir, "sqltools/MicrosoftSqlToolsServiceLayer")
	if jit.os == "Windows" then
		default_path = default_path .. ".exe"
	end

	local handlers = get_handlers()
	query.add_lsp_handlers(handlers, opts)

	vim.lsp.config["mssql_ls"] = {
		cmd = {
			opts.tools_file or default_path,
			"--enable-connection-pooling",
			"--enable-sql-authentication-provider",
		},
		filetypes = { "sql" },
		handlers = handlers,
	}

	vim.lsp.enable("mssql_ls")
end

local function set_auto_commands()
	vim.api.nvim_create_augroup("AutoNameSQL", { clear = true })

	-- Reset the buffer to the file name upon saving
	vim.api.nvim_create_autocmd("BufWritePost", {
		group = "AutoNameSQL",
		pattern = "*.sql",
		callback = function(args)
			local buf = args.buf
			if vim.b[buf].is_temp_name then
				local written_name = vim.fn.fnamemodify(vim.fn.expand("<afile>"), ":t")

				vim.cmd("file " .. written_name)
				vim.b[buf].is_temp_name = nil
			end
		end,
	})
end

local plugin_opts

local function setup_async(opts)
	opts = opts or {}
	local data_dir = opts.data_dir or joinpath(vim.fn.stdpath("data"), "/mssql.nvim"):gsub("[/\\]+$", "")
	local default_opts = {
		data_dir = data_dir,
		tools_file = nil,
		connections_file = joinpath(data_dir, "connections.json"),
		max_rows = 100,
		max_column_width = 100,
	}
	opts = vim.tbl_deep_extend("keep", opts or {}, default_opts)

	make_directory(opts.data_dir)

	-- if the opts specify a tools file path, don't download.
	if opts.tools_file then
		local file = io.open(opts.tools_file, "r")
		if not file then
			error("No sql tools file found at " .. opts.tools_file, 0)
		end
		file:close()
	else
		local config_file = joinpath(opts.data_dir, "config.json")
		local config = read_json_file(config_file)
		local download_url = downloader.get_tools_download_url()

		-- download if it's a first time setup or the last downloaded is old
		if not config.last_downloaded_from or config.last_downloaded_from ~= download_url then
			downloader.download_tools_async(download_url, opts.data_dir)
			config.last_downloaded_from = download_url
			write_json_file(config_file, config)
		end
	end

	enable_lsp(opts)
	set_auto_commands()
	plugin_opts = opts
end

local edit_connections = function(opts)
	if vim.fn.filereadable(opts.connections_file) == 0 then
		utils.log_info("Connections json file not found. Creating...")
		local default_connections = [=[
{
  "Example (edit this)": {
    "server": "localhost",
    "database": "master",
    "authenticationType" : "SqlLogin",
    "user" : "Admin",
    "password" : "Your_Password",
    "trustServerCertificate" : true
  }
}
]=]
		vim.fn.writefile(vim.split(default_connections, "\n"), opts.connections_file)
	end
	vim.cmd.edit(opts.connections_file)
end

local function get_connections(opts)
	local f = io.open(opts.connections_file, "r")
	if not f then
		return nil
	end

	local content = f:read("*a")
	f:close()
	local ok, json = pcall(vim.fn.json_decode, content)
	utils.safe_assert(
		ok and type(json) == "table" and not vim.islist(json),
		"The connections json file must contain a valid json object"
	)
	return json
end

local connect_async = function(opts)
	-- Check for an lsp client before prompting the user for connection
	local client = utils.get_lsp_client()
	local json = get_connections(opts)
	if not json then
		edit_connections(opts)
		return
	end

	local con = utils.ui_select_async(vim.tbl_keys(json), { prompt = "Choose connection" })
	if not con then
		utils.log_info("No connection chosen")
		return
	end

	local connectParams = {
		ownerUri = vim.uri_from_fname(vim.fn.expand("%:p")),
		connection = {
			options = json[con],
		},
	}

	local _, err = utils.lsp_request_async(client, "connection/connect", connectParams)
	if err then
		error("Could not connect: " .. err.message, 0)
	end
end

local function new_query()
	-- The langauge server requires all files to have a file name.
	-- Vscode names new files "untitled-1" etc so we'll do the same
	vim.cmd("enew")
	local buf = vim.api.nvim_get_current_buf()
	vim.cmd("file untitled-" .. buf .. ".sql")
	vim.cmd("setfiletype sql")
	vim.b[buf].is_temp_name = true
end

local function new_default_query_async(opts)
	utils.wait_for_schedule_async()

	local connections = get_connections(opts)
	if not (connections and connections.default) then
		utils.log_info("Add a connection called 'default'")
		edit_connections(opts)
		return
	end
	local connection = connections.default

	new_query()

	-- poll for client
	local client
	for _ = 1, 20 do
		utils.defer_async(100)
		client = vim.lsp.get_clients({ name = "mssql_ls", bufnr = 0 })[1]
		if client then
			break
		end
	end
	if not client then
		error("No lsp is attaching", 0)
	end

	local ownerUri = vim.uri_from_fname(vim.fn.expand("%:p"))

	local connectParams = {
		ownerUri = ownerUri,
		connection = {
			options = connection,
		},
	}
	local result, err
	_, err = utils.lsp_request_async(client, "connection/connect", connectParams)
	if err then
		error("Could not connect: " .. err.message, 0)
	end

	utils.wait_for_handler_async("connection/complete", 3000)

	result, err = utils.lsp_request_async(client, "connection/listdatabases", { ownerUri = ownerUri })

	if err then
		error("Error listing databases: " .. err.message, 0)
	elseif not (result or result.databaseNames) then
		error("Could not list databases", 0)
	end

	local db = utils.ui_select_async(result.databaseNames, { prompt = "Choose database" })
	if not db then
		utils.log_info("No database chosen. Using default")
		return
	end

	-- disconnect, change the database and connect again
	utils.lsp_request_async(client, "connection/disconnect", { ownerUri = ownerUri })

	connection.database = db
	connectParams = {
		ownerUri = ownerUri,
		connection = {
			options = connection,
		},
	}
	_, err = utils.lsp_request_async(client, "connection/connect", connectParams)
	if err then
		error("Could not connect: " .. err.message, 0)
	end
end

local disconnect_async = function()
	local client = utils.get_lsp_client()
	local result, err = utils.lsp_request_async(
		client,
		"connection/disconnect",
		{ ownerUri = vim.uri_from_fname(vim.fn.expand("%:p")) }
	)
	if err then
		error("Error disconnecting: " .. err.message, 0)
	elseif not result then
		error("Could not disconnect", 0)
	else
		utils.log_info("Disconnected")
	end
end

return {
	setup = function(opts, callback)
		utils.try_resume(coroutine.create(function()
			setup_async(opts)
			if callback ~= nil then
				callback()
			end
		end))
	end,
	new_query = new_query,

	-- Look for the connection called "default", prompt to choose a database in that server,
	-- connect to that database and open a new buffer for querying (very useful!)
	new_default_query = function()
		utils.try_resume(coroutine.create(function()
			new_default_query_async(plugin_opts)
		end))
	end,

	-- Connect the current buffer (you'll be prompted to choose a connection)
	connect = function()
		utils.try_resume(coroutine.create(function()
			connect_async(plugin_opts)
		end))
	end,

	edit_connections = function()
		edit_connections(plugin_opts)
	end,

	-- Rebuilds the intellisense cache
	refresh_intellisense_cache = function()
		local client = utils.get_lsp_client()
		client:notify("textDocument/rebuildIntelliSense", { ownerUri = vim.uri_from_fname(vim.fn.expand("%:p")) })
		utils.log_info("Refreshing intellisense...")
	end,

	disconnect = function()
		utils.try_resume(coroutine.create(function()
			disconnect_async()
		end))
	end,

	execute_query = function()
		utils.try_resume(coroutine.create(function()
			query.execute_async()
		end))
	end,
}
