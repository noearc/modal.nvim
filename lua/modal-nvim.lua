local M = {}
local Job = require("plenary.job")

local DEFAULTS = {
	boot = {
		-- 	modal = {
		-- 	mo	file = vim.api.nvim_get_runtime_file("BootTidal.hs", false)[1],
		-- 		args = {},
		-- 	},
		sclang = {
			use_boot_file = true,
			file = vim.api.nvim_get_runtime_file("BootSuperDirt.scd", false)[1],
			enabled = false,
		},
		-- split = "v",
	},
	keymaps = {
		send_line = "<leader>l",
		-- send_node = "<Leader>s",
		send_block = "<leader>e",
		send_visual = "<leader>l",
		hush = "<leader>.",
	},
}

local KEYMAPS = {
	send_line = {
		mode = "n",
		action = "Vy<cmd>lua require('modal-nvim').send_reg()<CR><ESC>",
		description = "send line to Tidal",
	},
	-- 	send_node = {
	-- 		mode = "n",
	-- 		action = function()
	-- 			T.send_node()
	-- 		end,
	-- 		description = "send treesitter node to Tidal",
	-- 	},
	send_block = {
		mode = "n",
		action = function()
			M.send_block()
		end,
		description = "send block to Tidal",
	},
	send_visual = {
		mode = "v",
		action = "y<cmd>lua require('nvim-modal').send_reg()<CR>",
		description = "send selection to Tidal",
	},
	hush = {
		mode = "n",
		action = function()
			M.send("hush!")
		end,
		description = "send 'hush' to Tidal",
	},
}

local state = {
	launched = false,
	modal = nil,
	sclang = nil,
	modal_process = nil,
	sclang_process = nil,
}

function M.send(text)
	-- if not state.modal_process then
	-- 	print("no proc")
	-- 	return
	-- end
	-- text = yue.to_lua(text)
	vim.api.nvim_chan_send(state.repl_process, text .. "\n")
end

function M.send_current_line()
	local l = vim.api.nvim_get_current_line()
	M.send(l)
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
			res = table.concat(vim.api.nvim_buf_get_lines(0, sections[i - 1], sections[i], false), "")
			M.send(res)
			break
		end
	end
end

function M.send_all()
	M.send(table.concat(Lines, "\n"))
end

-- TODO: send visual
function M.send_reg(register)
	print("tppp")
	if not register then
		register = ""
	end
	local text = table.concat(vim.fn.getreg(register, 1, true), "\n")
	M.send(text)
end

local function boot_modal(args)
	if state.modal then
		local ok = pcall(vim.api.nvim_set_current_buf, state.modal)
		if not ok then
			state.modal = nil
			boot_modal(args)
			return
		end
	else
		state.modal = vim.api.nvim_create_buf(false, false)
		boot_modal(args)
		return
	end
	-- state.modal_process = vim.fn.termopen("mods", {
	-- 	on_exit = function()
	-- 		if #vim.fn.win_findbuf(state.modal) > 0 then
	-- 			vim.api.nvim_win_close(vim.fn.win_findbuf(state.modal)[1], true)
	-- 		end
	-- 		vim.api.nvim_buf_delete(state.modal, {})
	-- 		state.modal = nil
	-- 		state.modal_process = nil
	-- 	end,
	-- })
	state.modal_process = Job:new({
		command = "mods",
		args = { 9000 }, -- FIND avail
		on_exit = function()
			print("server quit!")
		end,
	})
	print(vim.inspect(state.modal_process))
	state.modal_process:start()

	state.repl_process = vim.fn.termopen("modal", {
		on_exit = function()
			if #vim.fn.win_findbuf(state.modal) > 0 then
				vim.api.nvim_win_close(vim.fn.win_findbuf(state.modal)[1], true)
			end
			vim.api.nvim_buf_delete(state.modal, {})
			state.modal = nil
			state.modal_process:shutdown()
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
	local sclang = "sclang"
	if args.use_boot_file then
		sclang = "sclang " .. args.file
	end
	state.sclang_process = vim.fn.termopen(sclang, {
		on_exit = function()
			if #vim.fn.win_findbuf(state.sclang) > 0 then
				vim.api.nvim_win_close(vim.fn.win_findbuf(state.sclang)[1], true)
			end
			vim.api.nvim_buf_delete(state.sclang, {})
			state.sclang = nil
			state.sclang_process = nil
		end,
	})
end

local function launch_modal(args)
	local current_win = vim.api.nvim_get_current_win()
	if state.launched then
		return
	end
	vim.cmd(args.split == "v" and "vsplit" or "split")
	boot_modal(args.modal)
	-- vim.cmd(args.split == "v" and "split" or "vsplit")
	-- boot_sclang(args.sclang)
	vim.api.nvim_set_current_win(current_win)
	state.launched = true
	Lines = vim.api.nvim_buf_get_lines(0, 0, -1, true)
end

-- TODO:
local function exit()
	if not state.launched then
		return
	end
	if state.modal_process then
		-- vim.fn.jobstop(state.modal_process)
		state.modal_process:shutdown()
	end
	if state.sclang_process then
		vim.fn.jobstop(state.sclang_process)
	end
	state.launched = false
end

-- TODO:

local function key_map(key, mapping)
	vim.keymap.set(KEYMAPS[key].mode, mapping, KEYMAPS[key].action, {
		buffer = true,
		desc = KEYMAPS[key].description,
	})
end

function M.setup(args)
	args = vim.tbl_deep_extend("force", DEFAULTS, args)
	vim.api.nvim_create_user_command("ModalLaunch", function()
		launch_modal(args.boot)
	end, { desc = "launches Modal instance, including sclang if so configured" })
	vim.api.nvim_create_user_command("ModalExit", function()
		exit()
	end, { desc = "quits modal instance" })
	vim.api.nvim_create_autocmd({ "BufEnter", "BufWinEnter" }, {
		pattern = { "*.modal" },
		callback = function()
			-- vim.cmd("set ft=yue")
			for key, value in pairs(args.keymaps) do
				key_map(key, value)
			end
		end,
	})

	vim.api.nvim_create_autocmd("VimLeave", {
		pattern = { "*.modal" },
		callback = function()
			exit()
		end,
	})
end

return M
