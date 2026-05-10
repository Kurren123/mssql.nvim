---@class IconsOpts
---@field enabled boolean
---@field disconnected string?
---@field server string?
---@field database string?

return {
	-- Set up keymaps with this prefix. If which-key is found, this will be a which-key group.
	keymap_prefix = nil,

	--[[ How to open a buffer containing sql results.
  Valid options are: 
  "split"                   - Open results in a horizontal split
  "vsplit"                  - Open results in a vertical split
  "current_window"          - Open results in the current window
  function (bufnr) ... end  - Function which takes the buffer number of the results buffer to open 
                              (called for each results buffer if there are multiple). Use this 
                              to open the buffer in a custom way
  --]]
	open_results_in = "split",

	--[[ Where to view messages sent from sql server (eg when executing queries)
  Valid options are: 
  "notification"                        - View as a vim notification
  "buffer"                              - View in a messages buffer
  function(message, is_error) ...       - Function which takes the message string and is_error boolean
                                          (called for each message). Use this to view messages in a custom way
  --]]
	view_messages_in = "notification",

	-- Max rows to return for queries. Needed so that large results don't crash neovim.
	max_rows = 100,

	-- If a result row has a field text length larger than this it will be truncated when displayed
	max_column_width = 100,

	-- When choosing a table/view in the finder, immediately execute the generated SELECT statement
	execute_generated_select_statements = true,

	-- Settings passed to the mssql language server. See https://github.com/Kurren123/mssql.nvim/blob/main/docs/Lsp-Settings.md
	lsp_settings = {
		format = {
			placeSelectStatementReferencesOnNewLine = true,
			keywordCasing = "Uppercase",
			datatypeCasing = "Uppercase",
			alignColumnDefinitionsInColumns = true,
		},
	},

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

	-- Path to a json connections file (see https://github.com/Kurren123/mssql.nvim?tab=readme-ov-file#connections-json-file)
	-- If nil, it's stored in the data_dir
	connections_file = nil,

	-- Path to an existing SQL tools service binary (see https://github.com/microsoft/sqltoolsservice/releases).
	-- If nil, then the binary is auto downloaded to data_dir
	tools_file = nil,

	-- Directory to store download tools and internal config options
	data_dir = vim.fs.joinpath(vim.fn.stdpath("data"), "/mssql.nvim"):gsub("[/\\]+$", ""),

	-- Configuration for icons in default lualine component
	---@type IconsOpts
	icons = {
		enabled = false,
		disconnected = "",
		server = "",
		database = "",
	}
}
