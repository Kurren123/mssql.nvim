-- test comletions on a saved file
local utils = require("mssql.utils")
local function defer_async(ms)
	local co = coroutine.running()
	vim.defer_fn(function()
		coroutine.resume(co)
	end, ms)

	coroutine.yield()
end

local function get_completion_items()
	-- Trigger <C-x><C-o> to invoke omnifunc
	vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("i<C-x><C-o>", true, false, true), "n", true)

	-- Completion results are async
	defer_async(500)
	local items = vim.fn.complete_info({ "items" }).items or {}
	return utils.map(items, function(item)
		return item.word or item.abbr
	end)
end

return {
	test_name = "LSP should be configured so that autocomplete works on saved sql files",
	run_test_async = function()
		vim.schedule(function()
			vim.cmd("e tests/completion.sql")
		end)

		defer_async(3000)
		assert(#vim.lsp.get_clients({ bufnr = 0 }) == 1, "No lsp clients attached")

		-- move to the end of the "SE" in SELECT
		vim.api.nvim_win_set_cursor(0, { 1, 2 })
		local items = get_completion_items()
		assert(#items > 0, "Neovim didn't provide any completion items")
		assert(utils.contains(items, "SELECT"))
		vim.cmd("stopinsert")
	end,
}
