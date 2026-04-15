local nui_input = require("nui.input")
local nui_popup = require("nui.popup")
local nui_text = require("nui.text")
local nui_line = require("nui.line")
local nui_layout = require("nui.layout")
local nui_event = require("nui.utils.autocmd").event

local config = require("go-impl.config")

local M = {}

---@class FuzzyFinder
---@field is_loaded fun(): boolean
---@field get_interface fun(co: thread, bufnr: integer, gopls: vim.lsp.Client): InterfaceData

---@type table<string, FuzzyFinder>
local fuzzy_finders = {
	fzf_lua = require("go-impl.fzf_lua"),
	snacks = require("go-impl.snacks"),
}

---Get the receiver input
---@param default_value string? defualt value
---@param callback fun(receiver: string?)
function M.get_receiver(default_value, callback)
	local nui_opts = vim.tbl_deep_extend("force", config.options.style.receiver_input, {
		border = {
			text = {
				top = nui_line({
					nui_text(" [ "),
					nui_text(config.options.icons.go.text, config.options.icons.go.hl),
					nui_text("Receiver", "Fg"),
					nui_text(" ] "),
				}),
			},
		},
	})

	local input = nui_input(nui_opts, {
		prompt = nui_text(config.options.prompt.receiver, "GoImplHighlight"),
		default_value = default_value,
		on_close = callback,
		on_submit = callback,
		on_change = function() end,
	})

	input:mount()
	for _, event in ipairs({
		nui_event.BufWinLeave,
		nui_event.BufLeave,
		nui_event.InsertLeavePre,
	}) do
		input:on(event, function()
			input:unmount()
		end)
	end
end

---@class GenericOpts
---@field name string
---@field type string
---@field interface_base_name string
---@field generic_parameter_list string
---@field interface_declaration string

---Get the receiver input
---@param opts GenericOpts
---@param callback fun(argument?: string)
function M.get_generic_argument(opts, callback)
	local bottom_text = nil

	-- Generate type highlighted help text
	local params = vim.split(opts.generic_parameter_list, ",")
	local checked_params = {}
	for i = 1, #params do
		local param = params[i]
		local items = vim.split(vim.trim(param), " ")
		if string.find(items[1], opts.name) then
			local remain = table.concat(params, ",", i)
			local n_start, n_end = string.find(remain, opts.name)
			local t_start, t_end = string.find(remain, opts.type)

			if i > 1 then
				table.insert(checked_params, "") -- add last comma in concatenation
			end
			local normal_left = nui_text(table.concat(checked_params, ",") .. string.sub(remain, 1, n_start - 1))
			local hl_name = nui_text(opts.name, "GoImplHighlight")
			local normal_middle = nui_text(string.sub(remain, n_end + 1, t_start - 1))
			local hl_type = nui_text(opts.type, "GoImplHighlight")
			local normal_right = nui_text(string.sub(remain, t_end + 1))

			bottom_text = nui_line({ normal_left, hl_name, normal_middle, hl_type, normal_right })
			break
		end

		table.insert(checked_params, param)
	end

	local nui_opts = vim.tbl_deep_extend("force", config.options.style.generic_argument_input, {
		border = {
			text = {
				top = nui_line({
					nui_text(" [ "),
					nui_text(config.options.icons.interface.text, config.options.icons.interface.hl),
					nui_text(opts.interface_base_name, "Fg"),
					nui_text(" ] "),
				}),
				bottom = bottom_text,
			},
		},
	})

	local prompt_text = string.gsub(config.options.prompt.generic, "%{name%}", opts.name)

	local input = nui_input(nui_opts, {
		prompt = nui_text(prompt_text, "GoImplHighlight"),
		default_value = "",
		on_close = callback,
		on_submit = callback,
		on_change = function() end,
	})

	local previewer = nui_popup(vim.tbl_deep_extend("force", config.options.style.generic_argument_previewer, {
		enter = false,
		focusable = false,
		buf_options = {
			modifiable = false,
			readonly = true,
			filetype = "go",
		},
	}))

	local preview_lines = vim.split(opts.interface_declaration, "\n")
	vim.api.nvim_buf_set_lines(previewer.bufnr, 0, -1, false, preview_lines)

	local layout = nui_layout(
		config.options.style.generic_argument_layout,
		nui_layout.Box({
			nui_layout.Box(input, { size = 3 }),
			nui_layout.Box(previewer, { grow = 1 }),
		}, { dir = "col" })
	)
	layout:mount()

	local inited = false

	-- Weirdly, the popup is not in insert mode by default, so we need to force it
	vim.defer_fn(function()
		vim.api.nvim_command("startinsert!")
		inited = true
	end, 40)

	input:on({
		nui_event.BufWinLeave,
		nui_event.BufLeave,
		nui_event.InsertLeavePre,
	}, function(ctx)
		if ctx and ctx.event == nui_event.InsertLeavePre and not inited then
			return
		end
		layout:unmount()
	end)
end

---Try to get the interface from the given fuzzy finder
---@param finder "snacks" | "fzf_lua" The fuzzy finder to use
---@param co thread The coroutine to resume
---@param bufnr integer The current buffer number
---@param gopls vim.lsp.Client The gopls client
function M.try_get_interface(finder, co, bufnr, gopls)
	if not finder or not fuzzy_finders[finder] then
		vim.notify(
			string.format("Invalid picker '%s', available: snacks, fzf_lua (nil for auto-detect)", finder),
			vim.log.levels.WARN,
			{ title = "go-impl" }
		)
		return nil
	end

	if not fuzzy_finders[finder].is_loaded() then
		return nil
	end

	return fuzzy_finders[finder].get_interface(co, bufnr, gopls)
end

return M
