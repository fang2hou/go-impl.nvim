local ui = require("go-impl.ui")
local helper = require("go-impl.helper")
local config = require("go-impl.config")

local M = {}

---Open the go-impl user interface
function M.open()
	local bufnr = vim.api.nvim_get_current_buf()
	local gopls = helper.get_gopls(bufnr)

	if not gopls then
		vim.notify("No gopls client found in the current buffer", vim.log.levels.WARN, { title = "go-impl" })
		return
	end

	coroutine.wrap(function()
		local co = coroutine.running()

		-- Receiver
		local current_struct_name = helper.get_struct_at_cursor()
		local default_value = current_struct_name and config.options.receiver.predict_abbreviation(current_struct_name)
			or ""
		ui.get_receiver(default_value, function(recevier)
			coroutine.resume(co, recevier)
		end)
		local receiver = coroutine.yield()

		-- Get the line number to insert the implentation
		local lnum = helper.get_lnum(receiver)
		if not lnum then
			vim.notify("Invalid receiver provided", vim.log.levels.INFO, { title = "go-impl" })
			return
		end

		-- Interface
		---@class InterfaceData
		---@field package string
		---@field path string
		---@field line integer
		---@field col integer

		---@type InterfaceData?
		local interface_data = nil

		if config.options.picker then
			interface_data = ui.try_get_interface(config.options.picker, co, bufnr, gopls)
		else
			for _, finder in ipairs({ "snacks", "fzf_lua" }) do
				interface_data = ui.try_get_interface(finder, co, bufnr, gopls)
				if interface_data then
					break
				end
			end
		end

		for _, key in pairs({ "package", "path", "line", "col" }) do
			if not interface_data or not interface_data[key] then
				vim.notify("Failed to get the interface data", vim.log.levels.WARN, { title = "go-impl" })
				return
			end
		end

		-- Generic Arguments
		local interface_declaration, interface_base_name, generic_parameter_list, generic_parameters =
			helper.parse_interface(interface_data.path, interface_data.line, interface_data.col)
		if not interface_declaration or not interface_base_name or not generic_parameters then
			vim.notify("Failed to parse the selected item", vim.log.levels.WARN, { title = "go-impl" })
			return
		end

		local generic_arguments = {}
		if generic_parameter_list then
			for _, generic_parameter in ipairs(generic_parameters) do
				ui.get_generic_argument({
					name = generic_parameter.name,
					type = generic_parameter.type,
					interface_declaration = interface_declaration,
					interface_base_name = interface_base_name,
					generic_parameter_list = generic_parameter_list,
				}, function(arg)
					coroutine.resume(co, arg)
				end)
				local arg = coroutine.yield()
				if not arg then
					vim.notify(
						"Failed to get the generic type: " .. generic_parameter.name,
						vim.log.levels.ERROR,
						{ title = "go-impl" }
					)
					return
				end
				table.insert(generic_arguments, arg)
			end
		end

		-- Run impl
		local interface_name = interface_base_name
		if #generic_arguments > 0 then
			interface_name = string.format("%s[%s]", interface_base_name, table.concat(generic_arguments, ","))
		end
		helper.impl(receiver, interface_data.package, interface_name, lnum)
	end)()
end

return M
