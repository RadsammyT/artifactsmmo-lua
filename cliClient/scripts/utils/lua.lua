local STP = require "utils.StackTracePlus"
debug.traceback = STP.stacktrace
local utils = {}
function PrintTable(t, f)

   local function printTableHelper(obj, cnt)

      local cnt = cnt or 0

      if type(obj) == "table" then

         io.write("\n", string.rep("\t", cnt), "{\n")
         cnt = cnt + 1

         for k,v in pairs(obj) do

            if type(k) == "string" then
               io.write(string.rep("\t",cnt), '["'..k..'"]', ' = ')
            end

            if type(k) == "number" then
               io.write(string.rep("\t",cnt), "["..k.."]", " = ")
            end

            printTableHelper(v, cnt)
            io.write(",\n")
         end

         cnt = cnt-1
         io.write(string.rep("\t", cnt), "}")

      elseif type(obj) == "string" then
         io.write(string.format("%q", obj))

      else
         io.write(tostring(obj))
      end
   end

   if f == nil then
      printTableHelper(t)
	  print()
   else
      io.output(f)
      io.write("return")
      printTableHelper(t)
      io.output(io.stdout)
   end
end
function utils.awaitCooldown(actionTable)
	if actionTable["IGNORE"] ~= nil then
		return
	end
	if actionTable["data"] == nil then
		PrintTable(actionTable)
	end
	if actionTable["status"] == "499" then
		print(actionTable["error"]["message"]:match("%d+%.?%d"))
		local time = tonumber(tostring(actionTable["error"]["message"]):match("%d+%.?%d"))
		print(time)
		arti.sleep(time)
		return
	end
	local time = actionTable["data"]["cooldown"]["total_seconds"]
	arti.sleep(tonumber(time))
end
function utils.awaitCooldownChar(charName)
	local req = arti:get(string.format("/characters/%s", charName))
	if req["status"] ~= "200" then
		print "utils.awaitCooldownChar: tried to req char status but not 200"
		PrintTable(req)
	end
	local time = req["data"]["cooldown"]
	if (tonumber(time)) == 0 then
		return
	end
	print("sleeping for", time, "seconds")
	arti.sleep(tonumber(time))
end
function utils.getItemCount(charName, itemCode)
	local req = arti:get(string.format("/characters/%s", charName))
	if req["status"] ~= "200" then
		print("utils.getItemCount: tried to get req, but not 200")
		PrintTable(req)
		return 0
	end
	for _, val in ipairs(req["data"]["inventory"]) do
		if val["code"] == itemCode then
			return tonumber(val["quantity"])
		end
	end
	return 0
end
function utils.getItemCountBank(itemCode)
	local req = arti:get("/my/bank/items", {["item_code"] = itemCode})
	if req["status"] ~= "200" then
		print("non-200 bank")
		PrintTable(req)
		return 0
	end
	if #req["data"] == 0 then
		PrintTable(req)
		return 0
	end
	return tonumber(req["data"][1]["quantity"])
end
function utils.isInvFull(charName)
	local req = arti:get(string.format("/characters/%s", charName))
	if req["status"] ~= "200" then
		return nil
	end
	local itemCount = 0
	for _, value in ipairs(req["data"]["inventory"]) do
		itemCount = itemCount + value["quantity"]
	end
	if itemCount == req["data"]["inventory_max_items"] then
		return true
	end
	return false
end

function utils.findMap(contentCode, contentType, charName)
	local req = arti:get("/maps", {["content_code"] = contentCode, ["content_type"] = contentType})
	if req["status"] ~= "200" or #req["data"] <= 0 then
		return nil
	end
	local charInfo = arti:get(string.format("/characters/%s", charName))
	local indexOLD = nil -- OLD = Of Least Distance. what an unfortunate acronym
	if #req["data"] == 1 then
		return req["data"][1]
	end
	for index, value in ipairs(req["data"]) do
		if indexOLD == nil then
			indexOLD = index
			goto continue
		end

		local oldIndexCalcs = math.sqrt((tonumber(charInfo["data"]["x"]) - tonumber(req["data"][indexOLD]["x"]) ^ 2)
										+
											(tonumber(charInfo["data"]["y"]) - tonumber(req["data"][indexOLD]["y"]) ^ 2)
										)
		local curIndexCalcs = math.sqrt((tonumber(charInfo["data"]["x"]) - tonumber(value["x"]) ^ 2)
										+
											(tonumber(charInfo["data"]["y"]) - tonumber(value["y"]) ^ 2)
										)
		if curIndexCalcs <= oldIndexCalcs then
			indexOLD = index
		end
		::continue::
	end
	return req["data"][indexOLD]
end

function utils:DepositAll(charName)
	local bankLocation = self.findMap("bank", "bank", charName)
	local charData = arti:get(string.format("/characters/%s", charName))
	if charData["status"] ~= "200" then
		print("utils:DepositAll ERROR: Bad charData!")
		PrintTable(charData)
		return false
	end

	local isEmpty = true
	for _, v in ipairs(charData.data.inventory) do
		if tonumber(v.quantity) > 0 then
			isEmpty = false
		end
	end
	if isEmpty then
		return
	end
	local samePos = (tonumber(charData["data"]["x"]) == tonumber(bankLocation["x"]))
				and (tonumber(charData["data"]["y"]) == tonumber(bankLocation["y"]))
	if not samePos then
		local moveToBank = arti:post(string.format("/my/%s/action/move", charName), bankLocation)
		utils.awaitCooldown(moveToBank)
	end
	for _, value in ipairs(charData["data"]["inventory"]) do
		if tonumber(value["quantity"]) == 0 then
			goto continue
		end
		local depoItem = arti:post(string.format("/my/%s/action/bank/deposit", charName),
			{
				["code"] = value["code"],
				["quantity"] = value["quantity"]
			}
		)
		if depoItem["status"] ~= "200" then
			print(
				string.format("utils:DepositAll ERROR: attempted to deposit %s %s", value["code"], value["quantity"])
			)
			print(
				string.format("got bad status %s", depoItem["status"])
			)
			return false
		end
		utils.awaitCooldown(depoItem)
		::continue::
	end
end



return utils
