local mssql = require("mssql")
local test_utils = require("tests.utils")

return {
	test_name = "Finder should work",
	run_test_async = function()
		test_utils.ui_select_fake("Person")
		mssql.find_object()
		test_utils.defer_async(2000)

		local results = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
		assert(results:find("Bob"), "Sql query results do not contain Bob")
		assert(results:find("Hyundai"), "Sql query results do not contain Hyundai")
		vim.cmd("bdelete")
	end,
}
