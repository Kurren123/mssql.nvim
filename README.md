![workflow status badge](https://github.com/Kurren123/mssql.nvim/actions/workflows/test.yml/badge.svg)

# mssql.nvim

<p align="center" >
<img src="./docs/Logo.png" alt="Logo" width="200" />
</p>

<p align="center" >
An SQL Server plugin for neovim. Like it? Give a ⭐️!
</p>

## Features

Completions, including TSQL keywords,

<img src="./docs/screenshots/Tsql_completion.png" alt="Tsql keywords screenshot" width="300"/>

stored procedures

<img src="./docs/screenshots/Stored_procedure_completion.png" alt="stored procedures screenshot" width="300"/>

and cross database queries

<img src="./docs/screenshots/Cross_db_completion.png" alt="Cross db completion" width="300"/>

Execute queries, with results in markdown tables for automatic colouring and
rendering

![results screenshot](./docs/screenshots/Results.png)

Optional which-key integration, showing only the key maps which are possible (eg
don't show `Connect` if we are already connected)

<img src="./docs/screenshots/Which-key.png" alt="Which key screenshot" width="300"/>

Lualine integration

<img src="./docs/screenshots/Lualine.png" alt="Which key screenshot" width="600"/>

## Installation

Requires Neovim v0.11.0 or later.

<details>
<summary>lazy.nvim</summary>

```lua
{
  "Kurren123/mssql.nvim",
  opts = {},
  -- optional. You also need to call set_keymaps (see below)
  dependencies = { "folke/which-key.nvim" }
}
```

</details>

<details>
<summary>Packer</summary>

```lua
require("packer").startup(function()
  use({
    "Kurren123/mssql.nvim",
    -- optional. You also need to call set_keymaps (see below)
    requires = { 'folke/which-key.nvim' },
    config = function()
      require("mssql").setup()
    end,
  })
end)
```

</details>

<details>
<summary>Paq</summary>

```lua
require("paq")({
  { "stevearc/conform.nvim" },
  -- optional. You also need to call set_keymaps (see below)
  { "folke/which-key.nvim" }
})
```

</details>

## Setup

```lua
require("mssql").setup()
-- then in your keymaps file with a prefix of your choice:
require("mssql").set_keymaps("<leader>d")
```

Pass in a prefix to `set_keymaps` to have all keymaps set up with that prefix
first. In the above example, new query would be `<leader>dn`. If you have
which-key installed, then the prefix you provide will be a which-key group.

### Lualine

Insert `require("mssql").lualine_component` into a lualine section (eg
`lualine_c`).

Eg in lazyvim this would be:

```lua
return {
  "nvim-lualine/lualine.nvim",
  dependencies = { "Kurren123/mssql.nvim" },
  opts = function(_, opts)
    table.insert(opts.sections.lualine_c, require("mssql").lualine_component)
    return opts
  end,
}
```

You can also use the `lualine_component` in other status lines.

## Usage

You can call the following as key maps typing your [prefix](#setup) first, or as
functions on `require("mssql")`.

| Key map | Function                       | Description                                                                                                                                                                       |
| ------- | ------------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `n`     | `new_query()`                  | Open a new buffer for sql queries                                                                                                                                                 |
| `c`     | `connect()`                    | Connect the current buffer (you'll be prompted to choose a connection)                                                                                                            |
| `x`     | `execute_query()`              | Execute the selection, or the whole buffer                                                                                                                                        |
| `q`     | `disconnect()`                 | Disconnects the current buffer                                                                                                                                                    |
| `s`     | `switch_database()`            | Prompts, then switches to a database that is on the currently connected server                                                                                                    |
| `d`     | `new_default_query()`          | Opens a new query and connects to the connection called `default` in your `connections.json`. Useful when combined with the `promptForDatabase` option in the `connections.json`. |
| `r`     | `refresh_intellisense_cache()` | Rebuild the intellisense cache                                                                                                                                                    |
| `e`     | `edit_connections()`           | Open the [connections file](#connections-json-file) for editing                                                                                                                   |

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
    "authenticationType": "Integrated",
    "promptForDatabase": true
  }
}
```

Each connection object takes
[standard connection properties](docs/Connections-Json.md). On top of those, you
can also provide these useful properties:

| Property            | Type   | Description                                                          |
| ------------------- | ------ | -------------------------------------------------------------------- |
| `promptForDatabase` | `bool` | After connecting to the server, select which database to connect to. |

## Options

Setup with options:

```lua
require("mssql").setup({
  max_rows = 50,
  max_column_width = 50,
  lsp_settings = {
    intelliSense = { lowerCaseSuggestions = true }
  }
})

-- With callback
require("mssql").setup({
  max_rows = 50,
  max_column_width = 50,
  lsp_settings = {
    intelliSense = { lowerCaseSuggestions = true }
  }
}, function()
  print("mssql.nvim is ready!")
end)
```

| Option                     | Type      | Description                                                                                                                                                       | Default                          |
| -------------------------- | --------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------- |
| `max_rows`                 | `int?`    | Max rows to return for queries. Needed so that large results don't crash neovim.                                                                                  | `100`                            |
| `max_column_width`         | `int?`    | If a result row has a field text length larger than this it will be truncated when displayed                                                                      | `100`                            |
| `lsp_settings`             | `table`   | Settings passed to the mssql language server. [More info](docs/Lsp-Settings.md)                                                                                   | [See here](docs/Lsp-Settings.md) |
| `data_dir`                 | `string?` | Directory to store download tools and internal config options                                                                                                     | `vim.fn.stdpath("data")`         |
| `tools_file`               | `string?` | Path to an existing [SQL tools service](https://github.com/microsoft/sqltoolsservice/releases) binary. If `nil`, then the binary is auto downloaded to `data_dir` | `nil`                            |
| `connections_file`         | `string?` | Path to a json [connections file](#connections-json-file)                                                                                                         | `<data_dir>/connections.json`    |
| `results_buffer_extension` | `string?` | The file extension of buffers that show query results                                                                                                             | `"md"`                           |
| `results_buffer_filetype`  | `string?` | The filetype (used in neovim to determine the language) of buffers that show query results. Set this to `""` to disable markdown rendering.                       | `"markdown"`                     |

### Notes

- `setup()` runs asynchronously as it may take some time to first download and
  extract the sql tools. Pass a callback as the second argument if you need to
  run code after initialization.

## Roadmap

- Save queries as csv/excel
- Backup/restore databases (something I use in SSMS a lot)
- Object explorer

Long term:

- Tree sitter
- Formatter
