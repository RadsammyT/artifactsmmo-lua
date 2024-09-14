local utils = require("utils.lua")
local f = string.format
local WAIT_TIME <const> = 60 * 1
function Main()
	local CHAR_NAME = ""
	local RECIPE_NAME = ""
	local RECIPE_COUNT = 0
	local RECIPE_INGREDS = {}
	local RECIPE_WORKSHOP = nil
	-- variable args
	-- args must be:
	-- 	char_name item_code item_quantity ... recipe recipe_count
	if #arti.args % 2 ~= 1 and #arti.args < 5 then
		print("args: char_name recipe recipe_count")
		error("args count is either even or less than 5. this is bad!")
	end
	CHAR_NAME = arti.args[1]
	RECIPE_NAME = arti.args[2]
	RECIPE_COUNT = arti.args[3]
	utils.awaitCooldownChar(CHAR_NAME)
	local req = arti:get(string.format("/characters/%s", CHAR_NAME))
	for _, value in ipairs(req["data"]["inventory"]) do
		if value["quantity"] > 0 then
			utils:DepositAll(CHAR_NAME)
			break
		end
	end
	req = arti:get(f("/items/%s", RECIPE_NAME))
	RECIPE_WORKSHOP = req["data"]["item"]["craft"]["skill"]
	for _, value in ipairs(req["data"]["item"]["craft"]["items"]) do
		RECIPE_INGREDS[value["code"]] = value["quantity"]
	end
	print("parsed:")
	print(f("crafting %d of %s @ %s with :", RECIPE_COUNT, RECIPE_NAME, RECIPE_WORKSHOP))
	PrintTable(RECIPE_INGREDS)
	local workshopLoco = utils.findMap(RECIPE_WORKSHOP, "workshop", CHAR_NAME)
	while true do
		local bank = utils.findMap("bank", "bank", CHAR_NAME)
		local gotoBank = arti:post(f("/my/%s/action/move", CHAR_NAME), bank)
		if gotoBank["status"] == "490" then
			gotoBank["IGNORE"] = 1
		end
		local stuckAtBank = false
		::recheckbank::
		local bankCheck = CheckBank(RECIPE_INGREDS)
		if bankCheck < tonumber(RECIPE_COUNT) then
			if not stuckAtBank then
				print("bank doesnt have what we need for one run. waiting...")
				stuckAtBank = true
			end
			arti.sleep(WAIT_TIME)
			goto recheckbank
		end
		if stuckAtBank then
			print("we got what we need. continuing...")
		end
		utils.awaitCooldown(gotoBank)
		for key, value in pairs(RECIPE_INGREDS) do
			local withdrawItem = arti:post(f("/my/%s/action/bank/withdraw", CHAR_NAME),
				{
					["code"] = key,
					["quantity"] = value * tonumber(RECIPE_COUNT)
				}
			)
			if withdrawItem["status"] ~= "200" then
				PrintTable(withdrawItem)
				print("UHOH! Got error code for withdrawing from bank")
				utils:DepositAll(CHAR_NAME)
				goto recheckbank
			end
			utils.awaitCooldown(withdrawItem)
		end

		local gotoWorkshop = arti:post(f("/my/%s/action/move", CHAR_NAME), workshopLoco)
		utils.awaitCooldown(gotoWorkshop)
		local craftItems = arti:post(f("/my/%s/action/crafting", CHAR_NAME), {
			["code"] = RECIPE_NAME,
			["quantity"] = tonumber(RECIPE_COUNT)
		})
		if craftItems["status"] ~= "200" then
			PrintTable(craftItems)
			error("Unable to craft item!")
		end
		utils.awaitCooldown(craftItems)
		utils:DepositAll(CHAR_NAME)
	end
end

-- where itemstable is of format: 
-- {
--	["itemCodeName"] = itemRequiredQuantity 
-- }
-- returns how many times of all items we can take for crafting. if 0, then 
-- items are unavailable
function CheckBank(itemsTable)

	local function keyLen(table)
		local result = 0
		for _, _ in pairs(table) do
			result = result + 1
		end
		return result
	end

	local req = arti:get("/my/bank/items", {["size"] = "99"})
	if req["status"] ~= "200" then
		print(f("Unable to get bank (%s). Zeroing.", req["status"]))
		PrintTable(req)
		return 0
	end
	if req["total"] > req["size"] then
		error("UNIMPLEMENTED: Bank paging")
	end
	local bankItems = req["data"]
	local craftItemsInBank = {}
	local returnedTimes = nil
	for _, BV in ipairs(bankItems) do
		for TI, TV in pairs(itemsTable) do
			if BV["code"] == TI then
				if returnedTimes == nil then
					returnedTimes = math.floor(BV["quantity"] / TV)
					craftItemsInBank[BV["code"]] = BV["quantity"]
					goto pass
				end
				local testedTimes = math.floor(BV["quantity"] / TV)
				craftItemsInBank[BV["code"]] = BV["quantity"]
				if testedTimes < returnedTimes then
					returnedTimes = testedTimes
				end
			end
			::pass::
		end
	end
	if returnedTimes == nil then
		print("returnedTimes still nil???? Zeroing.")
		returnedTimes = 0
	end
	if keyLen(craftItemsInBank) ~= keyLen(itemsTable) then
		returnedTimes = 0
	end
	return returnedTimes
end

local status, err = xpcall(Main, debug.traceback)
print(status)
print(err)
