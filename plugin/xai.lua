local xai = require("xai")

vim.api.nvim_create_user_command("XaiChat", xai.Chat, {})
vim.api.nvim_create_user_command("XaiHistory", xai.ChatHistory, {})
vim.api.nvim_create_user_command("XaiAnalyze", xai.ChatAnalyze, { nargs = "*" })
