local busted = require("plenary.busted")

busted.describe("Hello function", function()
	local mssql = require("mssql")

	it("greets with given name", function()
		assert.equals("Hello Brian", mssql.Hello("Brian"))
	end)
end)
