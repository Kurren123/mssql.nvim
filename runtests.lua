package.path = package.path .. ";.rocks/share/lua/5.1/?.lua;.rocks/share/lua/5.1/?/init.lua"
vim.opt.rtp:prepend(".")

local test_files = vim.fn.glob("tests/**/*_spec.lua", false, true)
local has_failures = false

for _, file in ipairs(test_files) do
	if type(file) == "string" and file ~= "" then
		file = file:gsub("\\", "/")
		print("Running: " .. file)
		local ok, err = pcall(dofile, file)
		if not ok then
			has_failures = true
			io.stderr:write("❌ Error in " .. file .. ":\n" .. tostring(err) .. "\n")
		else
			print("✅ Passed: " .. file)
		end
	end
end

-- Exit with status code: 0 if OK, 1 if failure
os.exit(has_failures and 1 or 0)
