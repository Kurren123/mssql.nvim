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

require("mssql").setup()

dofile("tests/completion_spec.lua")

local test_files = {
	-- "tests/download_spec.lua",
	"tests/completion_spec.lua",
}

local has_failures = false

for _, file in ipairs(test_files) do
	print("Running: " .. file)
	local ok, err = pcall(dofile, file)
	if not ok then
		has_failures = true
		io.stderr:write("Error in " .. file .. ":\n" .. tostring(err) .. "\n")
		break
	else
		print("Passed: " .. file)
	end
end

-- Exit with proper code
os.exit(has_failures and 1 or 0)
