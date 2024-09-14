function Main()
	local utils = require("utils.lua")
	local CHAR_NAME = ""
	local ENEMY_CODE = ""
	if #arti.args < 2 then
		print "not enough args. expected 2: charname, enemycode"
		return 1
	else
		CHAR_NAME = arti.args[1]
		ENEMY_CODE = arti.args[2]
	end

	local tile = utils.findMap(ENEMY_CODE, "monster", CHAR_NAME)

	utils.awaitCooldownChar(CHAR_NAME)

	while true do
		local moveToEnemy = arti:post(string.format("/my/%s/action/move", CHAR_NAME), tile)
		if moveToEnemy["status"] ~= "200" then
			if moveToEnemy["status"] == "490" then
				moveToEnemy["IGNORE"] = 0
			end
		end
		utils.awaitCooldown(moveToEnemy)
		local fightTheEnemy = arti:post(string.format("/my/%s/action/fight", CHAR_NAME))
		if fightTheEnemy["status"] ~= "200" then
			print(string.format("Got %s for action/fight.", fightTheEnemy["status"]))
			if fightTheEnemy["status"] == "497" then
				utils:DepositAll(CHAR_NAME)
			end
		else
			utils.awaitCooldown(fightTheEnemy)
		end
	end
end

local status, err = xpcall(Main, debug.traceback)
print(status)
print(err)
