vim.opt.rtp:prepend("C:/dev/mssql.nvim/")

vim.api.nvim_create_user_command("Pick", function()
	require("mssql").pick()
end, {})
