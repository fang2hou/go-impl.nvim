<!-- markdownlint-disable no-inline-html -->
<!-- markdownlint-disable first-line-heading -->

<div align="center">

# go-impl.nvim

A fast and minimal Go interface implementation plugin powered by Neovim's built-in LSP client and Treesitter.

[sample-video]

</div>

## ✨ Features

- **Built on Neovim primitives**  
  Leverages the native LSP client (`vim.lsp`), Treesitter, and `vim.system()` for async subprocess management.
  No heavy dependencies.
- **Fully Asynchronous**  
  Non-blocking LSP requests, interface selection, and `impl` execution for a seamless experience.
- **Smart Receiver Detection**  
  Uses Treesitter to locate the struct under the cursor and predict a sensible receiver abbreviation.
- **Multi-Picker Support**  
  Works with [snacks.nvim][snacks-url] (recommended, bundled with [LazyVim][LazyVim]),
  [fzf-lua][fzf-lua-url], or [telescope.nvim][telescope-url]. Auto-detected based on availability.
- **Generic Parameters Support**  
  Interactive input for each type parameter with highlighting and live preview
  of the interface declaration.

## 📦 Requirements

- Neovim >= 0.12.0
- [josharian/impl][impl] (`go install github.com/josharian/impl@latest`)
- [MunifTanjim/nui.nvim][nui-url]
- A fuzzy finder (choose one):
  - [folke/snacks.nvim][snacks-url] (recommended, bundled with [LazyVim][LazyVim])
  - [ibhagwan/fzf-lua][fzf-lua-url]
  - [nvim-telescope/telescope.nvim][telescope-url]

## 💿 Installation

<details>
<summary>Install with <a href="https://github.com/folke/lazy.nvim">lazy.nvim</a></summary>

```lua
{
  "fang2hou/go-impl.nvim",
  ft = "go",
  dependencies = {
    "MunifTanjim/nui.nvim",

    -- Choose one of the following fuzzy finder
    "folke/snacks.nvim",
    "ibhagwan/fzf-lua",
    "nvim-telescope/telescope.nvim",
  },
  opts = {},
  keys = {
    {
      "<leader>Gi",
      function()
        require("go-impl").open()
      end,
      mode = { "n" },
      desc = "Go Impl",
    },
  },
}
```

</details>

## 🚀 Usage

1. Open a Go file and place the cursor on a struct.
2. Run `:GoImplOpen` or `:lua require("go-impl").open()`.
3. Confirm the receiver, pick an interface, fill in any generic type parameters.

## ⚙️ Configuration

The defaults work out of the box. See [config.lua](lua/go-impl/config.lua) for all options.

```lua
require("go-impl").setup({
  -- explicitly pick a picker, or leave nil for auto-detection
  picker = nil, -- "snacks" | "fzf_lua" | "telescope"
  insert = {
    position = "after", -- "after" | "before" | "end"
    before_newline = true,
    after_newline = false,
  },
})
```

## 🔗 Alternatives

- [edolphin-ydf/goimpl.nvim][goimpl.nvim] -- original inspiration. Telescope-based, partial generic support.
- [olexsmir/gopher.nvim][gopher.nvim] -- manual argument input, no generic interface support.
- [fatih/vim-go][vim-go] -- full-featured Go development plugin for Vim.
- [rhysd/vim-go-impl][vim-go-impl] -- thin `impl` wrapper requiring manual input.

## 📄 License

MIT

<!-- LINKS -->

[impl]: https://github.com/josharian/impl
[nui-url]: https://github.com/MunifTanjim/nui.nvim
[sample-video]: https://github.com/user-attachments/assets/0f03a4f0-536c-42c1-a436-ada1775439ed
[LazyVim]: https://www.lazyvim.org/
[snacks-url]: https://github.com/folke/snacks.nvim
[fzf-lua-url]: https://github.com/ibhagwan/fzf-lua
[telescope-url]: https://github.com/nvim-telescope/telescope.nvim
[goimpl.nvim]: https://github.com/edolphin-ydf/goimpl.nvim
[gopher.nvim]: https://github.com/olexsmir/gopher.nvim
[vim-go]: https://github.com/fatih/vim-go
[vim-go-impl]: https://github.com/rhysd/vim-go-impl
