local utils = require("mssql.utils")

local function sanitise(table, limit)
	for _, record in ipairs(table) do
		for index, value in ipairs(record) do
			local str = tostring(value)
			-- truncate
			if vim.fn.strdisplaywidth(str) > limit then
				str = str:sub(1, limit) .. "..."
			end
			-- replace newline chars with `\n`. Backticks to look good in markdown
			str = str:gsub("\n", "`\\n`")
			record[index] = str
		end
	end
end

local function column_width(column_header, rows, column_index)
	local row_max = vim.iter(rows)
		:map(function(record)
			return vim.fn.strdisplaywidth(record[column_index])
		end)
		:fold(0, math.max)

	return math.max(vim.fn.strdisplaywidth(column_header), row_max)
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
	if vim.fn.strdisplaywidth(str) >= len then
		return str
	end
	return str .. string.rep(char, len - vim.fn.strdisplaywidth(str))
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

	sanitise(rows, max_width)

	local widths = column_widths(column_headers, rows)
	local divider = header_divider(widths)

	local lines = { row_to_string(column_headers, widths), divider }
	for _, row in ipairs(rows) do
		table.insert(lines, row_to_string(row, widths))
	end

	return lines
end

local result_buffers = {}

local function create_buffer(name, filetype)
	local bufnr = vim.api.nvim_create_buf(true, false)
	table.insert(result_buffers, bufnr)
	vim.api.nvim_buf_set_name(bufnr, name)
	if filetype and filetype ~= "" then
		vim.bo[bufnr].filetype = filetype
	end
	return bufnr
end

local function display_markdown(lines, bufnr)
	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
	vim.api.nvim_set_option_value("buftype", "nofile", { buf = bufnr })
	vim.api.nvim_set_option_value("bufhidden", "hide", { buf = bufnr })
	vim.api.nvim_set_option_value("swapfile", false, { buf = bufnr })
	vim.api.nvim_set_option_value("readonly", true, { buf = bufnr })
	vim.api.nvim_set_option_value("modifiable", false, { buf = bufnr })
	vim.api.nvim_set_current_buf(bufnr)
end

local function show_result_set_async(column_info, subset_params, opts)
	local column_headers = vim.iter(column_info)
		:map(function(i)
			return i.columnName
		end)
		:totable()

	local rows = utils.get_rows_async(subset_params)
	local lines = pretty_print(column_headers, rows, opts.max_column_width)
	local extension = opts.results_buffer_extension
	extension = extension or ""
	if extension ~= "" then
		extension = "." .. extension
	end

	local buf = create_buffer(
		"results " .. subset_params.batchIndex + 1 .. "-" .. subset_params.resultSetIndex + 1 .. extension,
		opts.results_buffer_filetype
	)
	vim.b[buf].query_result_info = { subset_params = subset_params }
	display_markdown(lines, buf)
end

local function display_query_results(opts, result)
	-- delete existing result buffers
	for _, result_buffer in ipairs(result_buffers) do
		if vim.api.nvim_buf_is_valid(result_buffer) then
			vim.api.nvim_buf_delete(result_buffer, { force = true })
		end
	end

	for batch_index, batch_summary in ipairs(result.batchSummaries) do
		if not batch_summary.hasError and batch_summary.resultSetSummaries then
			for result_set_index, result_set_summary in ipairs(batch_summary.resultSetSummaries) do
				local subset_params = {
					ownerUri = result.ownerUri,
					batchIndex = batch_index - 1,
					resultSetIndex = result_set_index - 1,
					rowsStartIndex = 0,
					rowsCount = math.min(result_set_summary.rowCount, opts.max_rows),
				}
				-- fetch and show all results at once
				vim.schedule(function()
					utils.try_resume(coroutine.create(function()
						show_result_set_async(result_set_summary.columnInfo, subset_params, opts)
					end))
				end)
			end
		end
	end
end

return display_query_results
