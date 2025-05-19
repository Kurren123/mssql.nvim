local utils = require("mssql.utils")

return {
	defer_async = utils.defer_async,
	get_completion_items = function()
		local client = vim.lsp.get_clients({ bufnr = 0 })[1]
		local position = vim.lsp.util.make_position_params(0, "utf-8")
		position.position.character = position.position.character + 1
		local response, err = client:request_sync("textDocument/completion", position)
		assert(not err, "Error returned when requesting completions: " .. vim.inspect(err))
		assert(response and response.result and response.result, "No completion items were returned")

		return vim.iter(response.result)
			:map(function(item)
				return item.label
			end)
			:totable()
	end,

	ui_select_fake = function(item)
		local original_select = vim.ui.select
		---@diagnostic disable-next-line: duplicate-set-field
		vim.ui.select = function(items, _, on_choice)
			vim.ui.select = original_select
			local index = vim.fn.index(items, item)
			if index == nil or index == -1 then
				error("You tried to choose " .. item .. "when prompted but this wasn't an option", 0)
			end
			vim.defer_fn(function()
				on_choice(item, index + 1)
			end, 3000)
		end
	end,
}
