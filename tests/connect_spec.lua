local mssql = require("mssql")
local test_utils = require("tests.utils")

return {
	test_name = "Connect to database should work",
	run_test_async = function()
		test_utils.ui_select_fake(1)
		mssql.connect()

		local result, err = test_utils.wait_for_handler("connection/complete", 10000)
		if err then
			error(err.message)
		end

		assert(result, "No result returned from connection/complete")
		if result.errorMessage then
			error("Error returned from connection/complete: " .. result.errorMessage)
		end
	end,
}
