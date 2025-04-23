$env:DbServer = "localhost"
$env:DbUser = "sa"
$env:DbPassword = "Test_Password_123"
$env:DbDatabase = "tempdb"
nvim -u .\runtests.lua --headless
