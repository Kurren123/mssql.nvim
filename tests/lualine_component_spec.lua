local mssql = require("mssql")
local utils = require("mssql.utils")
local test_utils = require("tests.utils")

local function get_lualine_status()
	local lualine_component_func = require("mssql").lualine_component[1]
	if not lualine_component_func then
		error("Could not find lualine component function.")
	end
	return lualine_component_func()
end

return {
	test_name = "Lualine component should display elapsed time and rows affected",
	run_test_async = function()
		local qm = vim.b.query_manager
		if not (qm and qm.get_state() == "connected") then
			error("Test setup error: Not connected to a database.")
		end

		-- Test 1: Verify live timer during execution
		local query_long = "WAITFOR DELAY '00:00:03'; SELECT 1 AS Test;"
		vim.api.nvim_buf_set_lines(0, 0, -1, false, { query_long })
		utils.wait_for_schedule_async()

		mssql.execute_query()
		local client = vim.lsp.get_clients({ name = "mssql_ls", bufnr = 0 })[1]
		local buf = vim.api.nvim_get_current_buf()

		test_utils.defer_async(2000)

		local status_during_execution = get_lualine_status()
		if status_during_execution then
			local elapsed_pattern = "%d?%d?:?%d%d:%d%d$"
			assert(status_during_execution:find("Executing..."), "Lualine status should contain 'Executing...' during query.")
			assert(
				status_during_execution:find(elapsed_pattern),
				"Lualine status should show elapsed seconds during query. Status was: " .. status_during_execution
			)
		end

		local _, err = utils.wait_for_notification_async(buf, client, "query/complete", 30000)
		if err then
			error(err.message)
		end
		test_utils.defer_async(1000)

		-- Test 2: Verify final elapsed time after completion
		local status_after_execution = get_lualine_status()
		if status_after_execution then
			assert(status_after_execution, "Status after execution should not be nil")
			assert(
				status_after_execution:match("00:03.%d+"),
				"Lualine status should show final elapsed time with milliseconds. Status was: " .. status_after_execution
			)
			assert(
				status_after_execution:find("1 row affected"),
				"Lualine status should show '1 row affected' for a SELECT query with one row. Status was: "
					.. status_after_execution
			)
		end

		vim.cmd("bdelete!")
		test_utils.defer_async(500)

		-- Test 3: Verify "rows affected" for an UPDATE statement
		vim.api.nvim_set_current_buf(buf) -- switch back to query buffer from the results buffer from prior `execute_query()` call
		local query_update = "SELECT * INTO #test_temp FROM (VALUES (1,2,3), (1,2,3), (4,5,6), (4,5,6)) AS t(a,b,c); UPDATE #test_temp SET a = a + 1 WHERE a >= 4;"
		vim.api.nvim_buf_set_lines(0, 0, -1, false, { query_update })
		mssql.execute_query()

		_, err = utils.wait_for_notification_async(buf, client, "query/complete", 30000)
		if err then
			error(err.message)
		end
		test_utils.defer_async(2000)

		local status_after_update = get_lualine_status()
		if status_after_update then
			assert(
				status_after_update:find("2 rows affected"),
				"Lualine status should show '2 rows affected' after update. Status was: " .. status_after_update
			)
		end

		vim.cmd("bdelete!")
		vim.api.nvim_set_current_buf(buf)
	end,
}
