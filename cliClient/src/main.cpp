#define JSON11_IMPLEMENTATION

#include <iostream>
#include <map>
#include <vector>


#include "external/httplib.h"
#include "external/json11.hpp"
#include "cliClient.h"

using namespace json11;

int main(int argc, char** argv) {
	args args;
	args.parseArgs(argc, argv);
	client cli(args.schema);
	SET_CLIENT_POINTER(&cli);
	lua::setupCliLibs(cli);
	luaL_dostring(cli.lua, R"(
		print('hello world from lua in C++') 
	)");
	if(luaL_dofile(cli.lua, args.scriptfile.c_str()) != LUA_OK) {
		luaL_error(cli.lua, "SCRIPT ERROR: %s\n", lua_tostring(cli.lua, -1));
	}
	return 0;
}
