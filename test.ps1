$rocksShare = ".rocks/share/lua/5.1"
$testDir = "tests"

$luaPath = "$rocksShare/?.lua;$rocksShare/?/init.lua"

& nvim --headless `
  -u NONE `
  -c "set rtp^=." `
  -c "lua package.path = package.path .. ';$luaPath'" `
  -c "lua require('plenary.busted').run('$testDir', { sequential = true })" `
  -c "qa"
