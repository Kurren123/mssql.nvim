local json = require("mssql.json")

-- creates the data directory if it doesn't exist, then returns it
local function get_data_directory(opts)
	local data_dir = opts.data_dir or (vim.fn.stdpath("data") .. "/mssql.nvim")
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
	return json.decode(content)
end

local function write_json_file(path, table)
	local file = io.open(path, "w")
	local text = json.encode(table)
	if file then
		file:write(text)
		file:close()
	else
		error("Could not open file: " .. path)
	end
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

-- delete any existing download folder, download, unzip and write the most recent url to the config
local function download_tools(url, data_folder, callback)
	local target_folder = data_folder .. "/sqltools"

	local download_job
	if jit.os == "Windows" then
		local temp_file = data_folder .. "/temp.zip"
		-- Turn off the progress bar to speed up the download
		download_job = {
			"powershell",
			"-Command",
			string.format(
				[[
          $ErrorActionPreference = 'Stop'
          $ProgressPreference = 'SilentlyContinue'
          Invoke-WebRequest %s -OutFile "%s"
          if (Test-Path -LiteralPath "%s") { Remove-Item -LiteralPath "%s" -Recurse }
          Expand-Archive "%s" "%s"
          Remove-Item "%s"
          $ProgressPreference = 'Continue'
        ]],
				url,
				temp_file,
				target_folder,
				target_folder,
				temp_file,
				target_folder,
				temp_file
			),
		}
	else
		local temp_file = data_folder .. "/temp.gz"
		download_job = {
			"bash",
			"-c",
			string.format(
				[[
        set -e
        curl -L "%s" -o "%s"
        rm -rf "%s"
        mkdir "%s"
        tar -xzf "%s" -C "%s"
        rm "%s"
      ]],
				url,
				temp_file,
				target_folder,
				target_folder,
				temp_file,
				target_folder,
				temp_file
			),
		}
	end

	print("Downloading sql tools...")
	vim.fn.jobstart(download_job, {
		on_exit = function(_, code)
			if code ~= 0 then
				vim.notify("Sql tools download error: exit code " .. code, vim.log.levels.ERROR)
			else
				print("Downloaded successfully")
				callback()
				-- todo: attach to buffer if we've opened an sql file in the time we were downloading
			end
		end,
		stderr_buffered = true,
		on_stderr = function(_, data)
			if data and data[1] ~= "" then
				vim.notify("Sql tools download error: " .. table.concat(data, "\n"), vim.log.levels.ERROR)
			end
		end,
	})
end

local M = {}

function M.setup(opts)
	M.opts = opts or {}

	-- if the opts specify a tools file path, don't download.
	if opts.tools_file then
		local file = io.open(opts.tools_file, "r")
		if not file then
			error("No sql tools file found at " .. opts.tools_file)
		end
		file:close()
	else
		local data_dir = get_data_directory(opts)
		local config_path = data_dir .. "/config.json"
		local config = read_json_file(config_path)
		local download_url = get_tools_download_url()

		-- download if it's a first time setup or the last downloaded is old
		if not config.last_downloaded_from or config.last_downloaded_from ~= download_url then
			download_tools(download_url, data_dir, function()
				config.last_downloaded_from = download_url
				write_json_file(config_path, config)
			end)
		end
	end
end

-- test lines
vim.opt.rtp:append("C:/dev/mssql.nvim/")
M.setup({})

return M
