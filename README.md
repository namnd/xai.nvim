# xai.nvim

A Neovim plugin for integrating xAI-powered chat and code analysis directly into your Neovim.
This plugin provides AI-assisted features like chat conversations, codebase analysis, and history management. It uses an external `xai` command-line tool for AI interactions.

## Installation

Using native package management in neovim v0.12
```lua
vim.pack.add({
	"https://github.com/namnd/xai.nvim",
})
```
## Usage

- `:XaiChat` - Open a new chat window.
- `:XaiChatAnalyze [files]` - Analyze files or the current directory (e.g., `:XaiChatAnalyze lua/xai.lua`).
- `:XaiChatHistory` - View and resume chat history.
- In chat mode, press `<Shift-CR>` to submit messages.

## Dependencies

- fzf
- External `xai` CLI tool (ensure it's in your PATH).

## Configuration

No setup required

## License

MIT
