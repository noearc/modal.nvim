-- require("modal")()
M = require("modal")
local log = require("modal.utils").log
local uv = require("luv")
local clock = M.DefaultClock

clock:start()

-- local eval = function(a)
--    if a then
--       local res, ok = M.eval("(" .. a .. ")", M)
--       if ok then
--          print(res)
--       else
--          print("Compilation error: " .. res)
--       end
--    end
--    return ">"
-- end

M()

local evalf = M.maxi(_G, true)

local eval = function(a)
	local ok, fn = pcall(evalf, a)
	if not ok then
		log.warn("syntax error: " .. fn)
	end
	local ok, res = pcall(fn)
	if ok then
		if res then
			print(res)
		end
	else
		log.warn("function error: " .. res)
	end
	return ">"
end

local timer = uv.new_timer()
timer:start(0, 10, function()
	coroutine.resume(clock.co)
end)

local colors = {
	black = "0;30",
	red = "0;31",
	green = "0;32",
	yellow = "0;33",
	blue = "0;34",
	magenta = "0;35",
	cyan = "0;36",
	white = "0;37",
	B = "1;",
	Bblack = "1;30",
	Bred = "1;31",
	Bgreen = "1;32",
	Byellow = "1;33",
	Bblue = "1;34",
	Bmagenta = "1;35",
	Bcyan = "1;36",
	Bwhite = "1;37",
}

function color(color_name)
	if usecolors then
		return "\27[" .. (colors[color_name] or "0") .. "m"
	else
		return ""
	end
end
if uv.guess_handle(0) ~= "tty" or uv.guess_handle(1) ~= "tty" then
	error("stdio must be a tty")
end
local stdin = uv.new_tty(0, true)

if uv.guess_handle(1) == "tty" then
	stdout = uv.new_tty(1, false)
	usecolors = true
else
	stdout = uv.new_pipe(false)
	uv.pipe_open(stdout, 1)
	usecolors = false
end

local function displayPrompt(prompt)
	uv.write(stdout, prompt .. " ")
end

local function onread(err, line)
	if err then
		error(err)
	end
	if line then
		local prompt = eval(line)
		displayPrompt(prompt)
	else
		uv.close(stdin)
	end
end

coroutine.wrap(function()
	displayPrompt(">")
	uv.read_start(stdin, onread)
end)()

uv.run()
