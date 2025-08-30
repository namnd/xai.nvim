# xai.nvim

A Neovim plugin for integrating xAI-powered chat and code analysis directly into your Neovim.
This plugin provides AI-assisted features like chat conversations, codebase analysis, and history management. It uses an external `xai` command-line tool for AI interactions.

# Demo

[Watch video](https://x.com/namnd_/status/1961035300295123215)

## Installation

Using native package management in neovim v0.12
```lua
vim.pack.add({
	"https://github.com/namnd/xai.nvim",
})
```
## Usage

- `:XaiChat` - Open a new chat window.
- `:XaiAnalyze [files]` - Analyze files or the current directory (e.g., `:XaiChatAnalyze lua/xai.lua`).
- `:XaiHistory` - View and resume chat history.
- In chat mode, press `<Shift-CR>` to submit messages.

## Dependencies

- [fzf](https://github.com/junegunn/fzf)
- External [xai](https://github.com/namnd/xai-cli) CLI tool

## Configuration

No setup required

## License

MIT

## Credits

- [The simplest ChatGPT interface for Neovim](https://www.youtube.com/watch?v=t5ZbKof83_Q&t=445s) by Greg Hurrell
- [shellbot](https://github.com/wolffiex/shellbot)
- [json.lua](https://github.com/rxi/json.lua)


