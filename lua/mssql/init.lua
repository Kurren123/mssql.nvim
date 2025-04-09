local function read_json_file(path)
	local file = io.open(path, "r")
	if not file then
		return {}
	end
	local content = file:read("*a")
	file:close()
	local json = require("mssql.json")
	return json.decode(content)
end

local function get_tools_download_url()
	local urls = {
		Windows = {
			arm = "https://github.com/microsoft/sqltoolsservice/releases/download/5.0.20250408.3/Microsoft.SqlTools.ServiceLayer-win-arm64-net8.0.zip",
			x64 = "https://github.com/microsoft/sqltoolsservice/releases/download/5.0.20250408.3/Microsoft.SqlTools.ServiceLayer-win-x64-net8.0.zip",
			x86 = "https://github.com/microsoft/sqltoolsservice/releases/download/5.0.20250408.3/Microsoft.SqlTools.ServiceLayer-win-x86-net8.0.zip",
		},
		Linux = {
			arm = "https://github.com/microsoft/sqltoolsservice/releases/download/5.0.20250408.3/Microsoft.SqlTools.ServiceLayer-linux-arm64-net8.0.tar.gz",
			x64 = "https://github.com/microsoft/sqltoolsservice/releases/download/5.0.20250408.3/Microsoft.SqlTools.ServiceLayer-linux-x64-net8.0.tar.gz",
		},
		OSX = {
			arm = "https://github.com/microsoft/sqltoolsservice/releases/download/5.0.20250408.3/Microsoft.SqlTools.ServiceLayer-osx-arm64-net8.0.tar.gz",
			x64 = "https://github.com/microsoft/sqltoolsservice/releases/download/5.0.20250408.3/Microsoft.SqlTools.ServiceLayer-osx-x64-net8.0.tar.gz",
		},
	}

	local os = jit.os
	local arch = jit.arch

	if not urls[os] then
		error("Your OS " .. os .. " is not supported. It must be Windows, Linux or OSX.")
	end

	local url = urls[os][arch]
	if not url then
		error("Your system architecture " .. arch .. " is not supported. It can either be x64 or arm.")
	end

	return url
end

local function download_tools(url, target_folder)
	-- delete any existing download folder, download, unzip and write the most recent url to the config
	-- TODO: finish this
end

local M = {}

function M.Hello(name)
	return "Hello " .. name
end

function M.setup(opts)
	M.opts = opts or {}

	-- if the opts specify a tools file path, don't download.
	if not opts.tools_file then
		local data_dir = opts.data_dir or (vim.fn.stdpath("data") .. "/mssql.nvim")
		local config = read_json_file(data_dir .. "/config.json")
		local download_url = get_tools_download_url()

		-- download if it's a first time setup or the last downloaded is old
		if not config.last_downloaded_from or config.last_downloaded_from ~= download_url then
			download_tools(download_url, data_dir .. "/sqltools")
		end
	end
end

-- test lines
vim.opt.rtp:append("C:/dev/mssql.nvim/")

return M
