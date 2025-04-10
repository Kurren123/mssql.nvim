local downloader = require("mssql.tools_downloader")

local joinpath = vim.fs.joinpath
-- creates the data directory if it doesn't exist, then returns it
local function get_data_directory(opts)
	local data_dir = opts.data_dir or joinpath(vim.fn.stdpath("data"), "/mssql.nvim")
	data_dir = data_dir:gsub("[/\\]+$", "")
	if vim.fn.isdirectory(data_dir) == 0 then
		vim.fn.mkdir(data_dir, "p")
	end
	return data_dir
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

local M = {}

function M.setup(opts)
	opts = opts or {}
	M.opts = opts

	-- if the opts specify a tools file path, don't download.
	if opts.tools_file then
		local file = io.open(opts.tools_file, "r")
		if not file then
			error("No sql tools file found at " .. opts.tools_file)
		end
		file:close()
	else
		local data_dir = get_data_directory(opts)
		local config_path = joinpath(data_dir, "config.json")
		local config = read_json_file(config_path)
		local download_url = downloader.get_tools_download_url()

		-- download if it's a first time setup or the last downloaded is old
		if not config.last_downloaded_from or config.last_downloaded_from ~= download_url then
			downloader.download_tools(download_url, data_dir, function()
				config.last_downloaded_from = download_url
				write_json_file(config_path, config)
			end)
		end
	end
end

return M
