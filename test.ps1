$nvim = "nvim"
$rocksShare = ".rocks/share/lua/5.1"
$luaPath = "$rocksShare/?.lua;$rocksShare/?/init.lua"

& $nvim --headless `
  -u NONE `
  -c "set rtp^=." `
  -c "lua package.path = package.path .. ';$luaPath'" `
  -c "lua local busted = require('plenary.busted'); local files = vim.split(vim.fn.glob('tests/**/*_spec.lua'), '\n'); files = vim.tbl_filter(function(x) return x ~= '' end, files); busted.run(files, { sequential = true })" `
  -c "qa"
