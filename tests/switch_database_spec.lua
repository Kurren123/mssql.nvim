local mssql = require("mssql")
local test_utils = require("tests.utils")
local utils = require("mssql.utils")

local switch_db_async = function()
	local co = coroutine.running()
	local success = false
	mssql.switch_database(function()
		success = true
		if coroutine.status(co) == "suspended" then
			coroutine.resume(co)
		end
	end)
	vim.defer_fn(function()
		if coroutine.status(co) == "suspended" then
			coroutine.resume(co)
		end
	end, 60000)
	coroutine.yield()
	if not success then
		error("mssql.switch_database did not resume the callback within 1 minute", 0)
	end
end

local result, err

local wait_for_intellisenseReady = function()
	local client = vim.lsp.get_clients({ name = "mssql_ls", bufnr = 0 })[1]
	local buf = vim.api.nvim_get_current_buf()

	-- The connect event is sent, then the intelliSenseReady event.
	-- Wait for the intelliSenseReady event as this means the connection was successful
	result, err = utils.wait_for_notification_async(buf, client, "textDocument/intelliSenseReady", 30000)
end

return {
	test_name = "Switch database should work",
	run_test_async = function()
		test_utils.ui_select_fake("TestDbB")

		test_utils.wait_for_all_async({ switch_db_async, wait_for_intellisenseReady })

		if err then
			error(err.message)
		end

		assert(result, "No result returned from textDocument/intelliSenseReady")
		if result.errorMessage then
			error("Error returned from textDocument/intelliSenseReady: " .. result.errorMessage)
		end
	end,
}
