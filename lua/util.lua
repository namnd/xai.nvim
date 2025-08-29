M = {}

---@diagnostic disable: duplicate-set-field
M.split = function(inputstr, sep)
	if sep == nil then
		sep = "%s"
	end
	local t = {}
	for str in string.gmatch(inputstr, "([^" .. sep .. "]+)") do
		table.insert(t, str)
	end
	return t
end

M.execute_command = function(command)
	local result = {}
	local handle = io.popen(command, "r")
	if handle then
		result.output = handle:read("*a")
		local success, _, exit_code = handle:close()
		result.success = success
		result.exit_code = exit_code or nil
	else
		result.error = "Failed to execute command"
	end
	return result
end

M.remove_last_empty = function(l)
	local r = {}
	for _, e in ipairs(l) do
		if e ~= "" then
			table.insert(r, e)
		end
	end
	return r
end

M.capitalize_first = function(str)
	if str and #str > 0 then
		return string.upper(string.sub(str, 1, 1)) .. string.sub(str, 2)
	else
		return str -- Return original if string is empty or nil
	end
end

return M
