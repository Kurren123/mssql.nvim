local utils = require("mssql.utils")

---Waits for the lsp to call the given method, with optional timeout.
---Must be run inside a coroutine.
---@param client vim.lsp.Client
---@param bufnr integer
---@param method string
---@param timeout integer
---@return any result
---@return lsp.ResponseError? error
local wait_for_handler_async = function(bufnr, client, method, timeout)
	local this = coroutine.running()
	local resumed = false
	local existing_handler = client.handlers[method]
	client.handlers[method] = function(err, result, cfg)
		if existing_handler then
			vim.lsp.handlers[method] = existing_handler
			existing_handler(err, result, cfg)
		end
		if not resumed and cfg.bufnr == bufnr then
			resumed = true
			utils.try_resume(this, result, err)
		end
	end

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
end

local states = {
	Disconnected = "disconnected",
	Connecting = "connecting",
	Connected = "connected",
	Executing = "executing a query",
}
return {
	states = states,
	-- interacts with sql server while maintaining a state
	create_query_manager = function(bufnr, client)
		local state = states.Disconnected

		return {
			-- the owner uri gets added to the connect_params
			connect_async = function(connect_params)
				if state ~= states.Disconnected then
					error("You are currently " .. state, 0)
				end

				connect_params.ownerUri = vim.uri_from_fname(vim.api.nvim_buf_get_name(bufnr))
				state = states.Connecting

				local result, err
				_, err = utils.lsp_request_async(client, "connection/connect", connect_params)
				if err then
					state = states.Disconnected
					error("Could not connect: " .. err.message, 0)
				end

				result, err = wait_for_handler_async(bufnr, client, "connection/complete", 10000)
				if err then
					state = states.Disconnected
					error("Error in connecting: " .. err.message, 0)
				elseif result and result.errorMessage then
					state = states.Disconnected
					error("Error in connecting: " .. result.errorMessage)
				end

				state = states.Connected
			end,

			disconnect_async = function()
				if state ~= states.Connected then
					error("You are currently " .. state, 0)
				end
				utils.lsp_request_async(
					client,
					"connection/disconnect",
					{ ownerUri = vim.uri_from_fname(vim.api.nvim_buf_get_name(bufnr)) }
				)
				state = states.Disconnected
			end,

			execute_async = function(query)
				if state ~= states.Connected then
					error("You are currently " .. state, 0)
				end
				state = states.Executing

				local result, err = utils.lsp_request_async(
					client,
					"query/executeString",
					{ query = query, ownerUri = vim.uri_from_fname(vim.api.nvim_buf_get_name(bufnr)) }
				)

				if err then
					state = states.Connected
					error("Error executing query: " .. err.message, 0)
				elseif not result then
					state = states.Connected
					error("Could not execute query", 0)
				else
					utils.log_info("Executing...")
				end

				result, err = wait_for_handler_async(bufnr, client, "query/complete", 360000)
				state = states.Connected
				return result, err
			end,
		}
	end,
}
