local downloader = require("mssql.tools_downloader")
local utils = require("mssql.utils")
local display_query_results = require("mssql.display_query_results")
local query_manager_module = require("mssql.query_manager")
local interface = require("mssql.interface")
local default_opts = require("mssql.default_opts")
local finder = require("mssql.find_object")

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

local function clean_cache()
	local in_use_connections = {}
	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		local qm = vim.b[buf].query_manager
		if vim.api.nvim_buf_is_loaded(buf) and qm and qm.get_state() ~= query_manager_module.states.Disconnected then
			table.insert(in_use_connections, qm.get_connect_params().connection.options)
		end
	end
	finder.delete_unused_cache(in_use_connections)
end

local lsp_name = "mssql_ls"
local function enable_lsp(opts)
	local default_path = joinpath(opts.data_dir, "sqltools/MicrosoftSqlToolsServiceLayer")
	if jit.os == "Windows" then
		default_path = default_path .. ".exe"
	end

	-- sometimes two of these come at once, so hide for 1s
	local hide_intellisense_ready = false

	local config = {
		cmd = {
			opts.tools_file or default_path,
			"--enable-connection-pooling",
			"--enable-sql-authentication-provider",
			"--log-file",
			joinpath(opts.data_dir, "sqltools.log"),
			"--application-name",
			"neovim",
			"--data-path",
			joinpath(opts.data_dir, "sql-tools-data"),
		},
		filetypes = { "sql" },
		handlers = {
			["textDocument/intelliSenseReady"] = function(err, result)
				if err then
					utils.log_error("Could not start intellisense: " .. vim.inspect(err))
				else
					if not hide_intellisense_ready then
						hide_intellisense_ready = true
						utils.log_info("Intellisense ready")
						vim.defer_fn(function()
							hide_intellisense_ready = false
						end, 1000)
					end
				end
				return result, err
			end,

			["query/complete"] = function(_, result)
				if not (result and result.params and result.params.ownerUri) then
					return
				end
				local bufnr = vim.iter(vim.api.nvim_list_bufs()):find(function(buf)
					return utils.lsp_file_uri(buf) == result.params.ownerUri
				end)

				if not (bufnr and vim.b[bufnr].query_manager) then
					return
				end

				if bufnr and vim.b[bufnr].query_manager then
					local qm = vim.b[bufnr].query_manager
					if qm.handle_query_complete then
						qm.handle_query_complete(result.params)
					end
				end
			end,
			["query/message"] = function(_, result)
				if not (result and result.message and result.message.message) then
					return
				end

				-- handles "rows affected" from UPDATE, INSERT, and DELETE statements
				local bufnr = vim.iter(vim.api.nvim_list_bufs()):find(function(buf)
					return utils.lsp_file_uri(buf) == result.ownerUri
				end)
				if bufnr and vim.b[bufnr].query_manager then
					local qm = vim.b[bufnr].query_manager
					if qm.handle_query_message then
						qm.handle_query_message(result)
					end
				end

				opts.view_messages_in(result.message.message, result.message.isError)
			end,
			["connection/connectionchanged"] = function(_, result, _)
				if not result.ownerUri then
					return
				end
				local bufnr = vim.iter(vim.api.nvim_list_bufs()):find(function(buf)
					return utils.lsp_file_uri(buf) == result.ownerUri
				end)
				if not bufnr then
					return
				end
				local qm = vim.b[bufnr].query_manager
				if not (result and result.connection and qm) then
					return
				end

				coroutine.resume(coroutine.create(function()
					qm.connectionchanged_async(result)
				end))

				clean_cache()
			end,
		},
		on_attach = function(client, bufnr)
			if not vim.b[bufnr].query_manager then
				vim.b[bufnr].query_manager = query_manager_module.create_query_manager(bufnr, client)
			end

			-- see the wait_for_on_attach_async function below
			if vim.b[bufnr].on_attach_handlers then
				for _, handler in ipairs(vim.b[bufnr].on_attach_handlers) do
					handler(client)
				end
				vim.b[bufnr].on_attach_handlers = {}
			end
		end,
	}

	if opts.lsp_settings then
		config.settings = { mssql = opts.lsp_settings }
	end

	vim.lsp.config[lsp_name] = config
	vim.lsp.enable("mssql_ls")
end

---Waits for the lsp attach to the given buffer, with optional timeout.
---Must be run inside a coroutine.
---@param bufnr_to_watch integer
---@param timeout integer
---@return vim.lsp.Client
local function wait_for_on_attach_async(bufnr_to_watch, timeout)
	-- if it's already attach, return
	local existing_client = vim.lsp.get_clients({ name = lsp_name, bufnr = bufnr_to_watch })[1]
	if existing_client then
		return existing_client
	end

	local this = coroutine.running()
	local resumed = false

	local on_attach_handler = function(client)
		if not resumed then
			resumed = true
			utils.try_resume(this, client)
		end
	end

	if not vim.b[bufnr_to_watch].on_attach_handlers then
		vim.b[bufnr_to_watch].on_attach_handlers = { on_attach_handler }
	else
		table.insert(vim.b[bufnr_to_watch].on_attach_handlers, on_attach_handler)
	end

	vim.defer_fn(function()
		if not resumed then
			resumed = true
			utils.log_error("Waiting for the lsp to attach to buffer " .. bufnr_to_watch .. " timed out")
		end
	end, timeout)

	return coroutine.yield()
end

local function set_auto_commands(opts)
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

	if opts.sql_buffer_options and opts.sql_buffer_options ~= {} then
		vim.api.nvim_create_autocmd("FileType", {
			pattern = "sql",
			callback = function()
				-- copy all properties
				for k, v in pairs(opts.sql_buffer_options) do
					vim.bo[k] = v
				end
			end,
		})
	end

	-- clean the sql object cache on buffer close
	-- use the BufWipeout auto command so that at that point the buffer is not loaded
	vim.api.nvim_create_autocmd("BufDelete", {
		callback = function(args)
			local buf = args.buf
			if vim.b[buf].query_manager then
				vim.b[buf].query_manager = nil
				vim.schedule(function()
					clean_cache()
				end)
			end
		end,
	})
end

local plugin_opts

local mssql_window
local show_results_buffer_options = {
	current_window = function(bufnr)
		vim.api.nvim_set_option_value("buflisted", true, { buf = bufnr })
		vim.api.nvim_set_current_buf(bufnr)
	end,
	split = function(bufnr)
		local original_window = vim.api.nvim_get_current_win()

		-- open a split if we haven't done already
		if not (mssql_window and vim.api.nvim_win_is_valid(mssql_window)) then
			vim.cmd("split")
			mssql_window = vim.api.nvim_get_current_win()
		end

		vim.api.nvim_set_option_value("buflisted", true, { buf = bufnr })
		vim.api.nvim_win_set_buf(mssql_window, bufnr)
		vim.api.nvim_set_current_win(original_window)
	end,
	vsplit = function(bufnr)
		local original_window = vim.api.nvim_get_current_win()

		-- open a split if we haven't done already
		if not (mssql_window and vim.api.nvim_win_is_valid(mssql_window)) then
			vim.cmd("vsplit")
			mssql_window = vim.api.nvim_get_current_win()
		end

		vim.api.nvim_set_option_value("buflisted", true, { buf = bufnr })
		vim.api.nvim_win_set_buf(mssql_window, bufnr)
		vim.api.nvim_set_current_win(original_window)
	end,
}

-- If the open_results_in is a string, sets it to the appropriate function
local function set_show_results_option(opts)
	if type(opts.open_results_in) == "string" and show_results_buffer_options[opts.open_results_in] then
		opts.open_results_in = show_results_buffer_options[opts.open_results_in]
	elseif type(opts.open_results_in) == "function" then
		return
	else
		utils.log_error(
			vim.inspect(opts.open_results_in)
				.. " is not a valid option for open_results_in. Must be one of: "
				.. table.concat(vim.tbl_keys(show_results_buffer_options), ", ")
				.. ", or a function"
		)
	end
end

local message_buffer
local message_buffer_error_ns = vim.api.nvim_create_namespace("mssql_error_highlight")
local clear_message_buffer = function()
	if message_buffer and vim.api.nvim_buf_is_valid(message_buffer) then
		vim.api.nvim_set_option_value("modifiable", true, { buf = message_buffer })
		vim.api.nvim_buf_set_lines(message_buffer, 0, -1, false, {})
		vim.api.nvim_set_option_value("modifiable", false, { buf = message_buffer })
	end
end

local view_message_options = {
	notification = function(message, is_error)
		if is_error then
			utils.log_error(message)
		else
			utils.log_info(message)
		end
	end,
	buffer = function(message, is_error)
		if not (message_buffer and vim.api.nvim_buf_is_valid(message_buffer)) then
			message_buffer = vim.api.nvim_create_buf(false, false)
			vim.api.nvim_buf_set_name(message_buffer, "sql messages")
			vim.api.nvim_set_option_value("buftype", "nofile", { buf = message_buffer })
			vim.api.nvim_set_option_value("bufhidden", "hide", { buf = message_buffer })
			vim.api.nvim_set_option_value("swapfile", false, { buf = message_buffer })
			vim.api.nvim_set_option_value("readonly", true, { buf = message_buffer })
			vim.api.nvim_set_option_value("modifiable", false, { buf = message_buffer })
			plugin_opts.open_results_in(message_buffer)
		end
		-- Append a line at the end
		local lines = vim.api.nvim_buf_line_count(message_buffer)
		vim.api.nvim_set_option_value("modifiable", true, { buf = message_buffer })
		local message_lines = vim.split(message:gsub("\r", ""), "\n")
		vim.api.nvim_buf_set_lines(message_buffer, lines, lines, false, message_lines)

		-- Apply the 'Error' highlight group to the line
		if is_error then
			vim.api.nvim_buf_set_extmark(message_buffer, message_buffer_error_ns, lines, 0, {
				end_row = lines + #message_lines,
				hl_group = "Error",
			})
		end

		vim.api.nvim_set_option_value("modifiable", false, { buf = message_buffer })
	end,
}

-- if the view_messages_in option is a string, sets it to the appropriate function
local function set_view_message_option(opts)
	if type(opts.view_messages_in) == "string" and view_message_options[opts.view_messages_in] then
		opts.view_messages_in = view_message_options[opts.view_messages_in]
	elseif type(opts.view_messages_in) == "function" then
		return
	else
		utils.log_error(
			vim.inspect(opts.view_messages_in)
				.. " is not a valid option for view_messages_in. Must be one of: "
				.. table.concat(vim.tbl_keys(view_message_options), ", ")
				.. ", or a function"
		)
	end
end

local function setup_async(opts)
	opts = opts or {}
    -- ensure that we use user's custom icons if configured, but validate are only single character
    if opts.icons then
        opts.icons = vim.tbl_deep_extend("force", default_opts.icons, opts.icons)
        for key, icon in pairs(opts.icons) do
            if key ~= "enabled" and type(icon) == "string" and vim.fn.strchars(icon) > 1 then
                utils.log_warn("Icon '" .. key .. "' should be a single character, got: " .. icon)
            end
        end
    end
	opts = vim.tbl_deep_extend("keep", opts or {}, default_opts)
	opts.connections_file = opts.connections_file or joinpath(opts.data_dir, "connections.json")
	set_show_results_option(opts)
	set_view_message_option(opts)

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
	set_auto_commands(opts)

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

local function switch_database_async(buf)
	if buf == nil then
		buf = vim.api.nvim_get_current_buf()
	end
	local query_manager = vim.b[buf].query_manager
	if not query_manager then
		error("No mssql lsp is attached. Create a new query or open an exising one.", 0)
	end
	if query_manager.get_state() ~= query_manager_module.states.Connected then
		error("You need to connect first", 0)
	end
	local client = query_manager.get_lsp_client()

	local result, err =
		utils.lsp_request_async(client, "connection/listdatabases", { ownerUri = utils.lsp_file_uri(buf) })

	if err then
		error("Error listing databases: " .. err.message, 0)
	elseif not (result or result.databaseNames) then
		error("Could not list databases", 0)
	end

	local db = utils.ui_select_async(result.databaseNames, { prompt = "Choose database" })
	utils.safe_assert(db, "No database chosen")

	-- get the connect params first, because they get set
	-- to nil when we disconnect
	local connect_params = query_manager.get_connect_params()
	-- disconnect, change the database and connect again
	query_manager.disconnect_async()

	connect_params.connection.options.database = db

	query_manager.connect_async(connect_params)
	utils.log_info("Connected")
end

local connect_async = function(opts, query_manager)
	local json = get_connections(opts)
	if not json then
		edit_connections(opts)
		return
	end

	local con_name = utils.ui_select_async(vim.tbl_keys(json), { prompt = "Choose connection" })
	if not con_name then
		utils.log_info("No connection chosen")
		return
	end

	local con = json[con_name]

	if con.promptForPassword then
		con.password = vim.fn.inputsecret("password for " .. (con.server or ""))
	end

	local connectParams = {
		connection = {
			options = con,
		},
	}

	query_manager.connect_async(connectParams)

	if con.promptForDatabase then
		switch_database_async()
	else
		utils.log_info("Connected")
	end
end

local function new_query_async()
	-- The langauge server requires all files to have a file name.
	-- Vscode names new files "untitled-1" etc so we'll do the same
	vim.cmd("enew")
	local buf = vim.api.nvim_get_current_buf()
	vim.cmd("file untitled-" .. buf .. ".sql")
	vim.cmd("setfiletype sql")
	vim.b[buf].is_temp_name = true

	local client = wait_for_on_attach_async(buf, 10000)
	return buf, client
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

	local buf = new_query_async()
	local query_manager = vim.b[buf].query_manager
	if not query_manager then
		error("CRITICAL: Lsp attached without query manager")
	end

	if connection.promptForPassword then
		connection.password = vim.fn.inputsecret("password for " .. (connection.server or ""))
	end

	local connectParams = {
		connection = {
			options = connection,
		},
	}

	query_manager.connect_async(connectParams)

	if connection.promptForDatabase then
		switch_database_async(buf)
	else
		utils.log_info("Connected")
	end
	query_manager.initialise_cache_async()
end

--- If the current buffer is empty, put the query into this buffer. Otherwise,
--- Open a new buffer with the same connection and put the query there
local function insert_query_into_buffer(query)
	if vim.trim(table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false))) == "" then
		vim.api.nvim_buf_set_lines(0, 0, 0, false, vim.split(query, "\n"))
		return 0
	end

	local query_manager = vim.b.query_manager
	if not query_manager then
		error("Connect to a database first", 0)
	end

	local connect_params = query_manager.get_connect_params()
	local buf = new_query_async()
	query_manager = vim.b[buf].query_manager
	query_manager.connect_async(connect_params)
	vim.api.nvim_buf_set_lines(buf, 0, 0, false, vim.split(query, "\n"))
	return buf
end

local function backup_database_async(query_manager)
	if query_manager.get_state() ~= query_manager_module.states.Connected then
		error("Connect to a database first", 0)
	end
	local connect_params = query_manager.get_connect_params()
	if
		not (
			connect_params
			and connect_params.connection
			and connect_params.connection.options
			and connect_params.connection.options.database
		)
	then
		error("No connection found", 0)
	end
	local database = connect_params.connection.options.database
	local dir = vim.fs.joinpath(vim.fn.getcwd(), database .. ".bak")
	local query = string.format(
		[[BACKUP DATABASE [%s]
-- Change to your backup location
TO DISK = N'%s'
WITH 
INIT, -- Remove if not overwriting
STATS = 25]],
		database,
		dir
	)

	insert_query_into_buffer(query)
end

local function restore_database_async(query_manager)
	if query_manager.get_state() ~= query_manager_module.states.Connected then
		error("Connect to a server first", 0)
	end

	local file = vim.fn.input("Enter .bak file path:", "", "file")
	if not file or file == "" then
		error("No file chosen", 0)
	end

	local internal_files =
		utils.get_query_result_async(query_manager.execute_async("RESTORE FILELISTONLY FROM DISK = '" .. file .. "'"))

	local headers =
		utils.get_query_result_async(query_manager.execute_async("RESTORE HEADERONLY FROM DISK = '" .. file .. "'"))[1]

	local database = headers.DatabaseName

	local size = tonumber(headers.BackupSize)
	local stats = 25
	if size <= 2000000000 then -- <= 2GB
		stats = 25
	else
		stats = 10
	end

	local data_path = utils.get_query_result_async(
		query_manager.execute_async("SELECT SERVERPROPERTY('InstanceDefaultDataPath') AS DefaultDataPath")
	)[1].DefaultDataPath

	local moves = vim.iter(internal_files)
		:map(function(file)
			return "MOVE N'"
				.. file.LogicalName
				.. "' TO N'"
				.. vim.fs.joinpath(data_path, vim.fs.basename(file.PhysicalName))
				.. "',"
		end)
		:join("\n")

	local query = string.format(
		[[-- WARNING: Read and understand this before executing!
USE [master]
ALTER DATABASE [%s] SET SINGLE_USER WITH ROLLBACK IMMEDIATE -- drop connections
RESTORE DATABASE [%s] FROM  DISK = N'%s' WITH
FILE = 1,
%s
REPLACE, -- overwrite existing
STATS = %s
ALTER DATABASE [%s] SET MULTI_USER]],
		database,
		database,
		file,
		moves,
		stats,
		database
	)

	insert_query_into_buffer(query)
end

local function connect_to_default(query_manager, opts)
	utils.wait_for_schedule_async()

	local connections = get_connections(opts)
	if not (connections and connections.default) then
		utils.log_info("Add a connection called 'default'")
		edit_connections(opts)
		return
	end

	local connection = connections.default

	if connection.promptForPassword then
		connection.password = vim.fn.inputsecret("password for " .. (connection.server or ""))
	end

	local connectParams = {
		connection = {
			options = connection,
		},
	}

	query_manager.connect_async(connectParams)

	if connection.promptForDatabase then
		switch_database_async()
	else
		utils.log_info("Connected")
	end
end

local function save_query_results_async(result_info)
	utils.wait_for_schedule_async()
	local success, lsp_client = pcall(utils.get_lsp_client, result_info.subset_params.ownerUri)
	if not success then
		error("The buffer with the sql query has been closed, can't save query results")
	end

	local file = vim.fn.input("Save query results (.csv/.json/.xls/.xlsx/.xml)", "", "file")
	if not file or file == "" then
		utils.log_error("No file path given")
		return
	end

	local params = {
		FilePath = file,
		BatchIndex = result_info.subset_params.batchIndex,
		ResultSetIndex = result_info.subset_params.resultSetIndex,
		OwnerUri = result_info.subset_params.ownerUri,
		IncludeHeaders = true,
		Formatted = true,
	}

	local method
	local openAfterSave = true
	if file:match("%.csv$") then
		method = "query/saveCsv"
	elseif file:match("%.json$") then
		method = "query/saveJson"
	elseif file:match("%.xml$") then
		method = "query/saveXml"
	elseif file:match("%.xls$") or file:match("%.xlsx$") then
		method = "query/saveExcel"
		openAfterSave = false
	else
		utils.log_error("File extension not recognised. Enter a file with extension .csv/.json/.xls/.xlsx/.xml")
		return
	end

	local _, err = utils.lsp_request_async(lsp_client, method, params)

	if err then
		utils.log_error("Error saving query results")
		utils.log_error(vim.inspect(err))
		return
	end

	utils.log_info("File saved")

	if openAfterSave then
		vim.cmd("edit " .. file)
	end
end

local show_caching_in_status_line = false

local M = {
	new_query = function()
		utils.try_resume(coroutine.create(function()
			new_query_async()
		end))
	end,

	-- Look for the connection called "default", prompt to choose a database in that server,
	-- connect to that database and open a new buffer for querying (very useful!)
	new_default_query = function()
		utils.try_resume(coroutine.create(function()
			new_default_query_async(plugin_opts)
		end))
	end,

	-- Prompts for a database to switch to that is on the currently
	-- connected server
	switch_database = function(callback)
		local query_manager = vim.b.query_manager
		if not query_manager then
			utils.log_error("No mssql lsp is attached. Create a new query or open an exising one.")
			return
		end
		utils.try_resume(coroutine.create(function()
			switch_database_async()
			query_manager.initialise_cache_async()
			clean_cache()
			if callback then
				callback()
			end
		end))
	end,

	-- Connect the current buffer (you'll be prompted to choose a connection)
	connect = function()
		local query_manager = vim.b.query_manager
		if not query_manager then
			utils.log_error("No mssql lsp is attached. Create a new query or open an exising one.")
			return
		end
		utils.try_resume(coroutine.create(function()
			connect_async(plugin_opts, query_manager)
			query_manager.initialise_cache_async()
		end))
	end,

	edit_connections = function()
		edit_connections(plugin_opts)
	end,

	-- Rebuilds the sql object and intellisense cache
	refresh_cache = function()
		local query_manager = vim.b.query_manager
		if not query_manager then
			utils.log_error("No mssql lsp is attached. Create a new query or open an exising one.")
			return
		end
		if query_manager.get_state() ~= query_manager_module.states.Connected then
			utils.log_error("You are currently " .. query_manager.get_state())
			return
		end
		-- refresh the object cache, fire and forget
		show_caching_in_status_line = true

		coroutine.resume(coroutine.create(function()
			query_manager.initialise_cache_async(true)
			show_caching_in_status_line = false
			vim.cmd("redrawstatus")
		end))

		-- refresh the intellisense cache, fire and forget
		local success, msg = pcall(function()
			local client = query_manager.get_lsp_client()
			client:notify("textDocument/rebuildIntelliSense", { ownerUri = utils.lsp_file_uri() })
		end)
		if not success then
			utils.log_error(msg)
		end
		utils.log_info("Refreshing cache...")
	end,

	disconnect = function()
		local query_manager = vim.b.query_manager
		if not query_manager then
			utils.log_error("No mssql lsp is attached. Create a new query or open an exising one.")
			return
		end
		utils.try_resume(coroutine.create(function()
			query_manager.disconnect_async()
			clean_cache()
		end))
	end,

	execute_query = function()
		local query_manager = vim.b.query_manager
		if not query_manager then
			utils.log_error("No mssql lsp is attached. Create a new query or open an exising one.")
			return
		end
		utils.try_resume(coroutine.create(function()
			local query = utils.get_selected_text()
			if query_manager.get_state() == query_manager_module.states.Disconnected then
				connect_to_default(query_manager, plugin_opts)
			end
			clear_message_buffer()
			local result = query_manager.execute_async(query)
			if result then -- since cancelled query returns nil, have to check for nil before displaying
				display_query_results(plugin_opts, result)
			end
		end))
	end,

	cancel_query = function()
		local query_manager = vim.b.query_manager
		if not query_manager then
			utils.log_error("No mssql lsp is attached. Create a new query or open an existing one.")
			return
		end
		utils.try_resume(coroutine.create(function()
			query_manager.cancel_async()
		end))
	end,

	lualine_component = {
		function()
			local qm = vim.b.query_manager
			if not qm then
				return
			end
			local state = qm.get_state()

			if state == query_manager_module.states.Disconnected then
				local disconnected_icon = plugin_opts.icons.enabled and plugin_opts.icons.disconnected .. " " or ""
				return disconnected_icon .. "Connect to MSSQL"
			elseif state == query_manager_module.states.Connecting then
				return "Connecting..."
			end

			local status_parts = {}
			local exec_info = qm.last_execution()
			local connect_params = qm.get_connect_params()

			local server_db_string = ""
			if connect_params and connect_params.connection and connect_params.connection.options then
				local server = connect_params.connection.options.server
				local db = connect_params.connection.options.database
				if db and server then
					local db_icon, server_icon = "", ""
					if plugin_opts.icons.enabled then
						server_icon = plugin_opts.icons.server .. " "
						db_icon = " " .. plugin_opts.icons.database .. " "
						server_db_string = server_icon .. server .. db_icon .. db
					else
						server_db_string = server .. " | " .. db
					end
				end
			end

			if state == query_manager_module.states.Executing then
				table.insert(status_parts, server_db_string)
				table.insert(status_parts, "Executing...")
				if exec_info.elapsed_time then
					table.insert(status_parts, utils.format_elapsed_time_to_string(exec_info.elapsed_time, false))
				end
			else -- Connected state (after completion, cancellation, or idle)
				if exec_info.rows_affected ~= nil then
					local rows_text = exec_info.rows_affected == 1 and "row" or "rows"
					table.insert(status_parts, string.format("%d %s affected", exec_info.rows_affected, rows_text))
				end
				if exec_info.elapsed_time and exec_info.elapsed_time > 0 then
					table.insert(status_parts, utils.format_elapsed_time_to_string(exec_info.elapsed_time, true))
				end
				table.insert(status_parts, server_db_string)
			end

			if show_caching_in_status_line and qm.is_refreshing() then
				table.insert(status_parts, "(Caching database objects...)")
			end

			return table.concat(status_parts, "  ")
		end,
		cond = function()
			return vim.b.query_manager ~= nil
		end,
	},

	backup_database = function()
		local query_manager = vim.b.query_manager
		if not query_manager then
			utils.log_error("No mssql lsp is attached. Create a new query or open an existing one.")
			return
		end
		utils.try_resume(coroutine.create(function()
			backup_database_async(query_manager)
		end))
	end,

	restore_database = function()
		local query_manager = vim.b.query_manager
		if not query_manager then
			utils.log_error("No mssql lsp is attached. Create a new query or open an existing one.")
			return
		end
		utils.try_resume(coroutine.create(function()
			restore_database_async(query_manager)
		end))
	end,

	save_query_results = function()
		local result_info = vim.b.query_result_info
		if not result_info then
			utils.log_error("Go to a query result buffer to save results")
			return
		end
		utils.try_resume(coroutine.create(function()
			save_query_results_async(result_info)
		end))
	end,

	find_object = function(callback)
		local query_manager = vim.b.query_manager
		if not query_manager then
			utils.log_error("No mssql lsp is attached. Create a new query or open an exising one.")
			return
		end
		if query_manager.get_state() ~= query_manager_module.states.Connected then
			utils.log_error("You are currently " .. query_manager.get_state())
			return
		end

		if query_manager.is_refreshing() then
			show_caching_in_status_line = true
			vim.cmd("redrawstatus")
			utils.log_error("Still caching. Try again in a few seconds...")
			return
		end

		show_caching_in_status_line = false
		vim.cmd("redrawstatus")

		utils.try_resume(coroutine.create(function()
			local item = query_manager.find_async()
			if not item then
				return
			end
			local buf = insert_query_into_buffer(item.script)
			query_manager = vim.b[buf].query_manager
			if plugin_opts.execute_generated_select_statements and item.select then
				clear_message_buffer()
				local result = query_manager.execute_async(item.script)
				display_query_results(plugin_opts, result)
			end
			if callback then
				callback()
			end
		end))
	end,
}

M.set_keymaps = function(prefix)
	interface.set_keymaps(prefix, M)
end

M.setup = function(opts, callback)
	utils.try_resume(coroutine.create(function()
		setup_async(opts)
		interface.set_user_commands(M)
		interface.set_keymaps(opts.keymap_prefix, M)
		if callback ~= nil then
			callback()
		end
	end))
end

return M
