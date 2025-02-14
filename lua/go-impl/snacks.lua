local config = require("go-impl.config")
local M = {}

function M.env()
	if M.env_initiated then
		return
	end
	M.env_initiated = true
	M.lsp = require("snacks.picker.source.lsp")
end

function M.is_loaded()
	local is_loaded = pcall(require, "snacks")
	if is_loaded then
		M.env()
	end
	return is_loaded
end

---Get the interface from the user using fzf-lua
---@param co thread
---@return InterfaceData
function M.get_interface(co)
	Snacks.picker.lsp_workspace_symbols({
		finder = M.symbols,
		prompt = config.options.prompt.interface,
		title = "go-impl",
		---@diagnostic disable-next-line: missing-fields
		icons = {
			kinds = {
				Interface = config.options.icons.interface.text,
			},
		},
		filter = {
			go = {
				"Interface",
			},
		},
		confirm = function(picker, item)
			picker:close()
			coroutine.resume(co, item)
		end,
		transform = function(item)
			item.containerName = item.item.containerName
		end,
	})

	local selected = coroutine.yield()

	return {
		col = selected.pos[2] + 1,
		line = selected.pos[1],
		path = selected.file,
		package = selected.containerName,
	}
end

return M
