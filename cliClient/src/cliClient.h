#include <optional>
#include <string>

#include "lualibs/jsonlua.h"
#include "lualibs/artifactlua.h"

#include "external/lua/lua.hpp"

#include "external/LuaBridge.h"
#include "external/httplib.h"
#include "external/json11.hpp"
using namespace json11;

struct client {
	httplib::Client httpCli;
	
	httplib::Result get(std::string apiPath, Json apiParams = Json::object{});
	httplib::Result post(std::string apiPath, Json apiParams);

	std::string charName;

	std::vector<Json> getChars();
	
	lua_State* lua;

	client(std::string hostname) : httpCli(hostname) {
		lua = luaL_newstate();
		luaL_openlibs(lua);
	}
};

struct args {
	std::string scriptfile;
	std::string schema;
	bool help;
	void parseArgs(int argc, char** argv);

	const std::string HELP_STRING=
R"(artiLua clientCLI - by RadsammyT
    <filename> - specify the script to run.
            -s - specify the server host to connect to. default is 127.0.0.1:6969
   --help | -h - display this help
)";
};

static client* GLOBAL_CLIENT;
void SET_CLIENT_POINTER(client* addr);

namespace lua {
	Json Table2Json(luabridge::LuaRef& ref);
	void setupCliLibs(client& cli);
	void run(std::string filename);

	std::string lget(std::string apiPath, std::string apiParams);
	std::string lpost(std::string apiPath, std::string apiParams);
}

template<typename ... Args>
std::string format( const std::string& format, Args ... args );
/*{
    int size_s = std::snprintf( nullptr, 0, format.c_str(), args ... ) + 1; // Extra space for '\0'
    if( size_s <= 0 ){ throw std::runtime_error( "Error during formatting." ); }
    auto size = static_cast<size_t>( size_s );
    std::unique_ptr<char[]> buf( new char[ size ] );
    std::snprintf( buf.get(), size, format.c_str(), args ... );
    return std::string( buf.get(), buf.get() + size - 1 ); // We don't want the '\0' inside
}*/

