local utils = require("mssql.utils")
local test_utils = require("tests.utils")

local test_completions = function(sql, expected_completion_item)
	test_utils.defer_async(500)
	vim.api.nvim_buf_set_lines(0, 0, -1, false, {})
	vim.api.nvim_buf_set_lines(vim.api.nvim_get_current_buf(), 0, 0, false, {
		sql,
	})

	-- move to the end
	vim.api.nvim_win_set_cursor(0, { 1, #sql })
	local items

	-- try it a few times as the first might internally time out.
	-- See findings.md for more
	for _ = 1, 5 do
		items = test_utils.get_completion_items()
		if items and utils.contains(items, expected_completion_item) then
			break
		end
		-- the internal timeout is 500ms so wait 550
		test_utils.defer_async(550)
	end
	assert(#items > 0, "Neovim didn't provide any completion items")
	assert(
		utils.contains(items, expected_completion_item),
		"Completion items for query " .. sql .. " didn't include " .. expected_completion_item
	)
end

return {
	test_name = "Autocomplete should include database objects in cross db queries",
	run_test_async = function()
		test_completions("select * from TestDbA.dbo.", "Person")
		test_completions("select * from TestDbA.dbo.Person join TestDbB.dbo.", "Car")
	end,
}
