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

-- Prepend plugin root to runtimepath
vim.opt.rtp:prepend(get_plugin_root())
-- Disable swap files to avoid test errors
vim.opt.swapfile = false

local function run_test(test)
	print("=== Running: " .. test.test_name .. " ===\n")
	local success, err = pcall(test.run_test_async)

	if not success then
		print("\n" .. test.test_name .. " FAILED: " .. err .. "\n")
		os.exit(1)
	else
		print("\nTest passed\n\n")
	end
end

local tests = { require("tests.download_spec"), require("tests.completion_spec") }

coroutine.resume(coroutine.create(function()
	for _, test in ipairs(tests) do
		run_test(test)
	end
	os.exit(0)
end))
