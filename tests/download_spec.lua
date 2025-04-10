local mssql = require("mssql")

local download_finished = false

function iif(cond, true_value, false_value)
	if cond then
		return true_value
	else
		return false_value
	end
end

local tools_folder = vim.fs.joinpath(vim.fn.stdpath("data"), "mssql.nvim/sqltools")
local tools_file = iif(jit.os == "Windows", "MicrosoftSqlToolsServiceLayer.exe", "MicrosoftSqlToolsServiceLayer")

vim.fn.delete(tools_folder, "rf")
vim.fn.delete(vim.fs.joinpath(vim.fn.stdpath("data"), "mssql.nvim/config.json"))

local ok, err = pcall(function()
	mssql.setup()
	vim.wait(120000, function()
		local f = io.open(vim.fs.joinpath(tools_folder, tools_file), "r")
		if f then
			f:close()
			download_finished = true
		end
		return download_finished
	end, 1000)
end)

assert(ok, "setup() threw: " .. (err or ""))
assert(download_finished, "Download did not complete")
