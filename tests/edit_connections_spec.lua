local mssql = require("mssql")

return {
	test_name = "Edit connections",
	run_test_async = function()
		mssql.edit_connections()

		local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
		-- Assert that the connection json opens, and it has
		-- some example text. Rather than asserting the exact text,
		-- just do a weak assert of testing that a curly brace exists.
		-- This will let us change the example without the test breaking
		assert(
			vim.iter(lines):any(function(line)
				return line:find("{")
			end),
			"No json was found after calling edit_connections"
		)

		local connections = string.format(
			[[
{
  "master": {
    "server": "%s",
    "database": "%s",
    "authenticationType": "SqlLogin",
    "user": "%s",
    "password": "%s",
    "trustServerCertificate": true
  }
}
]],
			os.getenv("DbServer"),
			os.getenv("DbDatabase"),
			os.getenv("DbUser"),
			os.getenv("DbPassword")
		)

		vim.api.nvim_buf_set_lines(0, 0, -1, false, vim.split(connections, "\n"))
		vim.cmd("w")
	end,
}
