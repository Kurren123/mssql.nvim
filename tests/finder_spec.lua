local mssql = require("mssql")
local test_utils = require("tests.utils")

local find_async = function()
	local co = coroutine.running()
	mssql.find_object(function()
		coroutine.resume(co)
	end)
	coroutine.yield()
end

return {
	test_name = "Finder should work",
	run_test_async = function()
		test_utils.ui_select_fake(1)
		-- wait until objects are cached
		test_utils.defer_async(2000)
		find_async()
		test_utils.defer_async(2000)
		local results = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
		assert(results:find("Hyundai"), "Sql query results do not contain Hyundai: " .. results)
		vim.cmd("bdelete")
	end,
}
