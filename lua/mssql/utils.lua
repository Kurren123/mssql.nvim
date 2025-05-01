---@param msg string
---@param level vim.log.levels
local function log(msg, level)
	if type(msg) == "table" then
		msg = vim.inspect(msg)
	end
	vim.schedule(function()
		vim.notify(msg, level, {
			title = "MSSQL",
			plugin = "MSSQL",
		})
	end)
end

---Like assert, but doesn't prepend the
---file name and line number
local function safe_assert(item, message)
	if not item then
		error(message, 0) -- level 0 = no file/line info
	end
	return item
end

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
		local result, errmsg = coroutine.resume(co, ...)

		if not result then
			log(errmsg, vim.log.levels.ERROR)
		end

		return result
	end

local get_lsp_client = function(owner_uri)
	local bufnr
	if owner_uri then
		bufnr = vim.iter(vim.api.nvim_list_bufs()):find(function(buf)
			return vim.uri_from_fname(vim.api.nvim_buf_get_name(buf)) == owner_uri
		end)
		safe_assert(bufnr, "No buffer found with filename " .. owner_uri)
	else
		bufnr = 0
	end

	return safe_assert(
		vim.lsp.get_clients({ name = "mssql_ls", bufnr = bufnr })[1],
		"No MSSQL lsp client attached. Create a new sql query or open an existing sql file"
	)
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
	defer_async = function(ms)
		local co = coroutine.running()
		vim.defer_fn(function()
			coroutine.resume(co)
		end, ms)

		coroutine.yield()
	end,
	---Waits for the lsp to call the given method, with optional timeout.
	---Must be run inside a coroutine.
	---@param method string
	---@param timeout integer?
	---@return any result
	---@return lsp.ResponseError? error
	wait_for_handler_async = function(method, timeout)
		local this = coroutine.running()
		local client = vim.lsp.get_clients({ name = "mssql_ls" })[1]
		local resumed = false
		if client then
			local existing_handler = client.handlers[method]
			client.handlers[method] = function(err, result, cfg)
				if existing_handler then
					vim.lsp.handlers[method] = existing_handler
					existing_handler(err, result, cfg)
				end
				if not resumed then
					resumed = true
					try_resume(this, result, err)
				end
			end
		end

		timeout = timeout or 2000
		vim.defer_fn(function()
			if not resumed then
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
	get_lsp_client = get_lsp_client,
	---makes a request to the mssql lsp client
	---@param client vim.lsp.Client
	---@param method string
	---@param params any
	---@return any
	---@return lsp.ResponseError?
	lsp_request_async = function(client, method, params)
		local this = coroutine.running()
		client:request(method, params, function(err, result, _, _)
			try_resume(this, result, err)
		end)
		return coroutine.yield()
	end,
	try_resume = try_resume,
	ui_select_async = function(items, opts)
		local this = coroutine.running()
		vim.ui.select(items, opts, function(selected)
			vim.schedule(function()
				try_resume(this, selected)
			end)
		end)
		return coroutine.yield()
	end,
	log_info = function(msg)
		log(msg, vim.log.levels.INFO)
	end,
	log_error = function(msg)
		log(msg, vim.log.levels.ERROR)
	end,
	safe_assert = safe_assert,
}
