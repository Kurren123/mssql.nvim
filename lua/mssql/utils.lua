local function contains(tbl, element)
	if not table then
		return false
	end
	for _, v in pairs(tbl) do
		if v == element then
			return true
		end
	end
	return false
end

local try_resume =
	-- resumes the coroutiune, vim notifies any errors
	function(co, ...)
		local success, msg = coroutine.resume(co, ...)

		if not success then
			vim.notify(msg, vim.log.levels.ERROR)
		end
	end
return {
	contains = contains,
	wait_for_schedule_async = function()
		local co = coroutine.running()
		vim.schedule(function()
			coroutine.resume(co)
		end)
		coroutine.yield()
	end,
	try_resume = try_resume,
	---makes a request to the lsp client
	---@param client vim.lsp.Client
	---@param method string
	lsp_request_async = function(client, method, params)
		local this = coroutine.running()
		client:request(method, params, function(err, result, _, _)
			try_resume(this, result, err)
		end)
		return coroutine.yield()
	end,

	ui_select_async = function(items, opts)
		local this = coroutine.running()
		vim.ui.select(items, opts, function(selected)
			if not selected then
				vim.notify("No selection made", vim.log.levels.INFO)
				return
			end
			vim.schedule(function()
				try_resume(this, selected)
			end)
		end)
		local result = coroutine.yield()
		return result
	end,
}
