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

Getting the [minimsed inputs](./minimised.json) for code completion of an
unopened buffer in vscode, it seems like some extra settings are required. The
settings in vscode are passed with the `workspace/didChangeConfiguration` event,
but we may be able to pass this upon startup.

Update: This may not be needed, see below

## Uri paths

The Language Server Protocol (and therefore mssql langauge server) requires file
paths to be passed as
[file uris](https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/#uri).
Eg:

```
file:///c:/project/readme.md
```

However it
[expects the file name to be unescaped](https://github.com/microsoft/sqltoolsservice/blob/d75ef0c6deb44b340fae08cd7633bbbf1e951973/src/Microsoft.SqlTools.ServiceLayer/LanguageServices/LanguageService.cs#L718).
So just put `file:///` at the start of the path.

## Timeouts

Many things such as completion requests have internal timeouts within the
language. Eg for
[completion requests](https://github.com/microsoft/sqltoolsservice/blob/48f446723cfa04ae3f0e3734cf61488fcf178819/src/Microsoft.SqlTools.ServiceLayer/LanguageServices/Completion/CompletionService.cs#L95)
we eventually get to:

```csharp
QueueItem queueItem = this.BindingQueue.QueueBindingOperation(
    key: scriptParseInfo.ConnectionKey,
    bindingTimeout: LanguageService.BindingTimeout,
    bindOperation: (bindingContext, cancelToken) =>
    {
        return CreateCompletionsFromSqlParser(connInfo, scriptParseInfo, scriptDocumentInfo, bindingContext.MetadataDisplayInfoProvider);
    },
    timeoutOperation: (bindingContext) =>
    {
        // return the default list if the connected bind fails
        return CreateDefaultCompletionItems(scriptParseInfo, scriptDocumentInfo, useLowerCaseSuggestions);
    },
    errorHandler: ex =>
    {
        // return the default list if an unexpected exception occurs
        return CreateDefaultCompletionItems(scriptParseInfo, scriptDocumentInfo, useLowerCaseSuggestions);
    });
```

So if sql server doesn't get back to the langauage server within the timeout,
the default completion items are returned (standard keywords, nothing from sql
server). In this case, the the timeout is:
`internal const int BindingTimeout = 500;`

This probably happens in vscode too. We can handle this in end to end tests by
triggering auto complete more than once, as the query results from sql are
probably cached so will fire quicker the second time.

## Queries, batches and results sets

```
Query
  - Batches
    - Result sets
    - Messages
```

As far as I can tell:

1. A query is the whole text that gets executed. It contains multiple batches
   separated by GO statements. Each batch is sent to Sql server independantly.
2. A batch contains multiple sql statements, possibly separated by semicolons.
   Mulitple messages may also be returned from sql server when executing a
   batch.
3. An sql statement may or may not return a result set.

Eg:

```sql
SELECT * FROM Person;
UPDATE Person SET SomeValue = 1;
SELECT * FROM Car;
GO
SELECT * FROM Address;
```

This is a single query. It would contain the following:

```
- Batch 1:
  - Messages:
    - (10 rows affected)
    - (10 rows affected)
    - (30 rows affected)
  - Result sets:
    - Result set 1: Rows from Person
    - Result set 2: Rows from Car
- Batch 2:
  - Messages:
    - (40 rows affected)
  - Result sets:
    - Result set 1: Rows from Address
```
