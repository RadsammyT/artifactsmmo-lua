local test = require("task.init")
function Main()
	PrintTable(test)
	PrintTable(string)
	local testTable = {
		["text"] = "test"
	};
	local x = testTable["CLEARLY ILLEGAL"]
	x = x + 1
end

local ok, err = xpcall(Main, debug.traceback)
print(ok)
print(err)


