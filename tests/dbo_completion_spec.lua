local utils = require("mssql.utils")
local test_utils = require("tests.utils")

local test_completions = function(sql, expected_completion_item)
	test_utils.defer_async(2000)
	vim.api.nvim_buf_set_lines(0, 0, -1, false, {})
	vim.api.nvim_buf_set_lines(vim.api.nvim_get_current_buf(), 0, 0, false, {
		sql,
	})

	-- move to the end
	vim.api.nvim_win_set_cursor(0, { 1, sql:len() - 1 })
	local items = test_utils.get_completion_items()
	assert(#items > 0, "Neovim didn't provide any completion items")
	assert(
		utils.contains(items, expected_completion_item),
		"Completion items for query " .. sql .. " didn't include " .. expected_completion_item
	)
	vim.cmd("stopinsert")
end

return {
	test_name = "Autocomplete should include database objects in cross db queries",
	run_test_async = function()
		test_completions("select * from TestDbA.dbo.", "Person")
		test_completions("select * from TestDbA.dbo.Person join TestDbB.dbo.", "Car")
	end,
}
