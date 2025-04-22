![workflow status badge](https://github.com/Kurren123/mssql.nvim/actions/workflows/test.yml/badge.svg)

# mssql.nvim

An SQL Server plugin for neovim. **Not ready yet!** If you are looking for something usable, come back later.

## To do

- [x] Download and extract the sql tools
- [x] Basic LSP configuration
- [x] Basic (disconected) auto complete for saved sql files
- [x] Auto complete for new queries (unsaved buffer)
- [ ] Connect to a database

## Requirements

- Neovim v0.11.0 or later

## Setup

```lua
-- Basic setup
require("mssql.nvim").setup()

-- With options
require("mssql.nvim").setup({
  data_dir = "/custom/path",
  tools_file = "/path/to/sqltools/executable",
  connections_file = "/path/to/connections.json"
})

-- With callback
require("mssql.nvim").setup({
  data_dir = "/custom/path"
}, function()
  print("mssql.nvim is ready!")
end)
```

### Options

| Name               | Type     | Required?  | Description                                                   | Default                                      |
| ------------------ | -------- | ---------- | ------------------------------------------------------------- | -------------------------------------------- |
| `data_dir`         | `string` | `Optional` | Directory to store download tools and internal config options | `vim.fn.stdpath("data")`                     |
| `tools_file`       | `string` | `Optional` | Path to an existing SQL Server tools binary                   | `nil` (Binary auto downloaded to `data_dir`) |
| `connections_file` | `string` | `Optional` | Path to a json file containing connections (see below)        | `<data_dir>/connections.json`                |

### Notes

- `setup()` runs asynchronously as it may take some time to first download and extract the sql tools. Pass a callback as the second argument if you need to run code after initialization.

## Provided functions

```lua
local mssql = require("mssql")

-- Open a new buffer for sql queries
mssql.new_query()
```
