-- test completions on a saved file
local utils = require("mssql.utils")
local test_utils = require("tests.utils")

return {
	test_name = "LSP should be configured so that autocomplete works on saved sql files",
	run_test_async = function()
		vim.schedule(function()
			vim.cmd("e tests/completion.sql")
		end)

		test_utils.defer_async(3000)
		assert(#vim.lsp.get_clients({ bufnr = 0 }) == 1, "No lsp clients attached")

		-- move to the first E in SELECT
		vim.api.nvim_win_set_cursor(0, { 1, 1 })
		local items = test_utils.get_completion_items()
		assert(#items > 0, "Neovim didn't provide any completion items")
		assert(utils.contains(items, "SELECT"))
	end,
}
