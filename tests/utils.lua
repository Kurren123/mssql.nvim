local defer_async = function(ms)
	local co = coroutine.running()
	vim.defer_fn(function()
		coroutine.resume(co)
	end, ms)

	coroutine.yield()
end
return {
	defer_async = defer_async,

	get_completion_items = function()
		-- Trigger <C-x><C-o> to invoke omnifunc
		vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("i<C-x><C-o>", true, false, true), "n", true)

		-- Completion results are async
		defer_async(500)
		local items = vim.fn.complete_info({ "items" }).items or {}
		return vim.iter(items)
			:map(function(item)
				return item.word or item.abbr
			end)
			:totable()
	end,

	ui_select_fake = function(index)
		index = index or 1
		local original_select = vim.ui.select
		vim.ui.select = function(items, _, on_choice)
			vim.ui.select = original_select
			vim.defer_fn(function()
				on_choice(items[index], index)
			end, 3000)
		end
	end,

	---Waits for the lsp to call the given method, with optional timeout.
	---Must be run inside a coroutine.
	---@param method string
	---@param timeout integer?
	---@return any result
	---@return lsp.ResponseError? error
	wait_for_handler = function(method, timeout)
		local this = coroutine.running()

		local client = vim.lsp.get_clients({ name = "mssql_ls" })[1]
		if client then
			local existing_handler = client.handlers[method]
			client.handlers[method] = function(err, result, cfg)
				if existing_handler then
					vim.lsp.handlers[method] = existing_handler
					existing_handler(err, result, cfg)
				end
				if coroutine.status(this) == "suspended" then
					coroutine.resume(this, result, err)
				end
			end
		end

		timeout = timeout or 2000
		vim.defer_fn(function()
			if coroutine.status(this) == "suspended" then
				coroutine.resume(
					this,
					nil,
					vim.lsp.rpc_response_error(
						vim.lsp.protocol.ErrorCodes.UnknownErrorCode,
						"Waiting for the lsp to call " .. method .. " timed out"
					)
				)
			end
		end, timeout)
		return coroutine.yield()
	end,
}
