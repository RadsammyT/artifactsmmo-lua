#include "cliClient.h"
#include <climits>
#include <exception>
#include <iostream>
#include <optional>
#include <string>

httplib::Result client::get(std::string apiPath, Json apiParams) {
	auto res = httpCli.Get("/get", {
		{"api-path", apiPath},
		{"api-params", apiParams.dump()}
	});
	return res;
}

httplib::Result client::post(std::string apiPath, Json apiParams) {
	auto res = httpCli.Post("/post", {
		{"api-path", apiPath}
	}, apiParams.dump(), "application/json");
	return res;
}

std::vector<Json> client::getChars() {
	std::string jsonError;
	auto res = get("/my/characters");
	Json parsed = Json::parse(res->body, jsonError);
	return parsed["data"].array_items();
}

std::optional<int> input::readInt(int min = INT_MIN, int max = INT_MAX) {
	for(;;) {
		std::string line;
		std::getline(std::cin, line);
		try {
			int x = std::stoi(line);
			if(x >= min && x < max)
				return x;
		} catch(std::exception& e) {
			
		}
	}
}

Json lua::Table2Json(luabridge::LuaRef &ref) {
	if(!ref.isTable()) {
		return Json{};
	}
	std::vector<std::string> keys;
	Json json;
	for(int i = 1;; i++) {
		if(!ref[i].isString()) break;
		keys.push_back(ref[i]);
	}
	for(std::string i: keys) {
		json[i] = ref[i].tostring();
	}
	return json;
}
