local utils = require "utils.lua"
local f = string.format

--[[
-- ge.lua
-- 	buys from gold in bank OR sells item in bank. 
-- 	args: (SCRIPT_FILENAME) (buy/sell) item_code
--]]

function Main()
	local CHAR_NAME = ""
	local SCRIPT_MODE = ""
	local CODE_ITEM = ""

	if #arti.args < 3 then
		print("Not enough args. Expected 3: char_name (buy/sell) item_code")
	else 
		CHAR_NAME = arti.args[1]
		SCRIPT_MODE = arti.args[2]
		CODE_ITEM = arti.args[3]
	end
	if SCRIPT_MODE:lower() == "buy" then
		Buy(CHAR_NAME, CODE_ITEM)
	elseif SCRIPT_MODE:lower() == "sell" then
		Sell(CHAR_NAME, CODE_ITEM)
	end
end

function Buy(CHAR_NAME, CODE_ITEM)
	--[[
	--	goto bank
	--	withdraw all (if any)
	--	check item cost and withdraw if sufficient 
	--		else wait and check again
	--	goto GE
	--	buy items 
	--
	--]]
	local bankTile = utils.findMap("bank", "bank", CHAR_NAME)
	utils:DepositAll(CHAR_NAME)
	local gotoBank = arti:post(f("/my/%s/action/move", CHAR_NAME), bankTile)
	if gotoBank.status == "490" then
		gotoBank.IGNORE = 1
	end
	utils.awaitCooldown(gotoBank)
	::retry::
	local itemInfo = arti:get(f("/items/%s", CODE_ITEM))
	local goldInfo = arti:get(f("/my/bank/gold"))
	local charInfo = arti:get(f("/my/characters/%s", CHAR_NAME))
	if goldInfo.data.quantity + charInfo.data.gold < itemInfo.data.ge.buy_price then
		arti.sleep(20)
		goto retry
	end
	local goldToWithdraw = itemInfo.data.ge.buy_price - charInfo.data.gold
	if goldToWithdraw > 0 then
		local withdrawGold = arti:post(f("/my/%s/action/bank/withdraw/gold", CHAR_NAME), {
			["quantity"] = goldToWithdraw
		})
		if withdrawGold.status ~= "200" then
			goto retry
		end
	end
	local grandExTile = utils.findMap("grand_exchange", "grand_exchange", CHAR_NAME)
	local gotoGrandEx = arti:post(f("/my/%s/action/move", CHAR_NAME), grandExTile)
	utils.awaitCooldown(gotoGrandEx)
end

function Sell(CHAR_NAME, CODE_ITEM)

end

local status, err = xpcall(Main, debug.traceback)
print(status)
print(err)
