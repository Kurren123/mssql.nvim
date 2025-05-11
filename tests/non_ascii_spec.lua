local mssql = require("mssql")
local utils = require("mssql.utils")
local test_utils = require("tests.utils")

local function find_pipe_indices(str)
	local pipe = vim.fn.strgetchar("|", 0)

	local result = {}
	local running = 0
	for _, i in ipairs(vim.fn.range(0, vim.fn.strcharlen(str) - 1)) do
		local unicode = vim.fn.strgetchar(str, i)
		running = running + vim.fn.strdisplaywidth(vim.fn.nr2char(unicode))

		if unicode == pipe then
			table.insert(result, running)
		end
	end
	return result
end

local function all_pipes_same(lines)
	lines = vim.iter(lines)
		:map(find_pipe_indices)
		:filter(function(indicies)
			return #indicies > 0
		end)
		:totable()

	if #lines == 0 then
		return true
	end

	local first = lines[1]
	for _, indicies in ipairs(lines) do
		if not vim.deep_equal(first, indicies) then
			return false
		end
	end

	return true
end

return {
	test_name = "Non ascii charcters should render properly",
	run_test_async = function()
		local query = "select * from TestDbA.dbo.PersonNonAscii"
		vim.api.nvim_buf_set_lines(0, 0, -1, false, { query })
		utils.wait_for_schedule_async()
		mssql.execute_query()
		local client = vim.lsp.get_clients({ name = "mssql_ls", bufnr = 0 })[1]
		local buf = vim.api.nvim_get_current_buf()

		local _, err = utils.wait_for_notification_async(buf, client, "query/complete", 30000)
		if err then
			error(err.message)
		end

		test_utils.defer_async(2000)

		local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)

		assert(
			all_pipes_same(lines),
			"Not all pipes were in the same position when rendering:\n" .. table.concat(lines, "\n")
		)
		vim.cmd("bdelete")
	end,
}
