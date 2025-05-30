local mssql = require("mssql")
local test_utils = require("tests.utils")
local utils = require("mssql.utils")

return {
	test_name = "Connect to database should work",
	run_test_async = function()
		test_utils.ui_select_fake("master")
		mssql.connect()
		local client = vim.lsp.get_clients({ name = "mssql_ls", bufnr = 0 })[1]
		local buf = vim.api.nvim_get_current_buf()

		-- The connect event is sent, then the intelliSenseReady event.
		-- Wait for the intelliSenseReady event as this means the connection was successful and
		-- We can progress to the next test (getting completion items)
		local result, err = utils.wait_for_notification_async(buf, client, "textDocument/intelliSenseReady", 30000)
		if err then
			error(err.message)
		end

		assert(result, "No result returned from textDocument/intelliSenseReady")
		if result.errorMessage then
			error("Error returned from textDocument/intelliSenseReady: " .. result.errorMessage)
		end
	end,
}
