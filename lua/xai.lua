-- Forked of https://github.com/wolffiex/shellbot/blob/main/chatbot.lua
---@diagnostic disable: duplicate-set-field

local json = require("json")
local util = require("util")

M = {}

-- states[bufnr] = {
--   winnr = nil,
--   thread_id = nil,
--   timer = nil,
--   is_receiving = false,
--   buffer_sync_cursor = true,
-- }
local states = {}

local roles = {
	user = "🧑 " .. os.getenv("USER"),
	assistant = "🤖 xAI",
}

local get_buf_by_thread_id = function(thread_id)
	for k, v in pairs(states) do
		if v.thread_id == thread_id then
			return k
		end
	end
	return nil
end

-- parse buffer to a list of messages
-- each message has first element as role, and the rest are content
local parse_messages = function(bufnr)
	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

	local messages = {}
	local message = {}
	local current_role = "user"
	table.insert(message, roles[current_role])
	for _, line in ipairs(lines) do
		local new_role = ""
		if line:match(roles["user"]) then
			new_role = "user"
		elseif line:match(roles["assistant"]) then
			new_role = "assistant"
		else
			table.insert(message, line)
		end

		if new_role ~= "" and new_role ~= current_role then
			table.insert(messages, util.remove_last_empty(message))
			message = {}
			current_role = new_role
			new_role = ""
			table.insert(message, roles[current_role])
		end
	end

	table.insert(messages, util.remove_last_empty(message)) -- insert last one

	return messages
end

local add_transcript_header = function(bufnr, role, line_num)
	local line = ((line_num ~= nil) and line_num) or vim.api.nvim_buf_line_count(bufnr)
	vim.api.nvim_buf_set_lines(bufnr, line, line + 1, false, { roles[role] })
	if role == "user" and states[bufnr].buffer_sync_cursor then
		vim.schedule(function()
			local is_current = states[bufnr].winnr == vim.api.nvim_get_current_win()
			vim.api.nvim_win_call(states[bufnr].winnr, function()
				vim.cmd("normal! Go")
				if is_current and states[bufnr].thread_id == nil and not states[bufnr].is_receiving then
					vim.cmd("startinsert!")
				end
			end)
		end)
	end

	if role == "assistant" and states[bufnr].is_receiving then
		vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, { "" })
		-- Start the timer
		states[bufnr].timer = vim.loop.new_timer()
		if states[bufnr].timer then
			states[bufnr].timer:start(
				1000,
				1000,
				vim.schedule_wrap(function() -- 1000ms initial delay, then every 1000ms
					local line_count = vim.api.nvim_buf_line_count(bufnr)
					local last_line_idx = line_count - 1
					local last_line_content =
						vim.api.nvim_buf_get_lines(bufnr, last_line_idx, last_line_idx + 1, false)[1]
					local new_last_line_content = last_line_content .. "*"
					vim.api.nvim_buf_set_lines(
						bufnr,
						last_line_idx,
						last_line_idx + 1,
						false,
						{ new_last_line_content }
					)
				end)
			)
		end
	end
	return line
end

local init_chat = function()
	vim.cmd("botright vnew")
	vim.cmd("set winfixwidth")
	vim.cmd("vertical resize 60")

	local bufnr = vim.api.nvim_get_current_buf()
	states[bufnr] = {
		winnr = vim.api.nvim_get_current_win(),
		thread_id = nil,
		timer = nil,
		is_receiving = false,
		buffer_sync_cursor = true,
	}

	vim.wo[states[bufnr].winnr].breakindent = true
	vim.wo[states[bufnr].winnr].wrap = true
	vim.wo[states[bufnr].winnr].linebreak = true

	vim.api.nvim_set_option_value("filetype", "markdown", { buf = bufnr })
	vim.api.nvim_set_option_value("buftype", "nofile", { buf = bufnr })
	vim.api.nvim_set_option_value("buflisted", true, { buf = bufnr })
	vim.api.nvim_set_option_value("modified", false, { buf = bufnr })

	add_transcript_header(bufnr, "user", 0)
	local modes = { "n", "i" }
	for _, mode in ipairs(modes) do
		vim.api.nvim_buf_set_keymap(
			bufnr,
			mode,
			"<S-CR>",
			"<ESC>:lua require('xai').ChatBotSubmit(" .. bufnr .. ")<CR>",
			{ noremap = true, silent = true }
		)
	end

	return bufnr
end

local parse_response = function(response)
	local result = {}

	if response["ChatRequest"] ~= nil and response["ChatRequest"]["messages"] ~= nil then
		for i, m in ipairs(response["ChatRequest"]["messages"]) do
			if m["role"] == "user" or m["role"] == "assistant" then
				table.insert(result, roles[m["role"]])
				-- first one is system prompt
				if i == 2 and m["content"]:match("Analyze codebase files:") then
					table.insert(result, response["OriginalPrompt"])
				else
					local lines = util.split(m["content"], "\n")
					for _, l in ipairs(lines) do
						table.insert(result, l)
					end
				end

				table.insert(result, "")
			end
		end
	end

	if response["ChatResponse"] ~= nil and response["ChatResponse"]["choices"] ~= nil then
		for _, c in ipairs(response["ChatResponse"]["choices"]) do
			local m = c["message"]
			if m["role"] == "user" or m["role"] == "assistant" then
				table.insert(result, roles[m["role"]])
				local lines = util.split(m["content"], "\n")
				for _, l in ipairs(lines) do
					table.insert(result, l)
				end
				table.insert(result, "")
			end
		end
	end

	return result
end

local done = function(bufnr)
	if states[bufnr].timer then
		states[bufnr].timer:stop() -- Stop the timer
		states[bufnr].timer:close() -- Close it to free resources
	end
	vim.api.nvim_set_option_value("modifiable", true, { buf = bufnr }) -- allow user input again
	states[bufnr].is_receiving = false
	add_transcript_header(bufnr, "user")
end

local receive_data = function(bufnr, data)
	if #data > 1 then
		local response = json.decode(data[1])
		states[bufnr].thread_id = response["ThreadID"]
		local bufname = "xai://" .. states[bufnr].thread_id
		states[bufnr].bufname = bufname
		vim.api.nvim_buf_set_name(bufnr, bufname)

		local new_lines = parse_response(response)
		vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, new_lines)
		if states[bufnr].buffer_sync_cursor then
			vim.schedule(function()
				vim.api.nvim_win_call(states[bufnr].winnr, function()
					vim.cmd("normal! G$")
				end)
			end)
		end
	end
end

function M.Chat()
	init_chat()
end

function M.ChatAnalyze(args)
	local prompt = "analyze "
	if args.args == "" then
		prompt = prompt .. vim.fn.getcwd() -- entire codebase
	elseif args.args == "%" then
		prompt = prompt .. vim.fn.expand("%:.") -- current buffer
	else
		prompt = prompt .. args.args
	end

	local analyze_cmd = "xai " .. prompt

	local bufnr = init_chat()

	vim.api.nvim_buf_set_lines(bufnr, 1, -1, false, { util.capitalize_first(prompt), "" })

	local job_id = vim.fn.jobstart(analyze_cmd, {
		on_stdout = function(_, data, _)
			receive_data(bufnr, data)
		end,
		on_exit = function(_, _, _)
			done(bufnr)
		end,
		on_stderr = function(_, _, _)
			-- vim.print(data)
		end,
	})

	if job_id > 0 then
		states[bufnr].is_receiving = true
		add_transcript_header(bufnr, "assistant")
	end
end

function M.ChatHistory()
	local command = "xai chat history"
	local result = util.execute_command(command)
	local fzf_run = vim.fn["fzf#run"]
	local fzf_wrap = vim.fn["fzf#wrap"]
	local wrapped = fzf_wrap("test", {
		source = util.split(result.output, "\n"),
	})

	wrapped["sink*"] = nil
	wrapped["sinklist"] = nil

	wrapped.sink = function(line)
		if line ~= nil and line ~= "" then
			local t_minus = util.split(line, ")")[1]
			local resume_cmd = "xai chat resume " .. t_minus
			vim.fn.jobstart(resume_cmd, {
				on_stdout = function(_, data, _)
					if #data > 1 then
						local response = json.decode(data[1])
						local bufnr = get_buf_by_thread_id(response["ThreadID"])
						if bufnr == nil then
							bufnr = init_chat()
							states[bufnr].thread_id = response["ThreadID"]
						end
						local new_lines = parse_response(response)
						vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, new_lines)
						if states[bufnr].buffer_sync_cursor then
							vim.schedule(function()
								vim.api.nvim_win_call(states[bufnr].winnr, function()
									vim.cmd("normal! G$")
								end)
							end)
						end
						local bufname = "xai://" .. states[bufnr].thread_id
						states[bufnr].bufname = bufname
						vim.api.nvim_buf_set_name(bufnr, bufname)

						vim.api.nvim_set_option_value("modifiable", true, { buf = bufnr }) -- allow user input again
						states[bufnr].is_receiving = false
						add_transcript_header(bufnr, "user")
					end
				end,
			})
		end
	end

	fzf_run(wrapped)
end

function M.ChatBotSubmit(bufnr)
	if states[bufnr].is_receiving then
		print("Already receiving")
		return
	end

	vim.cmd("normal! Go")
	states[bufnr].buffer_sync_cursor = true

	local messages = parse_messages(bufnr)
	local last_message = messages[#messages]
	local role = table.remove(last_message, 1)
	if role ~= roles["user"] then
		print("Missing user input")
		return
	end

	local user_input = table.concat(last_message, "\\n")
	user_input = string.gsub(user_input, '"', '\\"')
	user_input = string.gsub(user_input, "`", "\\`")
	-- vim.print(user_input)
	local prompt_cmd = 'xai prompt "' .. user_input .. '"'
	-- vim.print(prompt_cmd)
	if states[bufnr].thread_id ~= nil then
		-- pass thread to the request
		prompt_cmd = prompt_cmd .. " --thread-id " .. states[bufnr].thread_id
	end
	local job_id = vim.fn.jobstart(prompt_cmd, {
		on_stdout = function(_, data, _)
			receive_data(bufnr, data)
		end,
		on_exit = function(_, _, _)
			done(bufnr)
		end,
		on_stderr = function(_, data, _)
			vim.print(data)
		end,
	})

	if job_id > 0 then
		states[bufnr].is_receiving = true
		add_transcript_header(bufnr, "assistant")
	end
end

return M
