local utils = require "utils.lua"
local f = string.format

function ResizeResources(resources, invSize)
	local initialSize = 0
	for _, value in pairs(resources) do
		initialSize = initialSize + tonumber(value)
	end
	local multiplier = math.floor(invSize / initialSize)
	for key, value in pairs(resources) do
		resources[key] = tonumber(value) * multiplier
	end
	resources["multiplier"] = multiplier
	return resources
end

function GetItemFromResource(resourceName)
	local resource = arti:get(f("/resources/%s", resourceName))
	return resource.data.drops[1]
end

function Main()
	local CHAR_NAME = ""
	--[[
	--	[key: resource_name] = value: num_of_resources, integer
	--]]
	local RESOURCES = {}
	local RECIPE = ""
	-- resource_name = copper_rocks
	-- example args CHAR_NAME copper_rocks 2 iron_rocks 4 steel
	local keyOrValue = true
	for index, value in ipairs(arti.args) do
		if index == 1 then
			CHAR_NAME = value
			goto continue
		end
		if index == #arti.args then
			RECIPE = value
			goto continue
		end
		if keyOrValue then
			RESOURCES[value] = 0
			keyOrValue = not keyOrValue
			goto continue
		end
		if not keyOrValue then
			RESOURCES[arti.args[index-1]] = tonumber(value)
			keyOrValue = not keyOrValue
			goto continue
		end
		::continue::
	end
	local charInfo = arti:get(f("/characters/%s", CHAR_NAME))
	RESOURCES = ResizeResources(RESOURCES, tonumber(charInfo.data.inventory_max_items))
	local recipeData = arti:get(f("/items/%s", RECIPE))
	print(CHAR_NAME)
	PrintTable(RESOURCES)
	print(RECIPE)
	utils:DepositAll(CHAR_NAME)
	while true do
		for key, value in pairs(RESOURCES) do
			if key == "multiplier" then
				goto pass
			end
			local amtMined = 0
			amtMined = utils.getItemCount(CHAR_NAME, GetItemFromResource(key))
			local tile = utils.findMap(key, "resource", CHAR_NAME)
			local moveTo = arti:post(f("/my/%s/action/move", CHAR_NAME), tile)
			if moveTo.status ~= "200" then
				if moveTo.status == "490" then
					moveTo.IGNORE = "1"
				end
			end
			utils.awaitCooldown(moveTo)
			while amtMined < value do
				local mineResource = arti:post(f("/my/%s/action/gathering", CHAR_NAME))
				if mineResource.status ~= "200" then
					print("ERROR: unable to mine")
					if mineResource.status == "497" then utils:DepositAll(CHAR_NAME) end
					PrintTable(mineResource)
				else
					amtMined = amtMined + 1
					utils.awaitCooldown(mineResource)
				end
			end
			::pass::
		end
		local workshopTile = utils.findMap(
			recipeData.data.item.craft.skill,
			"workshop",
			CHAR_NAME
		)
		local gotoWorkshop = arti:post(f("/my/%s/action/move", CHAR_NAME), workshopTile)
		if gotoWorkshop.status == "490" then
			gotoWorkshop.IGNORE = "1"
		end
		utils.awaitCooldown(gotoWorkshop)
		local craftRecipe = arti:post(f("/my/%s/action/crafting", CHAR_NAME), {
			["code"] = RECIPE,
			["quantity"] = RESOURCES.multiplier
		})
		if craftRecipe.status ~= "200" then
			print("UHOH! crafting errored")
			PrintTable(craftRecipe)
			error("Crafting errored. See above logs.")
		end
		utils.awaitCooldown(craftRecipe)
		utils:DepositAll(CHAR_NAME)
	end
end

local status, err = xpcall(Main, debug.traceback)
print(status)
print(err)
