local function map(tbl, fn)
	local result = {}
	for i, v in ipairs(tbl) do
		result[i] = fn(v)
	end
	return result
end

local function contains(tbl, element)
	if not table then
		return false
	end
	for _, v in pairs(tbl) do
		if v == element then
			return true
		end
	end
	return false
end

return {
	map = map,
	contains = contains,
}
