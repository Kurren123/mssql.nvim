local utils = require("mssql.utils")

---Same as utils.wait_for_notification_async but ignores any owner uri
---@param client vim.lsp.Client
---@param method string
---@param timeout integer
---@return any result
---@return lsp.ResponseError? error
local wait_for_notification_async = function(client, method, timeout)
	local this = coroutine.running()
	local resumed = false
	local handler
	handler = function(err, result, _)
		if not resumed then
			resumed = true
			utils.unregister_lsp_handler(client, method, handler)
			utils.try_resume(this, result, err)
		end
		return result, err
	end
	utils.register_lsp_handler(client, method, handler)
	vim.defer_fn(function()
		if not resumed then
			resumed = true
			utils.unregister_lsp_handler(client, method, handler)
			utils.try_resume(
				this,
				nil,
				vim.lsp.rpc_response_error(
					vim.lsp.protocol.ErrorCodes.UnknownErrorCode,
					"Waiting for the lsp to call " .. method .. "timed out"
				)
			)
		end
	end, timeout)
	return coroutine.yield()
end

local get_session_async = function(client, connection_options)
	connection_options = vim.deepcopy(connection_options)
	connection_options.ServerName = connection_options.server
	connection_options.DatabaseName = connection_options.database
	connection_options.UserName = connection_options.user
	connection_options.EnclaveAttestationProtocol = connection_options.attestationProtocol

	-- For some reason, if there is no display name set on the connection parameters then
	-- the language server will treat this as a default/system database:
	-- https://github.com/microsoft/sqltoolsservice/blob/49036c6196e73c3791bca5d31e97a16afee00772/src/Microsoft.SqlTools.ServiceLayer/ObjectExplorer/ObjectExplorerService.cs#L537
	connection_options.DatabaseDisplayName = connection_options.DatabaseDisplayName or connection_options.database

	utils.lsp_request_async(client, "objectexplorer/createsession", connection_options)
	local response, err = wait_for_notification_async(client, "objectexplorer/sessioncreated", 10000)
	if response and response.rootNode and response.rootNode.objectType == "Server" then
		-- If we connect to a system database then the root node will be the server.
		-- So we need to set a target path to navigate to first so that we only search the database we connect to
		response.target_path = response.rootNode.nodePath
			.. "/Databases/System Databases/"
			.. connection_options.DatabaseName
	end
	utils.safe_assert(not err, vim.inspect(err))
	return response
end

--[[
			scriptOptions Possible values:
			  ScriptCreate
			  ScriptDrop
			  ScriptCreateDrop
			  ScriptSelect


		public enum ScriptingOperationType
		{
		    Select = 0,
		    Create = 1,
		    Insert = 2,
		    Update = 3,
		    Delete = 4,
		    Execute = 5,
		    Alter = 6
		}
--]]
local nodeTypes = {
	AggregateFunctionPartitionFunction = {
		scriptCreateDrop = "ScriptCreate",
		operation = 6,
	},
	ScalarValuedFunction = {
		scriptCreateDrop = "ScriptCreate",
		operation = 6,
	},
	StoredProcedure = {
		scriptCreateDrop = "ScriptCreate",
		operation = 6,
	},
	TableValuedFunction = {
		scriptCreateDrop = "ScriptCreate",
		operation = 6,
	},
	Table = {
		scriptCreateDrop = "ScriptSelect",
		operation = 0,
	},
	View = {
		scriptCreateDrop = "ScriptSelect",
		operation = 0,
	},
}

local get_object_cache_async = function(lsp_client, connection_options, cancellation_token)
	local session = get_session_async(lsp_client, connection_options)
	utils.safe_assert(session and session.sessionId)

	local session_id = session.sessionId
	local root_path = session.rootNode.nodePath
	local cache = {}
	local expand_count = 0
	local co = coroutine.running()
	local expand_complete

	local clean_up_and_return = function(return_value)
		-- disconnect
		lsp_client:request("objectExplorer/closeSession", {
			sessionId = session_id,
		}, function(err, result, _, _)
			session_id = nil
			return result, err
		end)
		utils.unregister_lsp_handler(lsp_client, "objectexplorer/expandCompleted", expand_complete)
		if coroutine.status(co) == "suspended" then
			coroutine.resume(co, return_value)
		end
	end

	local expand = function(path)
		expand_count = expand_count + 1
		vim.schedule(function()
			-- check for cancellation every time we expand a node in the tree
			if cancellation_token.cancel then
				clean_up_and_return(false)
				return
			end
			lsp_client:request("objectexplorer/expand", {
				sessionId = session_id,
				nodePath = path,
			}, function(err, result, _, _)
				return result, err
			end)
		end)
	end

	expand_complete = function(_, expand_result, _)
		if not expand_result then
			return
		end
		for _, node in ipairs(expand_result.nodes) do
			if nodeTypes[node.objectType] then
				local path = node.parentNodePath
				local root_path_length = #root_path
				if session.target_path then
					root_path_length = #session.target_path
				end
				node.picker_path = string.sub(path, root_path_length + 2, #path) .. "/"
				node.text = node.picker_path .. node.label
				table.insert(cache, node)
			elseif not node.nodePath then
				utils.log_info("no node path")
				utils.log_info(node)
			elseif session.target_path and vim.startswith(session.target_path, node.nodePath) then
				-- We are on our way to the target, expand
				expand(node.nodePath)
			elseif session.target_path and vim.startswith(node.nodePath, session.target_path) then
				-- we have hit our target path, expand inside it
				expand(node.nodePath)
			elseif not session.target_path then
				-- We are not in a system database. Expand as usual
				expand(node.nodePath)
			end
		end

		expand_count = expand_count - 1
		if expand_count == 0 then
			clean_up_and_return(cache)
		end
	end

	utils.register_lsp_handler(lsp_client, "objectexplorer/expandCompleted", expand_complete)

	expand(session.rootNode.nodePath)
	return coroutine.yield()
end

local generate_script_async = function(item, client)
	local scripting_params = {
		scriptDestination = "ToEditor",
		scriptingObjects = {
			{
				type = item.metadata.metadataTypeName,
				schema = item.metadata.schema,
				name = item.metadata.name,
			},
		},
		scriptOptions = {
			scriptCreateDrop = nodeTypes[item.objectType].scriptCreateDrop,
			typeOfDataToScript = "SchemaOnly",
			scriptStatistics = "ScriptStatsNone",
		},
		ownerURI = utils.lsp_file_uri(0),
		operation = nodeTypes[item.objectType].operation,
	}
	local res, script_err = utils.lsp_request_async(client, "scripting/script", scripting_params)
	if script_err then
		error("Error generating script: " .. vim.inspect({ err = script_err, scripting_params = scripting_params }), 0)
	end

	if not (res and res.script) then
		error("Error generating script (no script returned from language server)", 0)
	end

	return {
		-- strip carriage returns
		script = res.script:gsub("\r", ""),
		select = scripting_params.operation == 0,
	}
end

-- one cache per server and db (ie per connect opts)
local global_cache = {}

local function is_refreshing(connection_options)
	local key = connection_options
	if type(key) == "table" then
		key = vim.json.encode(connection_options)
	end

	return (
		global_cache[key]
		and global_cache[key].refresh_coroutine
		and type(global_cache[key].refresh_coroutine) == "thread"
		and coroutine.status(global_cache[key].refresh_coroutine) ~= "dead"
	)
end

-- Initialises the cache, unless it already exists
-- If force is true, then gets a new cache and overwrites
local initialise_cache_async = function(lsp_client, connection_options, force)
	local key = vim.json.encode(connection_options)
	if not global_cache[key] then
		global_cache[key] = {}
	end

	-- don't refresh if we are already refreshing or have refreshed previously
	if (global_cache[key].cache or is_refreshing(key)) and not force then
		return
	end

	-- cancel any currently running
	if global_cache[key].cancellation_token then
		global_cache[key].cancellation_token.cancel = true
	end
	local cancellation_token = { cancel = false }
	global_cache[key].cancellation_token = cancellation_token

	global_cache[key].refresh_coroutine = coroutine.running()
	vim.cmd("redrawstatus")
	utils.defer_async(5000)
	local new_cache = get_object_cache_async(lsp_client, connection_options, cancellation_token)
	if not cancellation_token.cancel then
		global_cache[key].cache = new_cache
	end
end

-- Picker
local picker_icons = {
	AggregateFunctionPartitionFunction = "󰡱",
	ScalarValuedFunction = "󰡱",
	StoredProcedure = "󰯁",
	TableValuedFunction = "󰡱",
	Table = "",
	View = "󱂬",
}

local pick_item_async = function(cache, title)
	local co = coroutine.running()

	local success, snacks = pcall(require, "snacks")
	if not success then
		return utils.ui_select_async(cache, {
			prompt = title,
			format_item = function(item)
				return table.concat({
					picker_icons[item.nodeType],
					" ",
					item.picker_path,
					item.label,
				})
			end,
		})
	end

	snacks.picker.pick({
		title = title,
		layout = "select",
		items = cache,
		format = function(item)
			return {
				{ picker_icons[item.nodeType], "SnacksPickerIcon" },
				{ " " },
				{ item.label },
				{ " " },
				{ item.picker_path, "SnacksPickerComment" },
			}
		end,
		confirm = function(picker, item)
			picker:close()
			coroutine.resume(co, item)
		end,
		cancel = function(picker)
			picker:close()
			coroutine.resume(co, nil)
		end,
	})
	return coroutine.yield()
end

local find_async = function(connection_options, lsp_client)
	local title = "Find"
	if connection_options and connection_options.database and connection_options.server then
		title = connection_options.server .. " | " .. connection_options.database
	end
	local key = vim.json.encode(connection_options)
	local cache = {}
	if global_cache[key] and global_cache[key].cache then
		cache = global_cache[key].cache
	end

	local item = pick_item_async(cache, title)
	if not item then
		return
	end
	return generate_script_async(item, lsp_client)
end

-- Checks for any cache entries not being used by any buffers and
-- deletes them
local function clean_cache()
	local in_use = {}
	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_loaded(buf) and vim.b[buf].query_manager then
			local key = vim.json.encode(vim.b[buf].query_manager.get_connect_params().connection.options)
			in_use[key] = true
		end
	end

	for cache_key, entry in pairs(global_cache) do
		if not in_use[cache_key] then
			if entry.cancellation_token then
				entry.cancellation_token.cancel = true
			end
			global_cache[cache_key] = nil
		end
	end
end
return {
	find_async = find_async,
	initialise_cache_async = initialise_cache_async,
	clean_cache = clean_cache,
	is_refreshing = is_refreshing,
}
