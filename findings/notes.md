# Lsp notes

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

Getting the [minimsed inputs](./minimised.json) for code completion of an unopened buffer in vscode, it seems like some extra settings are required. The settings in vscode are passed with the `workspace/didChangeConfiguration` event, but we may be able to pass this upon startup.

Need to check:

- What messages neovim sends to the lsp (if didopen is given for an empty buffer)
