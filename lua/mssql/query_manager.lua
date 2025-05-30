local utils = require("mssql.utils")

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
		local last_connect_params

		return {
			-- the owner uri gets added to the connect_params
			connect_async = function(connect_params)
				if state.get_state() ~= states.Disconnected then
					error("You are currently " .. state.get_state(), 0)
				end

				connect_params.ownerUri = utils.lsp_file_uri(bufnr)
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
				utils.lsp_request_async(client, "connection/disconnect", { ownerUri = utils.lsp_file_uri(bufnr) })
				state.set_state(states.Disconnected)
				last_connect_params = nil
			end,

			execute_async = function(query)
				if state.get_state() ~= states.Connected then
					error("You are currently " .. state.get_state(), 0)
				end
				state.set_state(states.Executing)

				local result, err = utils.lsp_request_async(
					client,
					"query/executeString",
					{ query = query, ownerUri = utils.lsp_file_uri(bufnr) }
				)

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
		}
	end,
}
