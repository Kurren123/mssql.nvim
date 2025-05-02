local mssql = require("mssql")
local utils = require("mssql.utils")
local test_utils = require("tests.utils")

return {
	test_name = "Queries should execute and show results",
	run_test_async = function()
		local query = "SELECT * from TestDbA.dbo.Person join TestDbB.dbo.Car on Person.ID = Car.PersonId"
		vim.api.nvim_buf_set_lines(0, 0, -1, false, { query })
		utils.wait_for_schedule_async()
		mssql.execute_query()
		local client = vim.lsp.get_clients({ name = "mssql_ls", bufnr = 0 })[1]
		local buf = vim.api.nvim_get_current_buf()

		local _, err = utils.wait_for_notification_async(buf, client, "query/complete", 30000)
		if err then
			error(err.message)
		end

		test_utils.defer_async(2000)

		local results = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
		assert(results:find("Bob"), "Sql query results do not contain Bob")
		assert(results:find("Hyundai"), "Sql query results do not contain Hyundai")
	end,
}
