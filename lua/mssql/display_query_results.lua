local utils = require("mssql.utils")

local function truncate_values(table, limit)
	for _, record in ipairs(table) do
		for index, value in ipairs(record) do
			local str = tostring(value)
			if #str > limit then
				str = str:sub(1, limit) .. "..."
			end
			record[index] = str
		end
	end
end

local function column_width(column_header, rows, column_index)
	local row_max = vim.iter(rows)
		:map(function(record)
			return #record[column_index]
		end)
		:fold(0, math.max)

	return math.max(#column_header, row_max)
end

local function column_widths(column_headers, rows)
	if not column_headers then
		return {}
	end

	return vim.iter(ipairs(column_headers))
		:map(function(column_index, column_header)
			return column_width(column_header, rows, column_index)
		end)
		:totable()
end

local function right_pad(str, len, char)
	if #str >= len then
		return str
	end
	return str .. string.rep(char, len - #str)
end

local function row_to_string(row, widths)
	local padded_cells = vim.iter(ipairs(row))
		:map(function(column_index, value)
			return right_pad(value, widths[column_index], " ")
		end)
		:totable()
	return "| " .. table.concat(padded_cells, " | ") .. " |"
end

local function header_divider(widths)
	if not widths then
		return ""
	end

	local dashes_row = vim.iter(widths)
		:map(function(width)
			return string.rep("-", width)
		end)
		:totable()
	return row_to_string(dashes_row, widths)
end

local function pretty_print(column_headers, rows, max_width)
	if not column_headers then
		return ""
	end

	truncate_values(rows, max_width)

	local widths = column_widths(column_headers, rows)
	local divider = header_divider(widths)

	local lines = { row_to_string(column_headers, widths), divider }
	for _, row in ipairs(rows) do
		table.insert(lines, row_to_string(row, widths))
	end

	return lines
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

local function display_query_results(opts, result)
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

return display_query_results
