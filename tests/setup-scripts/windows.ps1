Write-Host "Install Neovim (Windows) and add to PATH"
winget install Neovim.Neovim --silent --accept-package-agreements --accept-source-agreements
Write-Host "$Env:ProgramFiles\Neovim\bin" | Out-File -Append -FilePath $env:GITHUB_PATH -Encoding utf8

$DbServer = "(localdb)\MSSQLLocalDB"
$DbName = "TestDb"
$DbUser = ""
$DbPassword = ""
$Port = ""

Write-Host "Installing sqlcmd"
winget install sqlcmd

sqlcmd -S "${DbServer}" -i "tests/setup-scripts/seed.sql"

Write-Host "Exporting database settings to GITHUB_ENV"
"DB_SERVER=$DbServer" | Out-File -FilePath $env:GITHUB_ENV -Append
"DB_NAME=TestDb"     | Out-File -FilePath $env:GITHUB_ENV -Append
"DB_USER=$DbUser"     | Out-File -FilePath $env:GITHUB_ENV -Append
"DB_PASSWORD=$DbPassword" | Out-File -FilePath $env:GITHUB_ENV -Append
"DB_PORT=$Port" | Out-File -FilePath $env:GITHUB_ENV -Append

Write-Host "Done"
