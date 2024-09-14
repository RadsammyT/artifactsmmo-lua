print("begin")
local utils = require("utils.lua")
print("finished utils")
local tasks = require("task.init")
print("finished task.init")
function Main()
	if #arti.args < 2 then
		print("not enough args. expected 2: charname, taskMasterType")
	end
	local CHAR_NAME = arti.args[1]
	local TM_TYPE = arti.args[2]

	print("awaiting cooldown")
	utils.awaitCooldownChar(CHAR_NAME)
	print("done: awaiting cooldown")
	while true do
		if TM_TYPE == "monsters" then
			tasks.monster.doTask(CHAR_NAME)
		else
			error(string.format("unimplemented task type %s", TM_TYPE))
		end
	end
end

local status, err = xpcall(Main, debug.traceback)
print(status)
print(err)
