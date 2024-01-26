local socket = require("socket")
local host = "localhost"
local yue = require("yue")
local port = 8080
local M = {}

c = socket.connect(host, port)

function M.send_current_line()
	l = vim.api.nvim_get_current_line()
	assert(c:send(yue.to_lua(l)))
end

function M.send_all()
	l = vim.api.nvim_buf_get_lines(0, 0, -1, false)
	str = table.concat(l, "\n")
	c:send(yue.to_lua(str))
end

return M
