vim.opt.rtp:prepend("C:/dev/mssql.nvim/")

vim.api.nvim_create_user_command("HelloWorld", function()
	require("mssql").say_hello()
end, {})
