local utils = require("mssql.utils")

local defer_async = function(ms)
	local co = coroutine.running()
	vim.defer_fn(function()
		coroutine.resume(co)
	end, ms)

	coroutine.yield()
end
return {
	defer_async = defer_async,

	get_completion_items = function()
		-- Trigger <C-x><C-o> to invoke omnifunc
		vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("i<C-x><C-o>", true, false, true), "n", true)

		-- Completion results are async
		defer_async(500)
		local items = vim.fn.complete_info({ "items" }).items or {}
		return vim.iter(items)
			:map(function(item)
				return item.word or item.abbr
			end)
			:totable()
	end,
}
