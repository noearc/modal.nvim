local uv = vim.uv
local M = {}

-- TODO: more robust connection, repl and server can all shutdown and auto connect once is back up
-- TODO: tree-sitter

local state = {
	server = nil,
	repl = nil,
	repl_buf = nil,
}

local function send(text)
	vim.api.nvim_chan_send(state.repl, text)
end

function M.eval_visual()
	vim.cmd("normal! y")
	-- print(vim.fn.getreg '"')
	send(table.concat(vim.fn.getreg('"', 1, true)) .. "\n")
end

function M.eval_line()
	vim.cmd("normal! yy")
	send(vim.fn.getreg('"'))
end

local function boot_repl()
	vim.cmd("12split")
	state.repl_buf = vim.api.nvim_create_buf(true, false)
	vim.api.nvim_set_current_buf(state.repl_buf)
	state.repl = vim.fn.termopen("modal", {
		on_exit = function()
			if #vim.fn.win_findbuf(state.repl_buf) > 0 then
				vim.api.nvim_win_close(vim.fn.win_findbuf(state.repl_buf)[1], true)
			end
			vim.api.nvim_buf_delete(state.repl_buf, {})
			state.repl = nil
		end,
	})
	vim.api.nvim_set_current_buf(state.repl_buf)
end

function M.boot()
	state.server = uv.new_thread(function()
		require("modal").server()
	end)

	boot_repl()
	vim.cmd("wincmd k")
end

--[[
d2 $ s bd
]]

local DEFAULTS = {
	keymaps = {
		eval_line = "<leader>l",
		eval_visual = "<leader>e",
		boot = "<leader>bb",
	},
}

local KEYMAPS = {
	eval_visual = {
		mode = "x",
		action = M.eval_visual,
		description = "Evaluate visual",
	},
	eval_line = {
		mode = "n",
		action = M.eval_line,
		description = "Evaluate line",
	},
	boot = {
		mode = "n",
		action = M.boot,
		description = "Boot",
	},
}

local function key_map(key, mapping)
	vim.keymap.set(KEYMAPS[key].mode, mapping, KEYMAPS[key].action, {
		buffer = true,
		desc = KEYMAPS[key].description,
	})
end

function M.setup(args)
	args = vim.tbl_deep_extend("force", DEFAULTS, args)

	vim.api.nvim_create_autocmd({ "BufEnter", "BufWinEnter" }, {
		pattern = { "*.modal" },
		callback = function()
			vim.cmd("set ft=haskell")

			for key, value in pairs(args.keymaps) do
				key_map(key, value)
			end
		end,
	})
end
return M
