local utils = require("mssql.utils")
local pretty_print = require("mssql.query.pretty_print")

local function get_selected_text()
	local mode = vim.api.nvim_get_mode().mode
	if not (mode == "v" or mode == "V" or mode == "\22") then -- \22 is Ctrl-V (visual block)
		local content = vim.api.nvim_buf_get_lines(0, 0, vim.api.nvim_buf_line_count(0), false)
		return table.concat(content, "\n")
	end

	-- exit visual mode so the marks are applied
	local esc = vim.api.nvim_replace_termcodes("<esc>", true, false, true)
	vim.api.nvim_feedkeys(esc, "x", false)

	local start_pos = vim.fn.getpos("'<")
	local end_pos = vim.fn.getpos("'>")
	local lines = vim.fn.getregion(start_pos, end_pos, { mode = vim.fn.visualmode() })

	return table.concat(lines, "\n")
end

local result_buffers = {}

local function display_markdown(lines, buffer_name)
	local bufnr = vim.api.nvim_create_buf(true, false)
	table.insert(result_buffers, bufnr)
	vim.api.nvim_buf_set_name(bufnr, buffer_name)
	vim.bo[bufnr].filetype = "markdown"
	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
	vim.api.nvim_set_option_value("buftype", "nofile", { buf = bufnr })
	vim.api.nvim_set_option_value("bufhidden", "hide", { buf = bufnr })
	vim.api.nvim_set_option_value("swapfile", false, { buf = bufnr })
	vim.api.nvim_set_option_value("readonly", true, { buf = bufnr })
	vim.api.nvim_set_option_value("modifiable", false, { buf = bufnr })
	vim.api.nvim_set_current_buf(bufnr)
end

local function show_result_set_async(column_info, subset_params, max_width)
	local column_headers = vim.iter(column_info)
		:map(function(i)
			return i.columnName
		end)
		:totable()
	local client = utils.get_lsp_client(subset_params.ownerUri)

	local result, err = utils.lsp_request_async(client, "query/subset", subset_params)
	if err then
		error("Error getting rows: " .. vim.inspect(err), 0)
	elseif not result then
		error("Error getting rows", 0)
	end

	local rows = vim.iter(result.resultSubset.rows)
		:map(function(cells)
			return vim.iter(cells)
				:map(function(cell)
					return cell.displayValue
				end)
				:totable()
		end)
		:totable()

	local lines = pretty_print(column_headers, rows, max_width)
	display_markdown(
		lines,
		"results " .. subset_params.batchIndex + 1 .. "-" .. subset_params.resultSetIndex + 1 .. ".md"
	)
end

local function query_complete_async(opts, err, result)
	if err then
		error("Could not execute query: " .. vim.inspect(err), 0)
	elseif not (result or result.batchSummaries) then
		error("Could not execute query: no results returned" .. vim.inspect(err), 0)
	end

	-- delete existing result buffers
	for _, result_buffer in ipairs(result_buffers) do
		if vim.api.nvim_buf_is_valid(result_buffer) then
			vim.api.nvim_buf_delete(result_buffer, { force = true })
		end
	end

	for batch_index, batch_summary in ipairs(result.batchSummaries) do
		if batch_summary.resultSetSummaries then
			for result_set_index, result_set_summary in ipairs(batch_summary.resultSetSummaries) do
				-- fetch and show all results at once
				vim.schedule(function()
					utils.try_resume(coroutine.create(function()
						show_result_set_async(result_set_summary.columnInfo, {
							ownerUri = result.ownerUri,
							batchIndex = batch_index - 1,
							resultSetIndex = result_set_index - 1,
							rowsStartIndex = 0,
							rowsCount = opts.max_rows,
						}, opts.max_column_width)
					end))
				end)
			end
		end
	end
end

return {
	execute_async = function()
		local client = utils.get_lsp_client()
		local query = get_selected_text()
		local result, err = utils.lsp_request_async(
			client,
			"query/executeString",
			{ query = query, ownerUri = vim.uri_from_fname(vim.fn.expand("%:p")) }
		)

		if err then
			error("Error executing query: " .. err.message, 0)
		elseif not result then
			error("Could not execute query", 0)
		else
			utils.log_info("Executing...")
		end

		-- from here, the language server should send back some query/message evwnts then a final
		-- query/complete event.
	end,
	add_lsp_handlers = function(handlers, opts)
		handlers["query/complete"] = function(err, result)
			utils.try_resume(coroutine.create(function()
				query_complete_async(opts, err, result)
			end))
		end
		handlers["query/message"] = function(_, result)
			if not (result or result.message or result.message.message) then
				return
			end

			if result.message.isError then
				utils.log_error(result.message.message)
			else
				utils.log_info(result.message.message)
			end
		end
	end,
}
