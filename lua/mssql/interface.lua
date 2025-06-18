-- Handles how the user user interfaces with this plugin, i.e. keymaps and user commands
local query_manager_module = require("mssql.query_manager")
local utils = require("mssql.utils")

return {
	set_keymaps = function(prefix, M)
		if not prefix then
			return
		end

		local keymaps = {
			new_query = { "n", M.new_query, desc = "New Query", icon = { icon = "", color = "yellow" } },
			connect = { "c", M.connect, desc = "Connect", icon = { icon = "󱘖", color = "green" } },
			disconnect = { "q", M.disconnect, desc = "Disconnect", icon = { icon = "", color = "red" } },
			cancel_query = { "l", M.cancel_query, desc = "Cancel Query", icon = { icon = "", color = "red" } },
			execute_query = {
				"x",
				M.execute_query,
				desc = "Execute Query",
				mode = { "n", "v" },
				icon = { icon = "", color = "green" },
			},
			edit_connections = {
				"e",
				M.edit_connections,
				desc = "Edit Connections",
				icon = { icon = "󰅩", color = "grey" },
			},
			refresh_intellisense = {
				"r",
				M.refresh_intellisense_cache,
				desc = "Refresh Intellisense",
				icon = { icon = "", color = "grey" },
			},
			new_default_query = {
				"d",
				M.new_default_query,
				desc = "New Default Query",
				icon = { icon = "", color = "yellow" },
			},
		}

		local success, wk = pcall(require, "which-key")
		if success then
			local wkeygroup = {
				prefix,
				group = "mssql",
				icon = { icon = "", color = "yellow" },
			}

			local normal_group = vim.tbl_deep_extend("keep", wkeygroup, {})
			normal_group.expand = function()

				local available_keymaps = {
					keymaps.new_query,
					keymaps.new_default_query,
					keymaps.edit_connections,
				}

				local qm = vim.b.query_manager
				if qm then
					local current_state = qm.get_state()
					local states = query_manager_module.states

					table.insert(available_keymaps, keymaps.refresh_intellisense)

					local state_specific_keymaps = {
						[states.Executing] = { keymaps.cancel_query },
						[states.Cancelling] = { keymaps.disconnect },
						[states.Connected] = {
							keymaps.execute_query,
							keymaps.disconnect,
							{
								"s",
								M.switch_database,
								desc = "Switch Database",
								icon = { icon = "", color = "yellow" },
							},
						},
						[states.Disconnected] = {
							keymaps.connect,
							{
								"x",
								M.execute_query,
								desc = "Execute On Default",
								mode = { "n", "v" },
								icon = { icon = "", color = "green" },
							},
						}
					}

					local keymaps_for_state = state_specific_keymaps[current_state]
					if not keymaps_for_state and current_state ~= states.Connecting then
						utils.log_error("Entered unrecognised query state: " .. current_state)
						return {}
					end

					for _, keymap in ipairs(keymaps_for_state or {}) do
						table.insert(available_keymaps, keymap)
					end

				elseif vim.b.query_result_info then
					table.insert(available_keymaps, {
						"s",
						M.save_query_results,
						desc = "Save Query Results",
						icon = { icon = "", color = "green" },
					})
				end
				return available_keymaps
			end

			wk.add(normal_group)

			local visual_group = vim.tbl_deep_extend("keep", wkeygroup, {})
			visual_group.mode = "v"
			visual_group.expand = function()
				local qm = vim.b.query_manager
				if not qm then
					return { keymaps.new_query, keymaps.new_default_query, keymaps.edit_connections }
				end

				local state = qm.get_state()
				local states = query_manager_module.states
				if state == states.Connecting or state == states.Executing or state == states.Disconnected then
					return {}
				elseif state == states.Connected then
					return { keymaps.execute_query }
				else
					utils.log_error("Entered unrecognised query state: " .. state)
					return {}
				end
			end

			wk.add(visual_group)
		else
			for _, m in pairs(keymaps) do
				vim.keymap.set(m.mode or "n", prefix .. m[1], m[2], { desc = m.desc })
			end
			vim.keymap.set("n", prefix .. "s", function()
				if vim.b.query_result_info then
					M.save_query_results()
				else
					M.switch_database()
				end
			end)
		end
	end,

	set_user_commands = function(M)
		local commands = {
			Connect = M.connect,
			Disconnect = M.disconnect,
			BackupDatabase = M.backup_database,
			RestoreDatabase = M.restore_database,
			ExecuteQuery = M.execute_query,
			RefreshIntellisense = M.refresh_intellisense_cache,
			EditConnections = M.edit_connections,
			SwitchDatabase = M.switch_database,
			NewQuery = M.new_query,
			NewDefaultQuery = M.new_default_query,
			SaveQueryResults = M.save_query_results,
			CancelQuery = M.cancel_query,
		}

		local complete = function(_, _, _)
			local available_commands = {
				"NewQuery",
				"NewDefaultQuery",
				"EditConnections",
			}

			local qm = vim.b.query_manager
			if qm then
				local current_state = qm.get_state()
				local states = query_manager_module.states

				table.insert(available_commands, "RefreshIntellisense")

				local state_specific_commands = {
					[states.Executing] = { "CancelQuery" },
                    [states.Cancelling] = { "Disconnect" },
					[states.Connected] = {
						"ExecuteQuery",
						"Disconnect",
						"SwitchDatabase",
						"BackupDatabase",
						"RestoreDatabase"
					},
					[states.Disconnected] = { "Connect" },
				}

				local commands_for_state = state_specific_commands[current_state]

				if not commands_for_state and current_state ~= states.Connecting then
					utils.log_error("Entered unrecognised query state: " .. current_state)
					return {}
				end

				for _, cmd in ipairs(commands_for_state or {}) do
					table.insert(available_commands, cmd)
				end

			elseif vim.b.query_result_info then
				table.insert(available_commands, "SaveQueryResults")
			end
			return available_commands
		end

		vim.api.nvim_create_user_command("MSSQL", function(args)
			local command = commands[args.args]
			if not command then
				error("No such command " .. args.args, 0)
			end
			command()
		end, { nargs = 1, complete = complete })
	end,
}
