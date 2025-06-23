return {
	-- Set up keymaps with this prefix. If which-key is found, this will be a which-key group.
	keymap_prefix = nil,

	-- Max rows to return for queries. Needed so that large results don't crash neovim.
	max_rows = 100,

	-- If a result row has a field text length larger than this it will be truncated when displayed
	max_column_width = 100,

	-- Settings passed to the mssql language server. See https://github.com/Kurren123/mssql.nvim/blob/main/docs/Lsp-Settings.md
	lsp_settings = {
		format = {
			placeSelectStatementReferencesOnNewLine = true,
			keywordCasing = "Uppercase",
			datatypeCasing = "Uppercase",
			alignColumnDefinitionsInColumns = true,
		},
	},

	-- Directory to store download tools and internal config options
	data_dir = vim.fs.joinpath(vim.fn.stdpath("data"), "/mssql.nvim"):gsub("[/\\]+$", ""),

	-- Path to a json connections file (see https://github.com/Kurren123/mssql.nvim?tab=readme-ov-file#connections-json-file)
	-- If nil, it's stored in the data_dir
	connections_file = nil,

	-- Path to an existing SQL tools service binary (see https://github.com/microsoft/sqltoolsservice/releases).
	-- If nil, then the binary is auto downloaded to data_dir
	tools_file = nil,

	-- Options that will be set on buffers of sql file type (see https://neovim.io/doc/user/options.html)
	sql_buffer_options = {
		expandtab = true,
		tabstop = 4,
		shiftwidth = 4,
		softtabstop = 4,
	},

	-- The file extension of buffers that show query results
	results_buffer_extension = "md",

	-- The filetype (used in neovim to determine the language) of buffers that show query results. Set this to "" to disable markdown rendering.
	results_buffer_filetype = "markdown",

	-- When choosing a table/view in the finder, immediately execute the generated SELECT statement
	execute_generated_select_statements = true,
}
