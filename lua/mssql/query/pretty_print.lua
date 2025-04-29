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

local function column_width(table, column_index)
	return vim.iter(table)
		:map(function(record)
			return #record[column_index]
		end)
		:fold(0, math.max)
end

local function column_widths(table)
	if not (table or table[1]) then
		return {}
	end

	return vim.iter(ipairs(table[1]))
		:map(function(column_index)
			return column_width(table, column_index)
		end)
		:totable()
end

local function header_divider(widths)
	if not widths then
		return ""
	end
	local dashes = vim.iter(widths)
		:map(function(w)
			return string.rep("-", w + 2)
		end)
		:totable()
	return "+" .. table.concat(dashes, "+") .. "+"
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

return function(query_results, max_width)
	truncate_values(query_results, max_width)

	if not (query_results or query_results[1]) then
		return ""
	end

	local widths = column_widths(query_results)
	local divider = header_divider(widths)

	local lines = { divider, row_to_string(query_results[1], widths), divider }
	for i = 2, #query_results do
		table.insert(lines, row_to_string(query_results[i], widths))
	end
	table.insert(lines, divider)

	return table.concat(lines, "\n")
end
