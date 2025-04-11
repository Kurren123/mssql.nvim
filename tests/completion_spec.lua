-- test comletions on a saved file
vim.cmd("e tests/completion.sql")
vim.api.nvim_win_set_cursor(0, { 1, 1 })

local params = vim.lsp.util.make_position_params(0, "utf-8")
local result

vim.lsp.buf_request(0, "textDocument/completion", params, function(err, result, ctx, config)
	if err then
		result = { err = err }
		return
	end
	if not result then
		result = { err = "No LSP completion result" }
		return
	end

	local items = vim.lsp.util.extract_completion_items(result)
	result = { count = #items }
end)

local ok, err = pcall(function()
	vim.wait(10000, function()
		return result ~= nil
	end, 10)
end)

assert(ok, "setup() threw: " .. (err or ""))
assert(not result.err, "Lsp threw:" .. result.err)
assert(not result.count ~= 0, "0 completion items were returned")
