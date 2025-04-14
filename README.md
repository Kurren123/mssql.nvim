# mssql.nvim

An SQL Server plugin for neovim. **Not ready yet!** If you are looking for something usable, come back later.

## To do

- [x] Download and extract the sql tools
- [x] Basic LSP configuration
- [x] Basic (disconected) auto complete for saved sql files
- [ ] Basic (disconnected) auto complete for new (unsaved) buffers
- [ ] Connect to a database

## Requirements

- Neovim v0.11.0 or later

## Usage

```lua
-- Basic setup
require("mssql.nvim").setup()

-- With options
require("mssql.nvim").setup({
  data_dir = "/custom/path",                    -- optional, defaults to vim.fn.stdpath("data")
  tools_file = "/path/to/sqltools/executable",  -- optional, if not provided, auto-downloads to data_dir
})

-- With callback
require("mssql.nvim").setup({
  data_dir = "/custom/path"
}, function()
  print("mssql.nvim is ready!")
end)
```

## Options

Option Description Default
data_dir Directory to store tools (if downloading) vim.fn.stdpath("data")
tools_file Path to existing SQL Server tools binary. If not set, downloads it. auto-downloaded if needed

## Notes

- `setup()` runs asynchronously as it may take some time to first download and extract the sql tools. Pass a callback as the second argument if you need to run code after initialization.
- If `tools_file` is not provided and the sql tools are not already downloaded, it will be downloaded and extracted into the `data_dir` upon `setup`.
