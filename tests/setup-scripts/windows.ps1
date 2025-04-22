echo "Install Neovim (Windows) and add to PATH"
winget install Neovim.Neovim --silent --accept-package-agreements --accept-source-agreements
echo "$Env:ProgramFiles\Neovim\bin" | Out-File -Append -FilePath $env:GITHUB_PATH -Encoding utf8
