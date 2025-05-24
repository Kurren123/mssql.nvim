local downloader = require("mssql.tools_downloader")
local utils = require("mssql.utils")
local display_query_results = require("mssql.display_query_results")
local query_manager_module = require("mssql.query_manager")

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
			["query/message"] = function(_, result)
				if not (result or result.message or result.message.message) then
					return
				end

				if result.message.isError then
					utils.log_error(result.message.message)
				else
					utils.log_info(result.message.message)
				end
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
		keymap_prefix = nil,
		lsp_settings = nil,
		results_buffer_extension = "md",
		results_buffer_filetype = "markdown",
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
end

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
	switch_database = function()
		utils.try_resume(coroutine.create(function()
			switch_database_async()
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
		end))
	end,

	edit_connections = function()
		edit_connections(plugin_opts)
	end,

	-- Rebuilds the intellisense cache
	refresh_intellisense_cache = function()
		local success, msg = pcall(function()
			local client = utils.get_lsp_client()
			client:notify("textDocument/rebuildIntelliSense", { ownerUri = utils.lsp_file_uri() })
			utils.log_info("Refreshing intellisense...")
		end)
		if not success then
			utils.log_error(msg)
		end
	end,

	disconnect = function()
		local query_manager = vim.b.query_manager
		if not query_manager then
			utils.log_error("No mssql lsp is attached. Create a new query or open an exising one.")
			return
		end
		utils.try_resume(coroutine.create(function()
			query_manager.disconnect_async()
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
			local result = query_manager.execute_async(query)
			display_query_results(plugin_opts, result)
		end))
	end,

	setup = function(opts, callback)
		utils.try_resume(coroutine.create(function()
			setup_async(opts)
			if callback ~= nil then
				callback()
			end
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
				return "Disconnected"
			elseif state == query_manager_module.states.Connecting then
				return "Connecting..."
			elseif state == query_manager_module.states.Executing then
				return "Executing..."
			elseif state == query_manager_module.states.Connected then
				local connect_params = qm.get_connect_params()
				if not (connect_params and connect_params.connection and connect_params.connection.options) then
					return "Connected"
				end
				local db = connect_params.connection.options.database
				local server = connect_params.connection.options.server
				if not (db or server) then
					return "Connected"
				end

				return server .. " | " .. db
			end
		end,
		cond = function()
			return vim.b.query_manager ~= nil
		end,
	},
}

M.set_keymaps = function(prefix)
	if not prefix then
		return
	end

	local keymaps = {
		new_query = { "n", M.new_query, desc = "New Query", icon = { icon = "", color = "yellow" } },
		connect = { "c", M.connect, desc = "Connect", icon = { icon = "󱘖", color = "green" } },
		disconnect = { "q", M.disconnect, desc = "Disconnect", icon = { icon = "", color = "red" } },
		execute_query = {
			"x",
			M.execute_query,
			desc = "Execute Query",
			mode = { "n", "v" },
			icon = { icon = "", color = "green" },
		},
		edit_connections = {
			"e",
			M.edit_connections,
			desc = "Edit Connections",
			icon = { icon = "󰅩", color = "grey" },
		},
		refresh_intellisense = {
			"r",
			M.refresh_intellisense_cache,
			desc = "Refresh Intellisense",
			icon = { icon = "", color = "grey" },
		},
		new_default_query = {
			"d",
			M.new_default_query,
			desc = "New Default Query",
			icon = { icon = "", color = "yellow" },
		},
		switch_database = {
			"s",
			M.switch_database,
			desc = "Switch Database",
			icon = { icon = "", color = "yellow" },
		},
	}

	local success, wk = pcall(require, "which-key")
	if success then
		local wkeygroup = {
			prefix,
			group = "mssql",
			icon = { icon = "", color = "yellow" },
		}

		local normal_group = vim.tbl_deep_extend("keep", wkeygroup, {})
		normal_group.expand = function()
			local qm = vim.b.query_manager
			if not qm then
				return { keymaps.new_query, keymaps.new_default_query, keymaps.edit_connections }
			end

			local state = qm.get_state()
			local states = query_manager_module.states
			if state == states.Connecting or state == states.Executing then
				return {
					keymaps.new_query,
					keymaps.new_default_query,
					keymaps.edit_connections,
					keymaps.refresh_intellisense,
				}
			elseif state == states.Connected then
				return {
					keymaps.new_query,
					keymaps.new_default_query,
					keymaps.edit_connections,
					keymaps.refresh_intellisense,
					keymaps.execute_query,
					keymaps.disconnect,
					keymaps.switch_database,
				}
			elseif state == states.Disconnected then
				return {
					keymaps.new_query,
					keymaps.new_default_query,
					keymaps.edit_connections,
					keymaps.refresh_intellisense,
					keymaps.connect,
				}
			else
				utils.log_error("Entered unrecognised query state: " .. state)
				return {}
			end
		end

		wk.add(normal_group)

		local visual_group = vim.tbl_deep_extend("keep", wkeygroup, {})
		visual_group.mode = "v"
		visual_group.expand = function()
			local qm = vim.b.query_manager
			if not qm then
				return { keymaps.new_query, keymaps.new_default_query, keymaps.edit_connections }
			end

			local state = qm.get_state()
			local states = query_manager_module.states
			if state == states.Connecting or state == states.Executing or state == states.Disconnected then
				return {}
			elseif state == states.Connected then
				return { keymaps.execute_query }
			else
				utils.log_error("Entered unrecognised query state: " .. state)
				return {}
			end
		end

		wk.add(visual_group)
	else
		for _, m in pairs(keymaps) do
			vim.keymap.set(m.mode or "n", prefix .. m[1], m[2], { desc = m.desc })
		end
	end
end

return M
