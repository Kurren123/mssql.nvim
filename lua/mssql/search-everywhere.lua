local picker = require("snacks").picker

local pick = function()
	picker.pick({
		title = "test",
		layout = "select",
		finder = function(config, ctx)
			return function(emit)
				vim.defer_fn(function()
					emit({ icon = "", text = "table" })
					ctx.async:resume()
				end, 2000)
				emit({ icon = "󰡱", text = "stored procedure" })
				emit({ icon = "󱂬", text = "view" })
				ctx.async:suspend()
			end
		end,
		format = function(item)
			return {
				{ item.icon, "SnacksPickerIcon" },
				{ " " },
				{ "path here", "SnacksPickerComment" },
				{ " " },
				{ item.text },
			}
		end,
		confirm = function(picker, item)
			picker:close()
			vim.notify(vim.inspect(item))
		end,
	})
end

local utils = require("mssql.utils")

---Same as utils.wait_for_notification_async but ignores any owner uri
---@param client vim.lsp.Client
---@param method string
---@param timeout integer
---@return any result
---@return lsp.ResponseError? error
local wait_for_notification_async = function(client, method, timeout)
	local this = coroutine.running()
	local existing_handler = client.handlers[method]
	client.handlers[method] = function(err, result, ctx)
		if existing_handler then
			vim.notify("abc")
			existing_handler(err, result, ctx)
		end

		vim.lsp.handlers[method] = existing_handler
		utils.try_resume(this, result, err)
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

get_session = function()
	utils.try_resume(coroutine.create(function()
		local client = vim.b.query_manager.get_lsp_client()

		local params = vim.b.query_manager.get_connect_params().connection.options
		params.ServerName = params.server
		params.DatabaseName = params.database
		params.UserName = params.user
		params.EnclaveAttestationProtocol = params.attestationProtocol

		utils.lsp_request_async(client, "objectexplorer/createsession", params)
		local response, err = wait_for_notification_async(client, "objectexplorer/sessioncreated", 10000)
		utils.safe_assert(not err, vim.inspect(err))
		vim.notify(vim.inspect(response))
		r = response
		return response
	end))
end

expand = function(path)
	utils.try_resume(coroutine.create(function()
		local client = vim.b.query_manager.get_lsp_client()
		utils.lsp_request_async(client, "objectexplorer/expand", {
			sessionId = ".__NULL_Integrated_3AE169C4-E7DF-495F-98F0-2A75C692A8BB_applicationName:vscode-mssql_encrypt:Mandatory_id:3AE169C4-E7DF-495F-98F0-2A75C692A8BB_trustServerCertificate:true",
			nodePath = "./Security/Server Roles",
		})
		local response, err = wait_for_notification_async(client, "objectexplorer/expandCompleted", 10000)
		vim.notify(vim.inspect({ response, err }))
	end))
end
