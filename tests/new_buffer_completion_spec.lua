-- test comletions on a new (unsaved) buffer
local utils = require("mssql.utils")
local function defer_async(ms)
	local co = coroutine.running()
	vim.defer_fn(function()
		coroutine.resume(co)
	end, ms)

	coroutine.yield()
end

local function wait_for_schedule_async()
	local co = coroutine.running()
	vim.schedule(function()
		coroutine.resume(co)
	end)
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
	test_name = "Autocomplete should work in new (unsaved) buffers",
	run_test_async = function()
		wait_for_schedule_async()
		vim.cmd("enew")
		vim.cmd("setfiletype sql")
		vim.api.nvim_buf_set_lines(vim.api.nvim_get_current_buf(), 0, 0, false, {
			"se * from TestTable",
		})

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
