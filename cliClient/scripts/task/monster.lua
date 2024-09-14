local utils = require("utils.lua")
local f = string.format
local gearTable = {
	["ogre"] = {
		["level"] = 20, -- char must be at or greater than this level
		["weapon_slot"] = "skull_staff",
		["shield_slot"] = "steel_shield",
		["helmet_slot"] = "steel_helm",
		["body_armor_slot"] = "steel_armor",
		["leg_armor_slot"]  = "iron_legs_armor",
		["boots_slot"] = "steel_boots",
		["ring1_slot"] = "ring_of_chance",
		["ring2_slot"] = "ring_of_chance",
		["amulet_slot"] = "fire_and_earth_amulet"
	},
	["vampire"] = {
		["level"] = 20,
		["weapon_slot"] = "steel_axe",
		["shield_slot"] = "steel_shield",
		["helmet_slot"] = "tromatising_mask",
		["body_armor_slot"] = "serpent_skin_armor",
		["leg_armor_slot"]  = "serpent_skin_legs_armor",
		["boots_slot"] = "steel_boots",
		["ring1_slot"] = "dreadful_ring",
		["ring2_slot"] = "dreadful_ring",
		["amulet_slot"] = "fire_and_earth_amulet"
	},
	["default"] = {
		["level"] = 15,
		["weapon_slot"] = "multislimes_sword",
		["shield_slot"] = "slime_shield",
		["helmet_slot"] = "adventurer_helmet",
		["body_armor_slot"] = "adventurer_vest",
		["leg_armor_slot"]  = "iron_legs_armor",
		["boots_slot"] = "iron_boots",
		["ring1_slot"] = "iron_ring",
		["ring2_slot"] = "iron_ring",
		["amulet_slot"] = "life_amulet"
	}
}
local function getGearForTask(monster)
	if gearTable[monster] == nil then
		return gearTable["default"]
	end
	return gearTable[monster]
end

local function isGearOkay(charInfo)
	for GK, GV in pairs(getGearForTask(charInfo.data.task)) do
		if GK == "level" then
			goto pass
		end
		if charInfo.data[GK] ~= GV then
			print(f("gear not okay: slot %s is %s and not %s", GK, charInfo.data[GK], GV))
			return false
		end
		::pass::
	end
	return true
end
local fn = {}
	function fn.skipTask(charName)
		if utils.getItemCountBank("tasks_coin") ~= 0 then
			local gotoBank = arti:post(f("/my/%s/action/move", charName), utils.findMap("bank", "bank", charName))
			if gotoBank.status == "490" then
				gotoBank.IGNORE = "1"
			end
			utils.awaitCooldown(gotoBank)
			local getCoin = arti:post(f("/my/%s/action/bank/withdraw", charName), {
				code = "tasks_coin",
				quantity = 1
			})
			utils.awaitCooldown(getCoin)
		end
		if utils.getItemCount(charName, "tasks_coin") ~= 0 then
			local gotoTM = arti:post(f("/my/%s/action/move", charName), utils.findMap("monsters", "tasks_master", charName))
			utils.awaitCooldown(gotoTM)
			local skipTask = arti:post(f("/my/%s/action/task/cancel", charName))
			utils.awaitCooldown(skipTask)
		else
			error("Task coin error!")
		end
	end
	function fn.prepTask(charName)
		--[[
			check current task- if equipped gear matches that of the 
			gear on the below E2G table, then finish prep.
			else, go to bank, then, for each gear slot on char/table, do:
			if charGear is tableGear:
				continue.
			else:
				unequip charGear
				deposit charGear
				withdraw tableGear 
				equip tableGear
			finish prep.
			enemy-to-gear table?
			{
				["ogre"] = {
					["level"] = 20, -- char must be at or greater than this level
					["weapon_slot"] = "skull_staff",
					["shield_slot"] = "steel_shield"
					["helmet_slot"] = "steel_helmet"
					-- boots slot can be one of the two but checks
					-- for first indices by priority
					["boots_slot"] = ["steel_boots", "leather_boots"]
				}
				["vampire"] = {...}
				-- if the key indexing into this table may return nil,
				-- refer to this entry
				-- because were prolly facing an enemy we can 
				-- defeat easily rather than having to minmax gear
				-- just to defeat 100%.
				["default"] = {...}
			}
			
		--]]

		local charInfo = arti:get(string.format("/characters/%s", charName));
		if isGearOkay(charInfo) then
			print("Gear already suitable for task.")
			return true
		end
			print("Gear currently unsuitable for task. Obtaining proper gear...")
		local bankTile = utils.findMap("bank", "bank", charName)
		local gotoBank = arti:post(f("/my/%s/action/move", charName), bankTile)
		if gotoBank.status == "490" then
			gotoBank.IGNORE = "1"
		end
		utils.awaitCooldown(gotoBank)
		for GK, GV in pairs(getGearForTask(charInfo.data.task)) do
			if charInfo.data[GK] ~= GV then
				if GK == "level" then
					if charInfo.data.level < GV then
						print("Level error: Char level is ", charInfo.data.level, " when required level is", GV)
						return false
					end
					goto pass
				end
				if utils.getItemCountBank(GV) == 0 then
					print(f("no item found for (%s), exiting", GV))
					return false
				end
				local unequipOld = arti:post(f("/my/%s/action/unequip", charName), {
					["slot"] = string.sub(GK, 1, string.len(GK) - 5)
				})
				if unequipOld.status == "491" then unequipOld.IGNORE = "1" end
				utils.awaitCooldown(unequipOld)
				if unequipOld.status ~= "491" then
					local depositOld = arti:post(f("/my/%s/action/bank/deposit", charName), {
						["code"] = charInfo.data[GK],
						["quantity"] = 1,
					})
					utils.awaitCooldown(depositOld)
				end
				local withdrawNew = arti:post(f("/my/%s/action/bank/withdraw", charName), {
					["code"] = GV,
					["quantity"] = 1,
				})
				utils.awaitCooldown(withdrawNew)
				local equipNew = arti:post(f("/my/%s/action/equip", charName), {
					["code"] = GV,
					["slot"] = string.sub(GK, 1, string.len(GK) - 5)
				})
				utils.awaitCooldown(equipNew)
				::pass::
			end
		end
		return true
	end
	function fn.doTask(charName)
		local charInfo = arti:get(string.format("/characters/%s", charName));

		if charInfo["data"]["task_type"] == "" then
			local TMM = utils.findMap("monsters", "tasks_master", charName)
			local moveToTMM = arti:post(string.format("/my/%s/action/move", charName), TMM)
			if moveToTMM["status"] ~= "200" then
				if moveToTMM["status"] == "490" then
					moveToTMM["IGNORE"] = 1
				end
			end
			utils.awaitCooldown(moveToTMM)
			local newTask = arti:post(string.format("/my/%s/action/task/new", charName))
			utils.awaitCooldown(newTask)
			charInfo = arti:get(string.format("/characters/%s", charName));
		end
		local taskProgress = tonumber(charInfo["data"]["task_progress"])
		local taskTotal = tonumber(charInfo["data"]["task_total"])
		local monster = utils.findMap(charInfo["data"]["task"], "monster", charName)
		local prepTaskResult = fn.prepTask(charName)
		if not prepTaskResult then
			print("prep task failed. skipping...")
			fn.skipTask(charName)
			return false
		end
		while taskTotal ~= taskProgress do
			local moveToMonster =
				arti:post(string.format("/my/%s/action/move", charName), monster)
			if moveToMonster["status"] ~= "200" then
				if moveToMonster["status"] == "490" then
					moveToMonster["IGNORE"] = 1
				end
			end
			utils.awaitCooldown(moveToMonster)
			local fightMon = arti:post(string.format("/my/%s/action/fight", charName))
			if fightMon["status"] ~= "200" then
				if fightMon["status"] == "497" then
					utils:DepositAll(charName)
				else
					PrintTable(fightMon)
				end
			else
				if fightMon["data"]["fight"]["result"] ~= "win" then
					PrintTable(fightMon)
					print(string.format("fought a %s and failed!", charInfo["data"]["task"]))
					utils.awaitCooldown(fightMon)
					fn.skipTask(charName)
					return false
				else
					taskProgress = taskProgress + 1
					utils.awaitCooldown(fightMon)
				end
			end
		end

		utils:DepositAll(charName)
		if taskProgress >= taskTotal then
			local TMM = utils.findMap("monsters", "tasks_master", charName)
			local moveToTMM =
				arti:post(string.format("/my/%s/action/move", charName), TMM)
			utils.awaitCooldown(moveToTMM)
			local exchangeTask =
				arti:post(string.format("/my/%s/action/task/complete", charName))
			utils.awaitCooldown(exchangeTask)
			return true
		end
	end
return fn
