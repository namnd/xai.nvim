local xai = require("xai")

vim.api.nvim_create_user_command("X", xai.Chat, {})
vim.api.nvim_create_user_command("XH", xai.ChatHistory, {})
vim.api.nvim_create_user_command("XA", xai.ChatAnalyze, { nargs = "*" })
