vim.opt.rtp:prepend(".")

local test_files = {
	"tests/hello_spec.lua",
}

local has_failures = false

for _, file in ipairs(test_files) do
	print("Running: " .. file)
	local ok, err = pcall(dofile, file)
	if not ok then
		has_failures = true
		io.stderr:write("Error in " .. file .. ":\n" .. tostring(err) .. "\n")
	else
		print("Passed: " .. file)
	end
end

-- Exit with proper code
os.exit(has_failures and 1 or 0)
