local socket = require("socket")
local host = "localhost"
local port = 8080
local M = {}

c = assert(socket.connect(host, port))

function M.send_current_line()
	l = vim.api.nvim_get_current_line()
	assert(c:send(l .. "\n"))
end

function M.send_all()
	l = vim.api.nvim_buf_get_lines(0, 0, -1, false)
	print(table.concat(l))
	c:send(table.concat(l))
	-- assert(c:send())
end

return M
