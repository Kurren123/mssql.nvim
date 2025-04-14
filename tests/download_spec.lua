local mssql = require("mssql")

function iif(cond, true_value, false_value)
	if cond then
		return true_value
	else
		return false_value
	end
end

local tools_folder = vim.fs.joinpath(vim.fn.stdpath("data"), "mssql.nvim/sqltools")
local tools_file = iif(jit.os == "Windows", "MicrosoftSqlToolsServiceLayer.exe", "MicrosoftSqlToolsServiceLayer")

local function tools_file_exists()
	local f = io.open(vim.fs.joinpath(tools_folder, tools_file), "r")
	if f then
		f:close()
		return true
	end
	return false
end

return {
	run_test = function(callback)
		vim.fn.delete(tools_folder, "rf")
		vim.fn.delete(vim.fs.joinpath(vim.fn.stdpath("data"), "mssql.nvim/config.json"))

		local download_finished = false

		mssql.setup(nil, function()
			download_finished = true
			assert(tools_file_exists(), "The sql server tools file does not exist among the downloads")
			callback()
		end)

		vim.defer_fn(function()
			assert(download_finished, "Download did not complete")
		end, 120000)
	end,
}
