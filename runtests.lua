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

local function run_test(name, test_fn, next_fn)
	print("Running " .. name .. "\n")
	local success, err = pcall(function()
		test_fn(function()
			print("\ntest passed\n")
			if next_fn then
				next_fn()
			end
		end)
	end)

	if not success then
		print("\n" .. name .. " FAILED: " .. err .. "\n")
		os.exit(1)
	end
end

run_test("download_spec", require("tests.download_spec").run_test, function()
	run_test("completion_spec", require("tests.completion_spec").run_test, function()
		os.exit(0)
	end)
end)
