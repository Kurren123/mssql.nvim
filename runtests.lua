local get_plugin_root = function()
	local current_file = debug.getinfo(1, "S").source:sub(2)
	local abs_path = vim.fn.fnamemodify(current_file, ":p")
	local current_dir = vim.fs.dirname(abs_path)

	return vim.fs.find("mssql.nvim", {
		upward = true,
		path = current_dir,
		type = "directory",
	})[1]
end

local function print_without_prompt(message)
	io.stdout:write(message .. "\n")
end

-- Prepend plugin root to runtimepath
vim.opt.rtp:prepend(get_plugin_root())
-- Disable swap files to avoid test errors
vim.opt.swapfile = false
-- Don't have autocomplete auto insert selections
vim.o.completeopt = "menu,menuone,noselect,noinsert"

local function run_test(test)
	print_without_prompt("=== Running: " .. test.test_name .. " ===")
	local success, err = pcall(test.run_test_async)

	if not success then
		print_without_prompt("\n" .. test.test_name .. " FAILED: " .. err)
		os.exit(1)
	else
		print_without_prompt("\nTest passed\n")
	end
end

local tests = {
	require("tests.download_spec"),
	require("tests.saved_file_completion_spec"),
	require("tests.edit_connections_spec"),
	require("tests.new_query_completion_spec"),
	require("tests.connect_spec"),
	-- Due to the internal timeout (see findings.md),
	-- This test in inconsistent
	-- require("tests.dbo_completion_spec"),
}

coroutine.resume(coroutine.create(function()
	for _, test in ipairs(tests) do
		run_test(test)
	end
	os.exit(0)
end))
