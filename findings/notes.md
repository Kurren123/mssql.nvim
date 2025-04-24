# Lsp notes

## CLI args

When vscode opens the language server, it does:

```bash
MicrosoftSqlToolsServiceLayer.exe
--log-file c:\...\ms-mssql.mssql\sqltools.log
--tracing-level Critical
--application-name Code
--data-path ...\AppData\Roaming
--enable-sql-authentication-provider
--enable-connection-pooling
```

Removing these arguments seem to have no effect on the code completions.

## Vscode settings

Getting the [minimsed inputs](./minimised.json) for code completion of an unopened buffer in vscode, it seems like some extra settings are required. The settings in vscode are passed with the `workspace/didChangeConfiguration` event, but we may be able to pass this upon startup.

Update: This may not be needed, see below

## Uri paths

The Language Server Protocol (and therefore mssql langauge server) requires file paths to be passed as [file uris](https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/#uri). Eg:

```
file:///c:/project/readme.md
```

The function `vim.uri_from_fname("c:/project/readme.md")` will convert from a filepath to uri syntax. Use URIs when passing paths to the language server, such as the `connect` method.
