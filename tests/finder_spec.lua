local mssql = require("mssql")
local test_utils = require("tests.utils")

local find_async = function()
	local co = coroutine.running()
	local success = false
	mssql.find_object(function()
		success = true
		if coroutine.status(co) == "suspended" then
			coroutine.resume(co)
		end
	end)
	vim.defer_fn(function()
		if coroutine.status(co) == "suspended" then
			coroutine.resume(co)
		end
	end, 60000)
	coroutine.yield()
	if not success then
		error("mssql.find_object did not resume the callback within 1 minute", 0)
	end
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
