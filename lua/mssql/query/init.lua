local function get_selected_text()
	local mode = vim.api.nvim_get_mode().mode
	if not (mode == "v" or mode == "V" or mode == "\22") then -- \22 is Ctrl-V (visual block)
		local content = vim.api.nvim_buf_get_lines(0, 0, vim.api.nvim_buf_line_count(0), false)
		return "not in visual mode" -- table.concat(content, "\n")
	end

	-- exit visual mode so the marks are applied
	local esc = vim.api.nvim_replace_termcodes("<esc>", true, false, true)
	vim.api.nvim_feedkeys(esc, "x", false)
	-- -- utils.wait_for_schedule_async()

	local start_pos = vim.fn.getpos("'<")
	local end_pos = vim.fn.getpos("'>")
	local lines = vim.fn.getregion(start_pos, end_pos, { mode = vim.fn.visualmode() })

	return table.concat(lines, "\n")
end

return {
	execute_async = function()
		local query = get_selected_text()
	end,
}
