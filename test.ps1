$env:DbServer = "localhost"
$env:DbUser = "sa"
$env:DbPassword = "Test_Password_123"
$env:DbDatabase = "master"
nvim -u .\runtests.lua --headless
