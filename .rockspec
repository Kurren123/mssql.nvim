package = "mssql.nvim"
version = "dev-1"
source = {
   url = "git+https://github.com/Kurren123/mssql.nvim.git"
}
description = {
   homepage = "https://github.com/Kurren123/mssql.nvim",
   license = "*** please specify a license ***"
}
build = {
   type = "builtin",
   modules = {
      ["mssql.init"] = "lua\\mssql\\init.lua"
   },
   copy_directories = {
      "tests"
   }
}
