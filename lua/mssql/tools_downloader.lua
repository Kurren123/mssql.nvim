local utils = require("mssql.utils")
local joinpath = vim.fs.joinpath
local M = {}

-- Check the OS and system architecture
M.get_tools_download_url = function()
	local urls = {
		Windows = {
			arm64 = "https://github.com/microsoft/sqltoolsservice/releases/download/5.0.20250530.2/Microsoft.SqlTools.ServiceLayer-win-arm64-net8.0.zip",
			x64 = "https://github.com/microsoft/sqltoolsservice/releases/download/5.0.20250530.2/Microsoft.SqlTools.ServiceLayer-win-x64-net8.0.zip",
			x86 = "https://github.com/microsoft/sqltoolsservice/releases/download/5.0.20250530.2/Microsoft.SqlTools.ServiceLayer-win-x86-net8.0.zip",
		},
		Linux = {
			arm64 = "https://github.com/microsoft/sqltoolsservice/releases/download/5.0.20250530.2/Microsoft.SqlTools.ServiceLayer-linux-arm64-net8.0.tar.gz",
			x64 = "https://github.com/microsoft/sqltoolsservice/releases/download/5.0.20250530.2/Microsoft.SqlTools.ServiceLayer-linux-x64-net8.0.tar.gz",
		},
		OSX = {
			arm64 = "https://github.com/microsoft/sqltoolsservice/releases/download/5.0.20250530.2/Microsoft.SqlTools.ServiceLayer-osx-arm64-net8.0.tar.gz",
			x64 = "https://github.com/microsoft/sqltoolsservice/releases/download/5.0.20250530.2/Microsoft.SqlTools.ServiceLayer-osx-x64-net8.0.tar.gz",
		},
	}

	local os = jit.os
	local arch = jit.arch

	if not urls[os] then
		error("Your OS " .. os .. " is not supported. It must be Windows, Linux or OSX.", 0)
	end

	local url = urls[os][arch]
	if not url then
		error("Your system architecture " .. arch .. " is not supported. It can either be x64 or arm64.", 0)
	end

	return url
end

-- Delete any existing download folder, download, unzip and write the most recent url to the config
M.download_tools_async = function(url, data_folder)
	local target_folder = joinpath(data_folder, "sqltools")

	local download_job
	if jit.os == "Windows" then
		local temp_file = joinpath(data_folder, "/temp.zip")
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
		local temp_file = joinpath(data_folder, "/temp.gz")
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

	utils.log_info("Downloading sql tools...")

	local co = coroutine.running()
	vim.fn.jobstart(download_job, {
		on_exit = function(_, code)
			if code ~= 0 then
				utils.log_error("Sql tools download error: exit code " .. code)
			else
				utils.log_info("Downloaded successfully")
				coroutine.resume(co)
			end
		end,
		stderr_buffered = true,
		on_stderr = function(_, data)
			if data and data[1] ~= "" then
				utils.log_error("Sql tools download error: " .. table.concat(data, "\n"))
			end
		end,
	})
	coroutine.yield()
end

return M
