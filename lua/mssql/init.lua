local M = {}

function M.pick()
	vim.ui.select({ "Apples", "Bananas", "Cherries" }, {
		prompt = "Pick a fruit:",
	}, function(choice)
		if choice then
			print("You picked " .. choice)
		end
	end)
end

return M
