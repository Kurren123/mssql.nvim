local downloader = require("mssql.tools_downloader")
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
		cmd = { opts.tools_file or default_path },
		filetypes = { "sql" },
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

local function setup_async(opts)
	local default_opts = {
		data_dir = joinpath(vim.fn.stdpath("data"), "/mssql.nvim"):gsub("[/\\]+$", ""),
		tools_file = nil,
	}
	opts = vim.tbl_deep_extend("keep", opts or {}, default_opts)

	-- if the opts specify a tools file path, don't download.
	if opts.tools_file then
		local file = io.open(opts.tools_file, "r")
		if not file then
			error("No sql tools file found at " .. opts.tools_file)
		end
		file:close()
	else
		make_directory(opts.data_dir)
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
end

return {
	setup = function(opts, callback)
		coroutine.resume(coroutine.create(function()
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
}
