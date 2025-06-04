local picker = require("snacks").picker

picker.pick({
	title = "test",
	layout = "select",
	finder = function(config, ctx)
		return function(emit)
			vim.defer_fn(function()
				emit({ icon = "", text = "table" })
				ctx.async:resume()
			end, 2000)
			emit({ icon = "󰡱", text = "stored procedure" })
			emit({ icon = "󱂬", text = "view" })
			ctx.async:suspend()
		end
	end,
	format = function(item)
		return {
			{ item.icon, "SnacksPickerIcon" },
			{ " " },
			{ "path here", "SnacksPickerComment" },
			{ " " },
			{ item.text },
		}
	end,
	confirm = function(picker, item)
		picker:close()
		vim.notify(vim.inspect(item))
	end,
})
