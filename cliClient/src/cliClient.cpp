#include "cliClient.h"
#include "external/LuaBridge.h"
#include "external/httplib.h"
#include "external/lua/lauxlib.h"
#include <chrono>
#include <climits>
#include <exception>
#include <iostream>
#include <optional>
#include <string>
#include <thread>

httplib::Result client::get(std::string apiPath, Json apiParams) {
	retry:
	auto res = httpCli.Get("/get", {
		{"api-path", apiPath},
		{"api-params", apiParams.dump()}
	});
	if((int)res.error()) {
		printf("ERROR! On path %s of params %s, got code %d\n", apiPath.c_str(),
				apiParams.dump().c_str(), (int)res.error());
		std::this_thread::sleep_for(std::chrono::milliseconds(500));
		goto retry;
	} else if(res->status >= 500 && res->status <= 599) {
		// Finding an HTML tag in a supposedly JSON body means
		// that we got a cloudflare/API server error (returning an HTML doc).
		// so we should treat it like an httplib error
		std::this_thread::sleep_for(std::chrono::milliseconds(500));
		goto retry;
	}
	return res;
}

httplib::Result client::post(std::string apiPath, Json apiParams) {
	retry:
	auto res = httpCli.Post("/post", {
		{"api-path", apiPath}
	}, apiParams.dump(), "application/json");
	if((int)res.error()) {
		printf("ERROR! On path %s of params %s, got code %d\n", apiPath.c_str(),
				apiParams.dump().c_str(), (int)res.error());
		std::this_thread::sleep_for(std::chrono::milliseconds(500));
		goto retry;
	} else if(res->status >= 500 && res->status <= 599) {
		// See above comment at client::get.
		std::this_thread::sleep_for(std::chrono::milliseconds(500));
		goto retry;
	}

	return res;
}

void args::parseArgs(int argc, char** argv) {
	enum {
		SCRIPT,
		SVRHOST,
		SCRIPTARGS
	};
	int mode = SCRIPT;
	for(int i = 0; i < argc; i++) {
		std::string arg = argv[i];
		if(arg == "-s") {
			mode = SVRHOST;
			continue;
		}
		if(arg == "-h" || arg == "--help") {
			printf("%s\n", this->HELP_STRING.c_str());
			std::exit(0);
			continue;
		}
		if(arg == "--") {
			mode = SCRIPTARGS;
			continue;
		}
		if(mode == SCRIPTARGS) {
			scriptargs.push_back(arg);
			continue;
		}
		if(mode == SCRIPT) {
			this->scriptfile = arg;
			continue;
		}
		if(mode == SVRHOST) {
			this->schema = arg;
			continue;
		}
	}
}

std::vector<Json> client::getChars() {
	std::string jsonError;
	auto res = get("/my/characters");
	if((int)res.error()) {
		printf("ERROR! %d\n", (int)res.error());
		return {};
	}
	Json parsed = Json::parse(res->body, jsonError);
	return parsed["data"].array_items();
}

void SET_CLIENT_POINTER(client *addr) {
	GLOBAL_CLIENT = addr;
}

void lua::setupCliLibs(client &cli, args &args) {
	if(!luaL_dostring(cli.lua, lualib::JSONLUA.c_str()) == LUA_OK) {
		luaL_error(cli.lua, "setupCliLibs@JSONLUA: %s\n", lua_tostring(cli.lua, -1));
	}
	luabridge::getGlobalNamespace(cli.lua)
		.beginNamespace("arti", luabridge::allowOverridingMethods | luabridge::extensibleClass)
			.addFunction("str_get", lget)
			.addFunction("str_post", lpost)
			.addFunction("get", lget) // placeholder function
			.addFunction("post", lpost) // placeholder function
			.addFunction("sleep", lsleep)
			.addVariable("args", args.scriptargs)
		.endNamespace();
	if(!luaL_dostring(cli.lua, lualib::ARTIFACTLIB.c_str()) == LUA_OK) {
		luaL_error(cli.lua, "setupCliLibs@ARTIFACTLIB: %s\n", lua_tostring(cli.lua, -1));
	}
}

std::string lua::lget(std::string apiPath, std::string apiParams) {
	std::string jsonError;
	std::string ret;
	auto res = GLOBAL_CLIENT->get(apiPath, Json::parse(apiParams, jsonError));
	if(res.error() == httplib::Error::Success) {
		ret = res->body;
		if(ret.empty()) {
			ret = format("{\"status\":\"%d\"}", res->status);
			return ret;
		}
		ret.pop_back();
		ret.append(format(",\"status\":\"%d\"", res->status));
		ret.append("}");
	} else {
		ret = "{\"status\":\"500\"}";
	}
	return ret;
}

std::string lua::lpost(std::string apiPath, std::string apiParams) {
	std::string jsonError;
	std::string ret;
	auto res = GLOBAL_CLIENT->post(apiPath, Json::parse(apiParams, jsonError));
	if(res.error() == httplib::Error::Success) {
		ret = res->body;
		if(ret.empty()) {
			ret = format("{\"status\":\"%d\"}", res->status);
			return ret;
		}
		ret.pop_back();
		ret.append(format(",\"status\":\"%d\"", res->status));
		ret.append("}");
	} else {
		ret = "{\"status\":\"500\"}";
	}

	return ret;
}

void lua::lsleep(float seconds) {
	std::this_thread::sleep_for(std::chrono::milliseconds((int)(seconds*1000)));
}

#pragma GCC diagnostic ignored "-Wformat-security"
template<typename ... Args>
std::string format(const std::string &format, Args ...args) {
    int size_s = std::snprintf( nullptr, 0, format.c_str(), args ... ) + 1; // Extra space for '\0'
    if( size_s <= 0 ){ throw std::runtime_error( "Error during formatting." ); }
    auto size = static_cast<size_t>( size_s );
    std::unique_ptr<char[]> buf( new char[ size ] );
    std::snprintf( buf.get(), size, format.c_str(), args ... );
    return std::string( buf.get(), buf.get() + size - 1 ); // We don't want the '\0' inside
}
