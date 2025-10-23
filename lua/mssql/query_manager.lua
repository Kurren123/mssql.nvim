---@class MssqlExecutionInfo
---@field rows_affected? number
---@field elapsed_time? number

local utils = require("mssql.utils")
local finder = require("mssql.find_object")

local states = {
	Disconnected = "disconnected",
	Cancelling = "cancelling a query",
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
		local owner_uri = utils.lsp_file_uri(bufnr)
		local execution_timer = nil
		---@type MssqlExecutionInfo
		local last_execution_info = { rows_affected = nil, elapsed_time = nil }
		local start_time = 0

		--- Stops the timer and calculates the final, precise time from the start time.
		---@return nil
		local function stop_execution_timer()
			if execution_timer then
				if start_time > 0 then
					last_execution_info.elapsed_time = (vim.loop.now() - start_time) / 1000
				end

				execution_timer:stop()
				execution_timer:close()
				execution_timer = nil
				start_time = 0
				vim.cmd("redrawstatus")
			end
		end

		--- Starts a timer that updates the elapsed time every second.
		---@return nil
		local function start_execution_timer()
			last_execution_info.elapsed_time = 0
			last_execution_info.rows_affected = nil
			start_time = vim.loop.now()

			execution_timer = vim.loop.new_timer()
			if execution_timer then
				execution_timer:start(0, 1000, vim.schedule_wrap(function()
					if state.get_state() == states.Executing then
						last_execution_info.elapsed_time = (vim.loop.now() - start_time) / 1000
						vim.cmd("redrawstatus")
					else
						stop_execution_timer()
					end
				end))
			end
		end

		--- Parses a query/message string to find the number of rows affected.
		--- NOTE: Relies on the specific "(N rows affected)" format from the LSP.
		---@param message string
		---@return nil
		local function parse_rows_affected_message(message)
			local row_count = string.match(message, "%((%d+) rows? affected%)")
			if row_count then
				last_execution_info.rows_affected = tonumber(row_count)
			end
		end

		--- Sets the final query elapsed time and row count from server results.
		--- Prioritizes DML row counts if they exist, otherwise uses the SELECT row count.
		---@param final_time number? The precise final execution time in seconds.
		---@param select_row_count number The row count returned by the SELECT statement.
		---@return nil
		local function set_final_execution_stats(final_time, select_row_count)
			last_execution_info.elapsed_time = final_time
			if last_execution_info.rows_affected == nil then
				last_execution_info.rows_affected = select_row_count
			end
		end

		--- Handles the 'query/message' notification to parse for `(N rows affected)` in UPDATE,INSERT,DELETE statements
		---@param message_result table
		---@return nil
		local function handle_query_message(message_result)
			local ok, err = pcall(function()
					parse_rows_affected_message(message_result.message.message)
			end)
			if not ok then
				utils.log_warn("Failed to parse rows affected: " .. err)
			end
		end

		--- Handles the 'query/complete' notification to parse for elapsed time and for SELECT statements rowCount
		---@param params table
		---@return nil
		local function handle_query_complete(params)
			local batch_summary = params.batchSummaries and params.batchSummaries[#params.batchSummaries]
			if not batch_summary then
			  return
			end

			local elapsed_str = batch_summary.executionElapsed
			local hours, minutes, seconds = elapsed_str:match("(%d+):(%d+):([%d.]+)")
			local final_elapsed_time = (tonumber(hours) or 0) * 3600
			  + (tonumber(minutes) or 0) * 60
			  + (tonumber(seconds) or 0)

			-- Get total row count for SELECT statements only
			local total_row_count = 0
			if batch_summary.resultSetSummaries and #batch_summary.resultSetSummaries > 0 then
			  total_row_count = batch_summary.resultSetSummaries[#batch_summary.resultSetSummaries].rowCount
			end

			set_final_execution_stats(final_elapsed_time, total_row_count)
		end


		local qm = {
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

				if result and result.connectionSummary then
					connect_params.connection.options.database = result.connectionSummary.databaseName
					connect_params.connection.options.DatabaseDisplayName = result.connectionSummary.databaseName
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
				last_execution_info = { rows_affected = nil, elapsed_time = nil }
			end,

			execute_async = function(query)
				if state.get_state() ~= states.Connected then
					error("You are currently " .. state.get_state(), 0)
				end
				state.set_state(states.Executing)

				start_execution_timer()

				local result, err =
					utils.lsp_request_async(client, "query/executeString", { query = query, ownerUri = owner_uri })

				if err then
                    stop_execution_timer()
					state.set_state(states.Connected)
					error("Error executing query: " .. err.message, 0)
				elseif not result then
					state.set_state(states.Connected)
					error("Could not execute query", 0)
				else
					utils.log_info("Executing...")
				end

				result, err = utils.wait_for_notification_async(bufnr, client, "query/complete", 360000)
				stop_execution_timer()
				state.set_state(states.Connected)
				vim.cmd("redrawstatus")

				-- handle cancellations that may be requested while waiting
				if state.get_state() == states.Cancelling then
					stop_execution_timer()
					utils.log_info("Query was cancelled.")
					return
				end

				if err then
					stop_execution_timer()
					error("Could not execute query: " .. vim.inspect(err), 0)
				elseif not (result or result.batchSummaries) then
					error("Could not execute query: no results returned", 0)
				end

				return result
			end,

			connectionchanged_async = function(result)
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
				finder.initialise_cache_async(client, last_connect_params.connection.options)
			end,

			cancel_async = function()
				if state.get_state() ~= states.Executing then
					error("There is no query being executed in the current buffer", 0)
				end

				state.set_state(states.Cancelling)
				-- let the waiting `execute_async` coroutine handle the 'query/complete' notification
				utils.lsp_request_async(client, "query/cancel", { ownerUri = owner_uri })
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

			initialise_cache_async = function(force)
				return finder.initialise_cache_async(client, last_connect_params.connection.options, force)
			end,
			find_async = function()
				return finder.find_async(last_connect_params.connection.options, client)
			end,
			is_refreshing = function()
				return finder.is_refreshing(last_connect_params.connection.options)
			end,

			--- Returns the last execution's info.
			---@return MssqlExecutionInfo
			last_execution = function()
				return last_execution_info
			end,

			parse_rows_affected_message = parse_rows_affected_message,

			set_final_execution_stats = set_final_execution_stats,
			handle_query_complete = handle_query_complete,
			handle_query_message = handle_query_message,
		}

		-- Add buffer cleanup to handle cases where buffer is deleted during execution
		vim.api.nvim_buf_attach(bufnr, false, {
			on_detach = function()
				if execution_timer and not execution_timer:is_closing() then
					execution_timer:stop()
					execution_timer:close()
					execution_timer = nil
				end
			end
		})

		return qm
	end,
}
