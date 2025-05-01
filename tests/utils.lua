local utils = require("mssql.utils")

return {
	defer_async = utils.defer_async,
	get_completion_items = function()
		-- Trigger <C-x><C-o> to invoke omnifunc
		vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("a<C-x><C-o>", true, false, true), "n", true)

		-- Completion results are async
		utils.defer_async(500)
		local items = vim.fn.complete_info({ "items" }).items or {}
		vim.cmd("stopinsert")
		return vim.iter(items)
			:map(function(item)
				return item.word or item.abbr
			end)
			:totable()
	end,

	ui_select_fake = function(index)
		index = index or 1
		local original_select = vim.ui.select
		---@diagnostic disable-next-line: duplicate-set-field
		vim.ui.select = function(items, _, on_choice)
			vim.ui.select = original_select
			vim.defer_fn(function()
				on_choice(items[index], index)
			end, 3000)
		end
	end,

	wait_for_handler = utils.wait_for_handler_async,
}
