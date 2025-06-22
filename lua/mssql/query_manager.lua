local utils = require("mssql.utils")
local find_object = require("mssql.find_object")

local states = {
	Disconnected = "disconnected",
	Connecting = "connecting",
	Connected = "connected",
	Executing = "executing a query",
}

local function new_state()
	local state = states.Disconnected

	return {
		get_state = function()
			return state
		end,
		set_state = function(s)
			state = s
			vim.cmd("redrawstatus")
		end,
	}
end

return {
	states = states,
	-- creates a query manager, which
	-- interacts with sql server while maintaining a state
	create_query_manager = function(bufnr, client)
		local state = new_state()
		local last_connect_params = {}
		local object_cache = {}
		local owner_uri = utils.lsp_file_uri(bufnr)
		local refreshing = false
		local refresh_cancellation_token = { cancel = false }

		local refresh_object_cache = function(callback)
			-- cancel the current token (so running refresh will have a reference
			-- to it and periodically check it), and set the current token to a new one.
			-- Any running refresh will still refer to the old one
			refresh_cancellation_token.cancel = true
			local this_cancellation_token = { cancel = false }
			refresh_cancellation_token = this_cancellation_token

			object_cache = {}
			refreshing = true
			vim.cmd("redrawstatus")
			-- refresh the object cache, fire and forget
			utils.try_resume(coroutine.create(function()
				local new_cache = find_object.get_object_cache_async(
					client,
					last_connect_params.connection.options,
					refresh_cancellation_token
				)
				if this_cancellation_token.cancel then
					return
				end

				object_cache = new_cache
				refreshing = false
				vim.cmd("redrawstatus")
				if callback then
					callback()
				end
			end))
		end

		local connectionchanged_handler
		connectionchanged_handler = function(_, result, _)
			if not (result and result.ownerUri == owner_uri and result.connection) then
				return
			end
			last_connect_params = vim.tbl_deep_extend("force", last_connect_params, {
				connection = {
					options = {
						user = result.connection.userName,
						database = result.connection.databaseName,
						server = result.connection.serverName,
					},
				},
			})
			refresh_object_cache()
		end
		utils.register_lsp_handler(client, "connection/connectionchanged", connectionchanged_handler)

		return {
			-- the owner uri gets added to the connect_params
			connect_async = function(connect_params)
				if state.get_state() ~= states.Disconnected then
					error("You are currently " .. state.get_state(), 0)
				end

				connect_params.ownerUri = owner_uri
				state.set_state(states.Connecting)

				local result, err
				_, err = utils.lsp_request_async(client, "connection/connect", connect_params)
				if err then
					state.set_state(states.Disconnected)
					error("Could not connect: " .. err.message, 0)
				end

				result, err = utils.wait_for_notification_async(bufnr, client, "connection/complete", 10000)
				if err then
					state.set_state(states.Disconnected)
					error("Error in connecting: " .. err.message, 0)
				elseif result and result.errorMessage then
					state.set_state(states.Disconnected)
					error("Error in connecting: " .. result.errorMessage, 0)
				end

				state.set_state(states.Connected)
				last_connect_params = connect_params
			end,

			disconnect_async = function()
				if state.get_state() ~= states.Connected then
					error("You are currently " .. state.get_state(), 0)
				end
				utils.lsp_request_async(client, "connection/disconnect", { ownerUri = owner_uri })
				state.set_state(states.Disconnected)
				last_connect_params = {}
			end,

			execute_async = function(query)
				if state.get_state() ~= states.Connected then
					error("You are currently " .. state.get_state(), 0)
				end
				state.set_state(states.Executing)

				local result, err =
					utils.lsp_request_async(client, "query/executeString", { query = query, ownerUri = owner_uri })

				if err then
					state.set_state(states.Connected)
					error("Error executing query: " .. err.message, 0)
				elseif not result then
					state.set_state(states.Connected)
					error("Could not execute query", 0)
				else
					utils.log_info("Executing...")
				end

				result, err = utils.wait_for_notification_async(bufnr, client, "query/complete", 360000)
				state.set_state(states.Connected)

				if err then
					error("Could not execute query: " .. vim.inspect(err), 0)
				elseif not (result or result.batchSummaries) then
					error("Could not execute query: no results returned", 0)
				end

				return result
			end,

			get_state = function()
				return state.get_state()
			end,

			get_connect_params = function()
				return vim.tbl_deep_extend("keep", last_connect_params, {})
			end,

			get_lsp_client = function()
				return client
			end,

			refresh_object_cache = refresh_object_cache,

			get_object_cache = function()
				return object_cache
			end,

			is_refreshing_object_cache = function()
				return refreshing
			end,
		}
	end,
}
