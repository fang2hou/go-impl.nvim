<!-- markdownlint-disable no-inline-html -->
<!-- markdownlint-disable first-line-heading -->

<div align="center">

# go-impl.nvim

🚀 A faster way to implement Go interfaces in Neovim.

[sample-video]

</div>

## 🌟 Key Features

- **Fully Asynchronous**:
  Non-blocking operations for a seamless experience.
- **Smart Receiver Detection**:
  Automatically identifies the correct receiver based on cursor position.
- **Treesitter Validation**:
  Ensures the receiver is valid before executing `impl`.
- **Fast Interface Selection**:
  Uses [snacks][snacks-url] picker or [ibhagwan/fzf-lua][fzf-lua-url] for quick
  and efficient interface selection.
- **Generic Parameters Support**:
  Allows specifying types for generic parameters with highlighting and interface
  declaration.

## 📋 Requirements

- Neovim >= 0.11.0
- Latest version of [josharian/impl][impl]
  - Install with `go install github.com/josharian/impl@latest`
- Fuzzy Finder (choose one of the following)
  - [folke/snacks.nvim][snacks-url] (recommended, bundled with [LazyVim][LazyVim])
  - [ibhagwan/fzf-lua][fzf-lua-url]

## 🚚 Installation

<details>
<summary>Install with <a href="https://github.com/folke/lazy.nvim">lazy.nvim</a></summary>

```lua
{
  "fang2hou/go-impl.nvim",
  ft = "go",
  dependencies = {
    "MunifTanjim/nui.nvim",
    "nvim-lua/plenary.nvim",

    -- Choose one of the following fuzzy finder
    "folke/snacks.nvim",
    "ibhagwan/fzf-lua",
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

1. Open a Go file.
2. Place your cursor on the structure you want to implement.
3. Run `:lua require("go-impl").open()` or `:GoImplOpen` to start implementing.

## ⚙️ Configuration

The default configuration should work for most users.

Check out all available options in [config.lua](lua/go-impl/config.lua).

## 🔄 Alternatives and Related Projects

- [edolphin-ydf/goimpl.nvim][goimpl.nvim] -
  Partial support for generic interfaces and telescope search.
  - This project is inspired by goimpl.nvim.
- [olexsmir/gopher.nvim][gopher.nvim] -
  Supports non-generic interfaces but requires manual input for arguments.
- [fatih/vim-go][vim-go] -
  A comprehensive Go development plugin for Vim.
- [rhysd/vim-go-impl][vim-go-impl] -
  Wraps the `impl` command in Vim, and also needs manual input for arguments.

## 🪪 License

MIT

<!-- LINKS -->

[impl]: https://github.com/josharian/impl
[sample-video]: https://github.com/user-attachments/assets/0f03a4f0-536c-42c1-a436-ada1775439ed
[LazyVim]: https://www.lazyvim.org/
[snacks-url]: https://github.com/folke/snacks.nvim
[fzf-lua-url]: https://github.com/ibhagwan/fzf-lua
[goimpl.nvim]: https://github.com/edolphin-ydf/goimpl.nvim
[gopher.nvim]: https://github.com/olexsmir/gopher.nvim
[vim-go]: https://github.com/fatih/vim-go
[vim-go-impl]: https://github.com/rhysd/vim-go-impl
