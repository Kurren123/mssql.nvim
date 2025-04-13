-- test comletions on a saved file
local utils = require("mssql.utils")
require("mssql").setup({})

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

vim.cmd("e tests/completion.sql")
-- wait for the lsp to load??
vim.wait(2000)
assert(#vim.lsp.get_clients({ bufnr = 0 }) == 1, "No lsp clients attached")
print("Language server attached")

-- move to the end of the "SE" in SELECT
vim.api.nvim_win_set_cursor(0, { 1, 2 })

local completed = false
local completion_items
get_completion_items(function(items)
	completion_items = items
	completed = true
end)

vim.wait(3000, function()
	return completed
end, 100)

assert(completed and completion_items and #completion_items > 0, "Neovim didn't provide any completion items")
assert(utils.contains(completion_items, "SELECT"))
