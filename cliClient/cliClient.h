#include <optional>
#include <string>

#include "external/lua/lua.h"
#include "external/lua/lauxlib.h"
#include "external/lua/lualib.h"
#include "external/LuaBridge.h"
#include "external/httplib.h"
#include "external/json11.hpp"
using namespace json11;

struct client {
	httplib::Client httpCli;
	
	httplib::Result get(std::string apiPath, Json apiParams = Json::object{});
	httplib::Result post(std::string apiPath, Json apiParams);

	std::vector<Json> getChars();
	
	lua_State* lua;

	client() : httpCli("127.0.0.1:6969") {
		lua = luaL_newstate();
		luaL_openlibs(lua);
	}
};

struct task {
	enum {
		GET,
		POST,
	} requestType;
	std::string apiPath;
	Json apiParams;
};

namespace input {
	std::optional<int> readInt(int min, int max);
}

namespace lua {
	Json Table2Json(luabridge::LuaRef& ref);
	void setupCliLibs(client& cli);
	void run(std::string filename);
}
