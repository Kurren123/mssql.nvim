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

## Unsaved buffer lsp messages

The following messages are sent after initialization when a buffer requests completion items:

```json
{"method":"textDocument/didOpen","params":{"textDocument":{"uri":"file://","version":0,"languageId":"sql","text":"\r\n"}},"jsonrpc":"2.0"}

{"method":"textDocument/completion","params":{"context":{"triggerKind":1},"textDocument":{"uri":"file://"},"position":{"line":0,"character":0}},"id":2,"jsonrpc":"2.0"}
```

This is then returned:

```json
{
  "jsonrpc": "2.0",
  "id": "2",
  "error": {
    "code": 0,
    "message": "The path is empty. (Parameter 'path')",
    "data": null
  }
}
```

## Todo:

- Report lsp errors back to the user. Is the error property a standard lsp thing? Is there a standard way to do this in nvim?
- Vscode sends an "untitled-1" file name to the lsp for unopened files. Send something similar and see if the completions are correct. What happens in vscode when the file is then saved? Is the same message sent from neovim when the new buffer is saved?
