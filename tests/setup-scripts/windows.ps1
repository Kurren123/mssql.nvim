Write-Host "Install Neovim"
winget install Neovim.Neovim --silent --accept-package-agreements --accept-source-agreements
Write-Host "$Env:ProgramFiles\Neovim\bin" | Out-File -Append -FilePath $env:GITHUB_PATH -Encoding utf8
