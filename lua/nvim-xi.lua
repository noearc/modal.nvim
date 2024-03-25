local socket = require("socket")
local yue = require("yue")
local M = {}
require("moon.all")

function M.init(...)
	print(...)
	host = host or "localhost"
	port = port or 8080
	Sock = socket.connect(host, port)
	Lines = vim.api.nvim_buf_get_lines(0, 0, -1, true)
	-- print("XI: Connected to " .. host .. ": " .. port)
end

function M.send_current_line()
	local l = vim.api.nvim_get_current_line()
	Sock:send(yue.to_lua(l))
end

local update_lines = function()
	Lines = vim.api.nvim_buf_get_lines(0, 0, -1, true)
end

vim.api.nvim_create_autocmd({ "InsertLeave", "TextChanged", "TextChangedI", "BufEnter" }, { callback = update_lines })

local get_sections = function(text)
	local res = { 0 }
	for i, v in pairs(text) do
		if v == "" then
			table.insert(res, i - 1)
		end
	end
	table.insert(res, #text)
	return res
end

function M.send_block()
	local cursor = vim.api.nvim_win_get_cursor(0)
	local sections = get_sections(Lines)
	for i, v in ipairs(sections) do
		local res = ""
		if cursor[1] <= v then
			res = table.concat(vim.api.nvim_buf_get_lines(0, sections[i - 1], sections[i], false), "\n")
			Sock:send(yue.to_lua(res))
			break
		end
	end
end

function M.send_all()
	Sock:send(yue.to_lua(table.concat(Lines, "\n")))
end

return M
