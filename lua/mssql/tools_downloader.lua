local joinpath = vim.fs.joinpath
local M = {}

-- Check the OS and system architecture
M.get_tools_download_url = function()
	local urls = {
		Windows = {
			arm64 = "https://github.com/microsoft/sqltoolsservice/releases/download/5.0.20250408.3/Microsoft.SqlTools.ServiceLayer-win-arm64-net8.0.zip",
			x64 = "https://github.com/microsoft/sqltoolsservice/releases/download/5.0.20250408.3/Microsoft.SqlTools.ServiceLayer-win-x64-net8.0.zip",
			x86 = "https://github.com/microsoft/sqltoolsservice/releases/download/5.0.20250408.3/Microsoft.SqlTools.ServiceLayer-win-x86-net8.0.zip",
		},
		Linux = {
			arm64 = "https://github.com/microsoft/sqltoolsservice/releases/download/5.0.20250408.3/Microsoft.SqlTools.ServiceLayer-linux-arm64-net8.0.tar.gz",
			x64 = "https://github.com/microsoft/sqltoolsservice/releases/download/5.0.20250408.3/Microsoft.SqlTools.ServiceLayer-linux-x64-net8.0.tar.gz",
		},
		OSX = {
			arm64 = "https://github.com/microsoft/sqltoolsservice/releases/download/5.0.20250408.3/Microsoft.SqlTools.ServiceLayer-osx-arm64-net8.0.tar.gz",
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
		error("Your system architecture " .. arch .. " is not supported. It can either be x64 or arm64.")
	end

	return url
end

-- Delete any existing download folder, download, unzip and write the most recent url to the config
M.download_tools = function(url, data_folder, callback)
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

	vim.notify("Downloading sql tools...", vim.log.levels.INFO)
	vim.fn.jobstart(download_job, {
		on_exit = function(_, code)
			if code ~= 0 then
				vim.notify("Sql tools download error: exit code " .. code, vim.log.levels.ERROR)
			else
				vim.notify("Downloaded successfully", vim.log.levels.INFO)
				callback()
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

return M
