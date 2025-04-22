Write-Host "Install Neovim (Windows) and add to PATH"
winget install Neovim.Neovim --silent --accept-package-agreements --accept-source-agreements
Write-Host "$Env:ProgramFiles\Neovim\bin" | Out-File -Append -FilePath $env:GITHUB_PATH -Encoding utf8

$DbServer = "localhost"
$Port = 1433
$DbName = "TestDb"
$DbUser = "sa"
$DbPassword = "Integration_test_123"

Write-Host "Starting SQL Server container"
docker run -e "ACCEPT_EULA=Y" -e "SA_PASSWORD=$DbPassword" -p "${Port}:1433" -d --name sqlserver mcr.microsoft.com/mssql/server:2022-latest

Write-Host "Installing sqlcmd"
Invoke-WebRequest -Uri https://aka.ms/sqlcmd-win-install -OutFile installSqlCmd.ps1
.\installSqlCmd.ps1

Write-Host "Waiting for SQL Server to be ready"
for ($i=0; $i -lt 30; $i++) {
    sqlcmd -S "${DbServer},${Port}" -U $DbUser -P $DbPassword -Q "SELECT 1" > $null 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "SQL Server is ready."
        break
    } else {
        Start-Sleep -Seconds 2
    }
}

Write-Host "Seeding database"
@"
CREATE DATABASE $DbName;
GO
USE $DbName;
CREATE TABLE Test (Id INT PRIMARY KEY, Name NVARCHAR(50));
INSERT INTO Test VALUES (1, 'Windows');
"@ | Out-File seed.sql

sqlcmd -S "${DbServer},${Port}" -U $DbUser -P $DbPassword -i seed.sql

Write-Host "Exporting database settings to GITHUB_ENV"
"DB_SERVER=$DbServer" | Out-File -FilePath $env:GITHUB_ENV -Append
"DB_NAME=$DbName"     | Out-File -FilePath $env:GITHUB_ENV -Append
"DB_USER=$DbUser"     | Out-File -FilePath $env:GITHUB_ENV -Append
"DB_PASSWORD=$DbPassword" | Out-File -FilePath $env:GITHUB_ENV -Append
"DB_PORT=$Port" | Out-File -FilePath $env:GITHUB_ENV -Append

Write-Host "Done"
