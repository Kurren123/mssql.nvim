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

	ui_select_fake = function(item)
		local original_select = vim.ui.select
		---@diagnostic disable-next-line: duplicate-set-field
		vim.ui.select = function(items, _, on_choice)
			vim.ui.select = original_select
			local index = vim.fn.index(items, item)
			if index == nil or index == -1 then
				error("You tried to choose " .. item .. "when prompted but this wasn't an option", 0)
			end
			vim.defer_fn(function()
				on_choice(item, index + 1)
			end, 3000)
		end
	end,
}
