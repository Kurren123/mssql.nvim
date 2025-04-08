local mssql = require("mssql")

assert(mssql.Hello("Brian") == "Hello Brian", "mssql.Hello() did not return expected output")
