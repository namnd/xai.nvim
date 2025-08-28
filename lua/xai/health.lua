local health = vim.health -- after: https://github.com/neovim/neovim/pull/18720
	or require("health") -- before: v0.8.x

return {
	-- Run with `:checkhealth xai`
	check = function()
		if vim.fn.executable("xai") == 1 then
			health.ok("xai cli has been installed and in $PATH")
			if
				vim.fn.filereadable(os.getenv("HOME") .. "/.xai/config") == 1
				and vim.fn.filereadable(os.getenv("HOME") .. "/.xai/chat.db") == 1
			then
				health.ok("xai config found")
			else
				health.warn("please run `xai setup` first")
			end
		else
			health.warn("xai cli is not found")
		end
	end,
}
