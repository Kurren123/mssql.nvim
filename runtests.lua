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

local src = vim.fn.stdpath("state")
print_without_prompt("nvim state path: " .. src)
vim.lsp.set_log_level("debug")

local function copy_state_folder()
	if vim.env.GITHUB_ACTIONS == "true" then
		local src = vim.fn.stdpath("state")
		print_without_prompt("nvim state path: " .. src)
		local dst = "nvim-state-dump"

		if vim.fn.has("win32") == 1 then
			vim.fn.system({ "xcopy", "/E", "/I", "/Y", src, dst })
		else
			vim.fn.system({ "cp", "-r", src, dst })
		end
	end
end

local function run_test(test)
	print_without_prompt("=== Running: " .. test.test_name .. " ===")
	local success, err = pcall(test.run_test_async)

	if not success then
		print_without_prompt("\n" .. test.test_name .. " FAILED: " .. err)
		copy_state_folder()
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
	require("tests.dbo_completion_spec"),
	require("tests.execute_query_spec"),
	require("tests.switch_database_spec"),
	require("tests.finder_spec"),
	require("tests.query_zero_rows_spec"),
	require("tests.file_with_space_spec"),
	require("tests.non_ascii_spec"),
	require("tests.cancel_query_spec"),
	require("tests.use_query_spec"),
	require("tests.lualine_component_spec"),
}

coroutine.resume(coroutine.create(function()
	for _, test in ipairs(tests) do
		run_test(test)
	end
	os.exit(0)
end))
