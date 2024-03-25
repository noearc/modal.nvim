local M = {}
local yue = require("yue")
require("moon.all")

function M.init(port)
	host = "127.0.0.1"
	port = port or 8080
	tcp = vim.loop.new_tcp()
	ok = tcp:connect(host, port, function() end)
	if ok then
		print("XI: Connected to " .. host .. ": " .. port)
	end
	-- Sock = socket.connect(host, port)
	Lines = vim.api.nvim_buf_get_lines(0, 0, -1, true)
	-- print("here")
	-- print("XI: Connected to " .. host .. ": " .. port)
end

function M.send_current_line()
	local l = vim.api.nvim_get_current_line()
	tcp:write(yue.to_lua(l))
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
			tcp:write(yue.to_lua(res))
			break
		end
	end
end

function M.send_all()
	tcp:write(yue.to_lua(table.concat(Lines, "\n")))
end

-- vim.highlight.range(0, 0, "", { 0, 0 }, { 1, 1 })
--
-- local DEFAULTS = {
-- 	boot = {
-- 		tidal = {
-- 			file = vim.api.nvim_get_runtime_file("BootTidal.hs", false)[1],
-- 			args = {},
-- 		},
-- 		sclang = {
-- 			file = vim.api.nvim_get_runtime_file("BootSuperDirt.scd", false)[1],
-- 			enabled = false,
-- 		},
-- 		split = "v",
-- 	},
-- 	keymaps = {
-- 		send_line = "<C-L>",
-- 		send_node = "<Leader>s",
-- 		send_visual = "<C-L>",
-- 		hush = "<C-H>",
-- 	},
-- }

-- local KEYMAPS = {
-- 	send_line = {
-- 		mode = "n",
-- 		action = "Vy<cmd>lua require('tidal').send_reg()<CR><ESC>",
-- 		description = "send line to Tidal",
-- 	},
-- 	send_node = {
-- 		mode = "n",
-- 		action = function()
-- 			T.send_node()
-- 		end,
-- 		description = "send treesitter node to Tidal",
-- 	},
-- 	send_visual = {
-- 		mode = "v",
-- 		action = "y<cmd>lua require('tidal').send_reg()<CR>",
-- 		description = "send selection to Tidal",
-- 	},
-- 	hush = {
-- 		mode = "n",
-- 		action = function()
-- 			T.send("hush")
-- 		end,
-- 		description = "send 'hush' to Tidal",
-- 	},
-- }

local state = {
	launched = false,
	xi = nil,
	sclang = nil,
	tidal_process = nil,
	sclang_process = nil,
}

local function boot_xi(args)
	if state.xi then
		local ok = pcall(vim.api.nvim_set_current_buf, state.xi)
		if not ok then
			state.xi = nil
			boot_xi(args)
			return
		end
	else
		state.xi = vim.api.nvim_create_buf(false, false)
		boot_xi(args)
		return
	end
	state.xi_process = vim.fn.termopen("xi", {
		on_exit = function()
			if #vim.fn.win_findbuf(state.xi) > 0 then
				vim.api.nvim_win_close(vim.fn.win_findbuf(state.xi)[1], true)
			end
			vim.api.nvim_buf_delete(state.xi)
			state.xi = nil
			state.tidal_process = nil
		end,
	})
end

local function boot_sclang(args)
	if state.sclang then
		local ok = pcall(vim.api.nvim_set_current_buf, state.sclang)
		if not ok then
			state.sclang = nil
			boot_sclang(args)
		end
	else
		state.sclang = vim.api.nvim_create_buf(false, false)
		boot_sclang(args)
		return
	end
	state.sclang_process = vim.fn.termopen("sclang", {
		on_exit = function()
			if #vim.fn.win_findbuf(state.sclang) > 0 then
				vim.api.nvim_win_close(vim.fn.win_findbuf(state.sclang)[1], true)
			end
			vim.api.nvim_buf_delete(state.sclang)
			state.sclang = nil
			state.sclang_process = nil
		end,
	})
end

function M.launch_xi(args)
	local current_win = vim.api.nvim_get_current_win()
	if state.launched then
		return
	end
	vim.cmd(args.split == "v" and "vsplit" or "split")
	boot_xi(args.tidal)
	-- vim.cmd(args.split == "v" and "split" or "vsplit")
	-- boot_sclang({})
	vim.api.nvim_set_current_win(current_win)
	state.launched = true
	M.init(8080) -- get from args
end

-- local function exit_tidal()
-- 	if not state.launched then
-- 		return
-- 	end
-- 	if state.tidal_process then
-- 		vim.fn.jobstop(state.tidal_process)
-- 	end
-- 	if state.sclang_process then
-- 		vim.fn.jobstop(state.sclang_process)
-- 	end
-- 	state.launched = false
-- end

-- function T.send_reg(register)
-- 	if not register then
-- 		register = ""
-- 	end
-- 	local text = table.concat(vim.fn.getreg(register, 1, true), "\n")
-- 	T.send(text)
-- end

-- function T.setup(args)
-- args = vim.tbl_deep_extend("force", DEFAULTS, args)
-- vim.api.nvim_create_user_command('TidalLaunch',
--   function() launch_tidal(args.boot) end,
--   { desc = "launches Tidal instance, including sclang if so configured"})
-- vim.api.nvim_create_user_command('TidalExit',
--   exit_tidal,
--   { desc = "quits Tidal instance"})
-- vim.api.nvim_create_autocmd({"BufEnter", "BufWinEnter"}, {
--   pattern = {"*.tidal"},
--   callback = function ()
--     vim.cmd 'set ft=haskell'
--     for key, value in pairs(args.keymaps) do
--       key_map(key, value)
--     end
--   end
-- })
-- end

return M
