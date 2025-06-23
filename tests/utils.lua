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
			local index
			if type(item) == "string" then
				index = vim.fn.index(items, item) + 1
				if index == nil or index == 0 then
					error("You tried to choose " .. item .. "when prompted but this wasn't an option", 0)
				end
			elseif type(item) == "number" then
				index = item
				if not items[index] then
					error("The index " .. index .. " is out of range in the items: " .. vim.inspect(items))
				end
				item = items[index]
			end
			vim.defer_fn(function()
				on_choice(item, index)
			end, 3000)
		end
	end,

	-- Takes a list of functions that should be run inside a coroutine,
	-- runs each one and waits for all of them to finish. Must be
	-- run inside a coroutine
	wait_for_all_async = function(async_functions)
		local finished_count = 0
		local co = coroutine.running()

		for _, f in ipairs(async_functions) do
			coroutine.resume(coroutine.create(function()
				f()
				finished_count = finished_count + 1
				if finished_count == #async_functions then
					coroutine.resume(co)
				end
			end))
		end
		coroutine.yield()
	end,
}
