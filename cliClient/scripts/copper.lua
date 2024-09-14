--[[
-- copper.lua 
-- 	mines a resource, crafts another resource once inv is full (if the crafted
-- 	resource's ingredient is only just the mined resource) and then banks.
--]]

function Main()
	local utils = require("utils.lua")
	local CHAR_NAME = "UNKNOWN"
	local CODE_MAP_RESOURCE = "iron_rocks"
	local CODE_ITEM_RESOURCE = "iron_ore"
	local CODE_CRAFT_RESOURCE = "iron"
	local CODE_CRAFT_REQUIRE = tonumber(6)
	local CODE_WORKSHOP_TYPE = "mining"
	local CODE_CRAFT_DIVISOR = tonumber(1) -- craft X times as less items than normal

	local DO_NOT_FORGE = false

	if #arti.args < 7 then
		print(
			"not enough args. expected 7 (or 2 to disable forging):"
			.. " charname, codeMapResource, codeItemResource, codeCraftResource, codeCraftRequire, codeWorkshopType"
			.. ", codeCraftDivisor"
			)
		if #arti.args < 2 then return 1; end
	end
	if #arti.args == 2 then
		print("2 arguments detected. diabling forging and continuing anyway...")
		CHAR_NAME = arti.args[1]
		CODE_MAP_RESOURCE = arti.args[2]
		DO_NOT_FORGE = true
	else
		CHAR_NAME = arti.args[1]
		CODE_MAP_RESOURCE = arti.args[2]
		CODE_ITEM_RESOURCE = arti.args[3]
		CODE_CRAFT_RESOURCE = arti.args[4]
		CODE_CRAFT_REQUIRE = tonumber(arti.args[5])
		CODE_WORKSHOP_TYPE = arti.args[6]
		CODE_CRAFT_DIVISOR = tonumber(arti.args[7])
	end

	local copperPos = {["x"] = 0, ["y"] = 0}
	local forgePos = {["x"] = 0, ["y"] = 0}
	local bankPos = {x = 0, y = 0}

	copperPos = utils.findMap(CODE_MAP_RESOURCE, "resource", CHAR_NAME)
	forgePos = utils.findMap(CODE_WORKSHOP_TYPE, "workshop", CHAR_NAME)
	bankPos = utils.findMap("bank", "bank", CHAR_NAME)

	print("positions:")
	print(string.format("copper: %d %d", copperPos["x"], copperPos["y"]))
	print(string.format("bank: %d %d", bankPos["x"], bankPos["y"]))

	utils.awaitCooldownChar(CHAR_NAME)

	while true do
		local move = arti:post(string.format("/my/%s/action/move", CHAR_NAME), copperPos)
		if move["status"] ~= "200" then
			if tonumber(move["status"]) == "499" then
				print(move)
			end
			if move["status"] == "490" then
				move["IGNORE"] = 1
			end
		end
		utils.awaitCooldown(move)
		local mine = arti:post(string.format("/my/%s/action/gathering", CHAR_NAME), {})
		if mine["status"] ~= "200" then
			print(move["status"])
			if mine["status"] == "497" then
				if not DO_NOT_FORGE then
					local forgeMove =
						arti:post(string.format("/my/%s/action/move", CHAR_NAME), forgePos)
					utils.awaitCooldown(forgeMove)
					local itemsToCraft =
						math.floor(
							(
								utils.getItemCount(
									CHAR_NAME,
									CODE_ITEM_RESOURCE
								) / CODE_CRAFT_REQUIRE) / CODE_CRAFT_DIVISOR)
					if itemsToCraft ~= 0 then
						local forgeCraft =
							arti:post(string.format("/my/%s/action/crafting", CHAR_NAME),
							{
								["code"] = CODE_CRAFT_RESOURCE,
								["quantity"] = tostring(itemsToCraft)
							}
						)
						local obtained = (itemsToCraft)
						utils.awaitCooldown(forgeCraft)
					end
				end
				utils:DepositAll(CHAR_NAME)
			end
		else
			utils.awaitCooldown(mine)
		end
	end
end

local status, err = xpcall(Main, debug.traceback)
print(status)
print(err)
