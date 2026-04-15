local config = require("go-impl.config")

local M = {}

function M.env()
	if M.env_initiated then
		return
	end
	M.env_initiated = true
	M.pickers = require("telescope.pickers")
	M.finders = require("telescope.finders")
	M.actions = require("telescope.actions")
	M.action_state = require("telescope.actions.state")
	M.entry_display = require("telescope.pickers.entry_display")
	M.conf = require("telescope.config").values
	M.make_entry = require("telescope.make_entry")
	M.utils = require("telescope.utils")
	M.sorters = require("telescope.sorters")
end

function M.is_loaded()
	local is_loaded = pcall(require, "telescope")
	if is_loaded then
		M.env()
	end
	return is_loaded
end

local function make_entry_fn(opts)
	local show_icon = config.options.style.interface_selector.interface_icon
	local icon_text = config.options.icons.interface.text
	local icon_hl = config.options.icons.interface.hl
	local show_pkg_hl = config.options.style.interface_selector.package_highlight
	local pkg_hl = config.options.style.interface_selector.package_highlight_hl

	local displayer = M.entry_display.create({
		separator = " ",
		items = {
			{ width = opts.symbol_width or 25 },
			{ width = opts.pkg_width or 20 },
			{ remaining = true },
		},
	})

	return function(entry)
		local filename = vim.uri_to_fname(entry.location.uri)
		local range = entry.location.range

		local display_name = show_icon and (icon_text .. entry.name) or entry.name

		return M.make_entry.set_default_entry_mt({
			value = entry,
			ordinal = entry.name .. " " .. (entry.containerName or "") .. " " .. filename,
			display = function(e)
				local display_path = M.utils.transform_path(opts, filename)
				return displayer({
					{ display_name, show_icon and icon_hl or "TelescopeResultsFunction" },
					{
						e.container_name and ("(" .. e.container_name .. ")") or "",
						show_pkg_hl and pkg_hl or "TelescopeResultsComment",
					},
					{ display_path, "TelescopeResultsPath" },
				})
			end,
			filename = filename,
			lnum = range.start.line + 1,
			col = range.start.character + 1,
			symbol_name = entry.name,
			container_name = entry.containerName,
		}, opts)
	end
end

local function interface_requester(bufnr)
	return function(prompt)
		local results = vim.lsp.buf_request_sync(bufnr, "workspace/symbol", { query = prompt }, 5000)
		if not results then
			return {}
		end

		local symbols = {}
		for _, client_result in pairs(results) do
			if client_result.result and type(client_result.result) == "table" then
				for _, symbol in ipairs(client_result.result) do
					if vim.lsp.protocol.SymbolKind[symbol.kind] == "Interface" then
						table.insert(symbols, symbol)
					end
				end
			end
		end
		return symbols
	end
end

---@param co thread
---@param bufnr integer
---@return InterfaceData?
function M.get_interface(co, bufnr)
	M.pickers
		.new({}, {
			prompt_title = "Go Interface Symbols",
			prompt_prefix = config.options.prompt.interface,
			finder = M.finders.new_dynamic({
				entry_maker = make_entry_fn({}),
				fn = interface_requester(bufnr),
			}),
			sorter = M.sorters.highlighter_only({}),
			previewer = M.conf.qflist_previewer({}),
			attach_mappings = function(prompt_bufnr)
				M.actions.select_default:replace(function()
					M.actions.close(prompt_bufnr)
					local selection = M.action_state.get_selected_entry()
					if not selection then
						return coroutine.resume(co, nil)
					end
					coroutine.resume(co, selection)
				end)
				return true
			end,
		})
		:find()

	local selected = coroutine.yield()

	if not selected then
		return nil
	end

	return {
		package = selected.container_name,
		path = selected.filename,
		col = selected.col,
		line = selected.lnum,
	}
end

return M
