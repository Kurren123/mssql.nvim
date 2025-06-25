local mssql = require("mssql")
local utils = require("mssql.utils")

return {
	test_name = "Executing a USE statement should switch database",
	run_test_async = function()
		local query = "USE TestDbB;"
		vim.api.nvim_buf_set_lines(0, 0, -1, false, { query })
		utils.wait_for_schedule_async()
		mssql.execute_query()
		local client = vim.lsp.get_clients({ name = "mssql_ls", bufnr = 0 })[1]
		local buf = vim.api.nvim_get_current_buf()

		local _, err = utils.wait_for_notification_async(buf, client, "query/complete", 30000)
		if err then
			error(err.message)
		end

		utils.defer_async(1000)
		local db = vim.b[buf].query_manager.get_connect_params().connection.options.database
		assert(db == "TestDbB", "Expected database to be TestDbB but instead it's " .. db)

		vim.cmd("bdelete!")
	end,
}
