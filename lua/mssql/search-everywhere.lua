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
	local existing_handler = client.handlers[method]
	client.handlers[method] = function(err, result, ctx)
		if existing_handler then
			existing_handler(err, result, ctx)
		end

		if not resumed then
			resumed = true
			vim.lsp.handlers[method] = existing_handler
			utils.try_resume(this, result, err)
		end
		return result, err
	end

	vim.defer_fn(function()
		if not resumed then
			resumed = true
			vim.lsp.handlers[method] = existing_handler
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

local session_id

local get_session = function()
	local client = vim.b.query_manager.get_lsp_client()

	local params = vim.b.query_manager.get_connect_params().connection.options
	params.ServerName = params.server
	params.DatabaseName = params.database
	params.UserName = params.user
	params.EnclaveAttestationProtocol = params.attestationProtocol

	-- For some reason, if there is no display name set on the connection parameters then
	-- the language server will treat this as a default/system database:
	-- https://github.com/microsoft/sqltoolsservice/blob/49036c6196e73c3791bca5d31e97a16afee00772/src/Microsoft.SqlTools.ServiceLayer/ObjectExplorer/ObjectExplorerService.cs#L537
	params.DatabaseDisplayName = params.DatabaseDisplayName or params.database

	utils.lsp_request_async(client, "objectexplorer/createsession", params)
	local response, err = wait_for_notification_async(client, "objectexplorer/sessioncreated", 10000)
	utils.safe_assert(not err, vim.inspect(err))
	return response
end

--[[
--NOTE: 
--The search everywhere plugin caches results the first time search is opened. We can do the same thing: cache results on 
--connect, have a user command to refresh the search cache.
--]]
local nodeTypes = {
	AggregateFunctionPartitionFunction = "alter",
	ScalarValuedFunction = "alter",
	StoredProcedure = "alter",
	TableValuedFunction = "alter",
	Table = "select",
	View = "select",
}

local expand_count = 0

local expand = function(sessionId, path)
	vim.schedule(function()
		expand_count = expand_count + 1
		local client = vim.b.query_manager.get_lsp_client()
		client:request("objectexplorer/expand", {
			sessionId = sessionId,
			nodePath = path,
		}, function(err, result, _, _)
			return result, err
		end)
	end)
end

cache = {}
local root_path = ""

local expand_complete = function(err, result, ctx)
	if not result then
		return
	end

	for _, node in ipairs(result.nodes) do
		if nodeTypes[node.objectType] then
			local path = node.parentNodePath
			node.pickerPath = string.sub(path, #root_path + 2, #path) .. "/"
			node.text = node.pickerPath .. node.label
			table.insert(cache, node)
		elseif node.nodePath then
			expand(session_id, node.nodePath)
		else
			vim.notify("no node path")
			vim.notify(vim.inspect(node))
		end
	end

	expand_count = expand_count - 1
	if expand_count == 0 then
		-- disconnect when we've finished caching
		local client = vim.b.query_manager.get_lsp_client()
		client:request("objectExplorer/closeSession", {
			sessionId = session_id,
		}, function(err, result, _, _)
			session_id = nil
			return result, err
		end)
	end
end

refresh_cache = function()
	cache = {}
	local client = vim.b.query_manager.get_lsp_client()

	client.handlers["objectexplorer/expandCompleted"] = nil -- delete this
	if client.handlers["objectexplorer/expandCompleted"] == nil then
		client.handlers["objectexplorer/expandCompleted"] = expand_complete
	end

	utils.try_resume(coroutine.create(function()
		local session = get_session()
		utils.safe_assert(session and session.sessionId, "Could not create a session")

		session_id = session.sessionId
		root_path = session.rootNode.nodePath
		expand(session.sessionId, session.rootNode.nodePath)
	end))
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

local picker = require("snacks").picker
find = function()
	picker.pick({
		title = "Find",
		layout = "select",
		items = cache,
		format = function(item)
			return {
				{ picker_icons[item.nodeType], "SnacksPickerIcon" },
				{ " " },
				{ item.pickerPath, "SnacksPickerComment" },
				-- { " " },
				{ item.label },
			}
		end,
		--TODO: fix searching, and select the item
		confirm = function(picker, item)
			picker:close()
			vim.notify(vim.inspect(item))
		end,
	})
end
