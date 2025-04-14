-- test comletions on a saved file
local utils = require("mssql.utils")

local function get_completion_items(callback)
	-- Trigger <C-x><C-o> to invoke omnifunc
	vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("i<C-x><C-o>", true, false, true), "n", true)

	-- Completion results are async
	vim.defer_fn(function()
		local items = vim.fn.complete_info({ "items" }).items
		items = items or {}

		callback(utils.map(items, function(item)
			return item.word or item.abbr
		end))
	end, 500)
end

return {
	run_test = function(callback)
		vim.schedule(function()
			vim.cmd("e tests/completion.sql")
		end)

		vim.defer_fn(function()
			assert(#vim.lsp.get_clients({ bufnr = 0 }) == 1, "No lsp clients attached")

			-- move to the end of the "SE" in SELECT
			vim.api.nvim_win_set_cursor(0, { 1, 2 })
			get_completion_items(function(items)
				assert(#items > 0, "Neovim didn't provide any completion items")
				assert(utils.contains(items, "SELECT"))
				vim.cmd("stopinsert")
				callback()
			end)
		end, 3000)
	end,
}
