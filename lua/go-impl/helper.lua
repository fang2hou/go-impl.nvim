local ts_utils = require("nvim-treesitter.ts_utils")
local parsers = require("nvim-treesitter.parsers")
local job = require("plenary.job")

local config = require("go-impl.config")

local M = {}

local ts_query_struct = vim.treesitter.query.parse(
	"go",
	[[
        (type_declaration
            (type_spec
                name: (type_identifier) @struct_name
                type: (struct_type)
            )
        ) @struct_declaration
    ]]
)

local ts_query_interface = vim.treesitter.query.parse(
	"go",
	[[
        (type_spec
            name: (type_identifier) @base_name
            type_parameters: (type_parameter_list
                (type_parameter_declaration
                    name: (identifier) @generic_name
                    type: (type_constraint) @generic_type
                )
            )? @parameter_list
            type: (interface_type)
        )
    ]]
)

---Get the gopls client for the current buffer
---@param bufnr integer The buffer number
---@return vim.lsp.Client? client The gopls client
function M.get_gopls(bufnr)
	local clients = vim.lsp.get_clients({ bufnr = bufnr, name = "gopls" })
	return clients and clients[1]
end

---Try to get the current struct name under the cursor
---@return string? struct_name The struct name
function M.get_struct_at_cursor()
	local node = ts_utils.get_node_at_cursor()

	while node and node:type() ~= "type_spec" do
		node = node:parent()
	end
	if not node then
		return
	end

	-- Tree-sitter node structure:
	-- (type_declaration
	--   (type_spec
	--   name: (type_identifier)
	--   type: (struct_type
	--       (field_declaration_list
	--       (field_declaration
	--       ...
	---@type table<string, TSNode>
	local nodes = {}
	for child, field in node:iter_children() do
		nodes[field] = child
	end

	if not nodes["type"] or not nodes["name"] then
		return
	end
	if nodes["type"]:type() ~= "struct_type" then
		return
	end

	local node_text = vim.treesitter.get_node_text(nodes["name"], 0)
	if not node_text then
		return
	end
	return node_text
end

---Check the validity of the go receiver string, and return the last line number of the struct
---@param receiver string? The receiver string
---@return integer? lnum The line number of the struct
function M.get_lnum(receiver)
	if not receiver or #receiver == 0 then
		return
	end

	local struct_name = string.match(receiver, "^%a+%s%*?(.*)$")
	if not struct_name then
		return
	end

	local root_lang_tree = parsers.get_parser(0)
	if not root_lang_tree then
		return
	end

	root_lang_tree:parse()
	local trees = root_lang_tree:trees()
	local root = trees and trees[1] and trees[1]:root()
	if not root then
		return
	end

	---@type TSNode?
	local current_struct_node = nil
	for id, capture_node in ts_query_struct:iter_captures(root, 0) do
		local capture = ts_query_struct.captures[id]
		local text = vim.treesitter.get_node_text(capture_node, 0)

		if capture == "struct_declaration" then
			current_struct_node = capture_node
		elseif capture == "struct_name" then
			if struct_name == text and current_struct_node then
				local start_row, _, end_row = current_struct_node:range(false)
				local lnum = vim.fn.line("$")
				if config.options.insert.position == "after" and end_row then
					lnum = end_row + 1
				elseif config.options.insert.position == "before" and start_row then
					lnum = start_row - 1
				end
				return lnum
			end
		end
	end
end

---@class GenericParameter
---@field name string
---@field type string

---Fetch the generics options for the interface with given path, line and column
---@param path string The path of the file
---@param line integer The line number of the interface symbol
---@param col integer The column number of the interface symbol
---@return string? interface_declaration The full interface declaration
---@return string? base_interface_name The name of the interface, e.g. "MyInterface"
---@return string? parameter_list The list of generic types, e.g. "[T any]"
---@return GenericParameter[]? generic_parameters The list of generic types
function M.parse_interface(path, line, col)
	-- Convert to 0-based index for treesitter
	line, col = line - 1, col - 1

	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_set_option_value("filetype", "go", { buf = buf })

	local lines = vim.fn.readfile(path)
	if not lines or #lines == 0 then
		return
	end

	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

	local root_lang_tree = parsers.get_parser(buf)
	if not root_lang_tree then
		return
	end
	root_lang_tree:parse()

	local root = ts_utils.get_root_for_position(line, col, root_lang_tree)
	if not root then
		return
	end

	local node = root:named_descendant_for_range(line, col, line, col)

	while node and node:type() ~= "type_declaration" do
		node = node:parent()
	end

	if not node then
		return
	end

	local interface_declaration = vim.treesitter.get_node_text(node, buf)
	local base_interface_name = nil
	local parameter_list = nil
	local generic_parameters = {}

	for id, capture_node in ts_query_interface:iter_captures(node, buf) do
		local capture = ts_query_interface.captures[id]
		local text = vim.treesitter.get_node_text(capture_node, buf)

		if capture == "base_name" then
			base_interface_name = text
		elseif capture == "generic_name" then
			table.insert(generic_parameters, { name = text, type = nil })
		elseif capture == "generic_type" then
			-- For some cases like [T, K any], there is no `generic_type` parsed for `T`
			-- So we need to find reverse and assign the type to the first `generic_name` without type
			for i = #generic_parameters, 1, -1 do
				if not generic_parameters[i].type then
					generic_parameters[i].type = text
					break
				end
			end
		elseif capture == "parameter_list" then
			parameter_list = text
		end
	end

	vim.api.nvim_buf_delete(buf, { force = true })

	if not base_interface_name then
		return
	end

	return interface_declaration, base_interface_name, parameter_list, generic_parameters
end

---Run `impl`(https://github.com/josharian/impl) to add implementation for the given interface
---@param receiver string The receiver string
---@param package string The package name
---@param interface_name string The interface name
---@param lnum integer The line number to add the implementation
function M.impl(receiver, package, interface_name, lnum)
	local lines = {}
	local job_config = {
		command = "impl",
		args = {
			"-dir",
			vim.fn.fnameescape(vim.fn.expand("%:p:h")),
			receiver,
			package .. "." .. interface_name,
		},
		on_stdout = function(_, data)
			table.insert(lines, data)
		end,
		on_exit = function(_, code)
			if code ~= 0 then
				vim.notify("Failed to add the implementation", vim.log.levels.ERROR, { title = "go-impl" })
				return
			end

			vim.schedule(function()
				-- before newline
				while #lines > 0 and lines[1] == "" do
					table.remove(lines, 1)
				end

				if config.options.insert.before_newline then
					table.insert(lines, 1, "")
				end

				-- after newline
				while #lines > 0 and lines[#lines] == "" do
					table.remove(lines, #lines)
				end

				if config.options.insert.after_newline then
					table.insert(lines, "")
				end

				vim.fn.append(lnum, lines)
			end)
		end,
	}

	job:new(job_config):start()
end

return M
