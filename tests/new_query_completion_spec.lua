local utils = require("mssql.utils")
local test_utils = require("tests.utils")

return {
	test_name = "Autocomplete should work after new_query()",
	run_test_async = function()
		require("mssql").new_query()
		vim.api.nvim_buf_set_lines(vim.api.nvim_get_current_buf(), 0, 0, false, {
			"se * from TestTable",
		})

		test_utils.defer_async(3000)
		assert(#vim.lsp.get_clients({ bufnr = 0 }) == 1, "No lsp clients attached")

		-- move to the end of the "SE" in SELECT
		vim.api.nvim_win_set_cursor(0, { 1, 2 })
		local items = test_utils.get_completion_items()
		assert(#items > 0, "Neovim didn't provide any completion items")
		assert(utils.contains(items, "SELECT"))
		vim.cmd("stopinsert")
	end,
}
