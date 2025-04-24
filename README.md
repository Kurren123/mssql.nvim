![workflow status badge](https://github.com/Kurren123/mssql.nvim/actions/workflows/test.yml/badge.svg)

# mssql.nvim

An SQL Server plugin for neovim. **Not ready yet!** If you are looking for something usable, come back later.

## To do

- [x] Download and extract the sql tools
- [x] Basic LSP configuration
- [x] Basic (disconected) auto complete for saved sql files
- [x] Auto complete for new queries (unsaved buffer)
- [x] Connect to a database
- [x] Have auto complete include database objects
- [x] Cross database query autocomplete
- [ ] Disconnect
- [ ] Execute queries (first few lines only)
- [ ] Switch database

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

| Name               | Type      | Description                                                                                           | Default                                      |
| ------------------ | --------- | ----------------------------------------------------------------------------------------------------- | -------------------------------------------- |
| `data_dir`         | `string?` | Directory to store download tools and internal config options                                         | `vim.fn.stdpath("data")`                     |
| `tools_file`       | `string?` | Path to an existing [SQL tools service](https://github.com/microsoft/sqltoolsservice/releases) binary | `nil` (Binary auto downloaded to `data_dir`) |
| `connections_file` | `string?` | Path to a json file containing connections (see below)                                                | `<data_dir>/connections.json`                |

### Notes

- `setup()` runs asynchronously as it may take some time to first download and extract the sql tools. Pass a callback as the second argument if you need to run code after initialization.

## Usage

```lua
local mssql = require("mssql")

-- Open sql connections file for editing. See below for more
mssql.edit_connections()

-- Open a new buffer for sql queries
mssql.new_query()

-- Connect (you'll be prompted to choose a connection)
mssql.connect()
```

## Connections json file

The format is `"connection name": connection object`. Eg:

```json
{
  "Connection A": {
    "server": "localhost",
    "database": "dbA",
    "authenticationType": "SqlLogin",
    "user": "Admin",
    "password": "Your_Password",
    "trustServerCertificate": true
  },
  "Connection B": {
    "server": "AnotherServer",
    "database": "dbB",
    "authenticationType": "Integrated"
  },
  "Connection C": {
    "connectionString": "Server=myServerAddress;Database=myDataBase;User Id=myUsername;Password=myPassword;"
  }
}
```

[Full details of the connection json here](docs/Connections-Json.md).
