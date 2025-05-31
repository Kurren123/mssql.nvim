# LSP Settings

These are the default settings used by the LSP, taken from the language server
[source code](https://github.com/microsoft/sqltoolsservice/blob/v3.0.0-release.254/src/Microsoft.SqlTools.ServiceLayer/SqlContext/SqlToolsSettingsValues.cs).

> [!WARNING]  
> Not all features have yet been implmented in in this plugin. All documented
> options that the LSP will accept are below, however many of them will have no
> effect when using this plugin. Particularly the object explorer settings.

```lua
return {
 --- Detailed IntelliSense settings
 intelliSense = {
  --- A flag determining if IntelliSense is enabled
  enableIntellisense = true,

  --- A flag determining if suggestions are enabled
  enableSuggestions = true,

  --- A flag determining if built-in suggestions should be lowercase
  lowerCaseSuggestions = false,

  --- A flag determining if diagnostics are enabled
  enableErrorChecking = true,

  --- A flag determining if quick info is enabled
  enableQuickInfo = true,
 },
 query = {
  --- The configured batch separator
  batchSeparator = "GO",

  --- Maximum number of characters to store in temp file for long character fields and binary fields
  maxCharsToStore = 65535,

  --- Maximum number of characters to store in temp file for XML columns
  maxXmlCharsToStore = 2097152,

  --- NOTE: This plugin does not show execution plans yet so
  --- these options will have no effect!
  --- Options for returning execution plans when executing queries
  executionPlanOptions = {
   --- Setting to return the actual execution plan as XML
   includeActualExecutionPlanXml = false,

   --- Setting to return the estimated execution plan as XML
   includeEstimatedExecutionPlanXml = false,
  },

  --- Determines if bit columns will be rendered as "1"/"0" or "true"/"false"
  displayBitAsNumber = true,

  rowCount = 0,
  textSize = 2147483647,
  executionTimeout = 0,
  noCount = false,
  noExec = false,
  parseOnly = false,
  arithAbort = true,

  --- Whether NULL concatenation yields NULL
  concatNullYieldsNull = true,

  statisticsTime = false,
  statisticsIO = false,
  xactAbortOn = false,

  --- Transaction isolation level for query execution
  --- Possible values: "READ UNCOMMITTED", "READ COMMITTED", "REPEATABLE READ", "SNAPSHOT", "SERIALIZABLE"
  transactionIsolationLevel = "READ UNCOMMITTED",

  --- Deadlock priority level
  --- Possible values: "LOW", "NORMAL", "HIGH"
  deadlockPriority = "Normal",

  lockTimeout = -1,
  queryGovernorCostLimit = 0,

  ansiDefaults = false,
  quotedIdentifier = true,
  ansiNullDefaultOn = true,
  implicitTransactions = false,
  cursorCloseOnCommit = false,
  ansiPadding = true,
  ansiWarnings = true,
  ansiNulls = true,

  --- Setting to return the actual execution plan as XML
  includeActualExecutionPlanXml = false,

  --- Setting to return the estimated execution plan as XML
  includeEstimatedExecutionPlanXml = false,

  isSqlCmdMode = false,

  --- Whether Always Encrypted Parameterization is enabled
  isAlwaysEncryptedParameterizationEnabled = false,
 },

 format = {
  --- Should names be escaped, for example converting dbo.T1 to [dbo].[T1]
  useBracketForIdentifiers = false,

  --- Should comma separated lists have the comma be at the start of a new line.
  --- Example:
  --- CREATE TABLE T1 (
  ---     C1 INT
  ---     , C2 INT)
  placeCommasBeforeNextStatement = false,

  --- Should each reference be on its own line or should references to multiple objects
  --- be kept on a single line.
  --- Example:
  --- SELECT *
  --- FROM T1,
  ---      T2
  placeSelectStatementReferencesOnNewLine = false,

  --- Should keyword casing be ignored, converted to all uppercase, or converted to all lowercase
  --- Possible values: "None", "Uppercase", "Lowercase"
  keywordCasing = "None",

  --- Should data type casing be ignored, converted to all uppercase, or converted to all lowercase
  --- Possible values: "None", "Uppercase", "Lowercase"
  datatypeCasing = "None",

  --- Should column definitions be aligned or left non-aligned?
  alignColumnDefinitionsInColumns = false,
 },

 --- NOTE: This plugin has no object explorer yet so the
 --- following options will have no effect!
 objectExplorer = {
  --- Number of seconds to wait before fail create session request with timeout error
  createSessionTimeout = 45,

  --- Number of seconds to wait before fail expand request with timeout error
  expandTimeout = 45,

  --- Moves Schema to the top level of OE and then move schema-bound nodes under it
  groupBySchema = false,
 },

 --- NOTE: This plugin has no table designer yet so the
 --- following options will have no effect!
 tableDesigner = {
  --- Whether the database model should be preloaded to make the initial launch quicker
  preloadDatabaseModel = false,

  --- Whether the table designer should allow disabling and re-enabling DDL triggers during publish
  allowDisableAndReenableDdlTriggers = true,
 },

 piiLogging = false,
}
```
