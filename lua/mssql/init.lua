local downloader = require("mssql.tools_downloader")
local utils = require("mssql.utils")

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
		error("Could not open file: " .. path)
	end
end

local function enable_lsp(opts)
	local default_path = joinpath(opts.data_dir, "sqltools/MicrosoftSqlToolsServiceLayer")
	if jit.os == "Windows" then
		default_path = default_path .. ".exe"
	end

	vim.lsp.config["mssql_ls"] = {
		cmd = {
			opts.tools_file or default_path,
			"--enable-connection-pooling",
			"--enable-sql-authentication-provider",
		},
		filetypes = { "sql" },
		handlers = {
			["connection/complete"] = function(_, result)
				if result.errorMessage then
					vim.notify("Could not connect: " .. result.errorMessage, vim.log.levels.ERROR)
				else
					vim.notify("Connected", vim.log.levels.INFO)
				end
			end,
		},
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
	}
	opts = vim.tbl_deep_extend("keep", opts or {}, default_opts)

	make_directory(opts.data_dir)

	-- if the opts specify a tools file path, don't download.
	if opts.tools_file then
		local file = io.open(opts.tools_file, "r")
		if not file then
			error("No sql tools file found at " .. opts.tools_file)
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

		enable_lsp(opts)
		set_auto_commands()
	end

	plugin_opts = opts
end

local edit_connections = function(opts)
	if vim.fn.filereadable(opts.connections_file) == 0 then
		vim.notify("Connections json file not found. Creating...", vim.log.levels.INFO)
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

local connect_async = function(opts)
	local client = assert(
		vim.lsp.get_clients({ name = "mssql_ls", bufnr = 0 })[1],
		"No MSSQL lsp client attached. Create a new sql query or open an existing sql file"
	)

	local f = io.open(opts.connections_file, "r")
	if not f then
		edit_connections(opts)
		return
	end

	local content = f:read("*a")
	f:close()
	local ok, json = pcall(vim.fn.json_decode, content)
	assert(
		ok and type(json) == "table" and not vim.islist(json),
		"The connections json file must contain a valid json object"
	)

	local con = utils.ui_select_async(vim.tbl_keys(json), { prompt = "Choose connection" })

	local connectParams = {
		ownerUri = vim.fn.expand("%:p"),
		connection = {
			options = json[con],
		},
	}

	local _, err = utils.lsp_request_async(client, "connection/connect", connectParams)
	if err then
		error("Could not connect: " .. err.message)
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
	new_query = function()
		-- The langauge server requires all files to have a file name.
		-- Vscode names new files "untitled-1" etc so we'll do the same
		vim.cmd("enew")
		local buf = vim.api.nvim_get_current_buf()
		vim.cmd("file untitled-" .. buf .. ".sql")
		vim.cmd("setfiletype sql")
		vim.b[buf].is_temp_name = true
	end,
	connect = function()
		utils.try_resume(coroutine.create(function()
			connect_async(plugin_opts)
		end))
	end,
	edit_connections = function()
		edit_connections(plugin_opts)
	end,
}
