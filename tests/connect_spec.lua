local mssql = require("mssql")
local test_utils = require("tests.utils")

return {
	test_name = "Connect to database should work",
	run_test_async = function()
		test_utils.ui_select_fake(1)
		mssql.connect()

		-- The connect event is sent, then the intelliSenseReady event.
		-- Wait for the intelliSenseReady event as this means the connection was successful and
		-- We can progress to the next test (getting completion items)
		local result, err = test_utils.wait_for_handler("textDocument/intelliSenseReady", 30000)
		if err then
			error(err.message)
		end

		assert(result, "No result returned from textDocument/intelliSenseReady")
		if result.errorMessage then
			error("Error returned from textDocument/intelliSenseReady: " .. result.errorMessage)
		end
	end,
}
