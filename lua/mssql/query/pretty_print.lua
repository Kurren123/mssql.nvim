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

return pretty_print
