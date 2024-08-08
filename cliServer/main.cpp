#include <iostream>
#include <cstdlib>
#include <map>
#include <string>
#include <thread>
#include <chrono>

#include "cliServer.h"

#define JSON11_IMPLEMENTATION
#include "external/json11.hpp"

#include "external/httplib.h"

using namespace json11;
using namespace std::chrono_literals;

int main() {
	cliServer server;
	char* authKey = std::getenv(AUTHKEY);
	if(authKey == NULL) {
		printf("No key found in AUTHKEY: " AUTHKEY "\n");
		return 1;
	} else {
		auto status = server.getServerStatus();
		printf("%s\n", status.first.c_str());
		if(!status.second) {
			printf("Server returned unacceptable result: %s\n.", status.first.c_str());
			return 1;
		}
		if(!server.certifyAuth()) return 1;
	}

	server.serverSetup();
	return 0;
}

std::pair<std::string, bool> cliServer::getServerStatus() {
	auto res = client.Get("/");
	if(res->status != httplib::OK_200) {
		return std::pair(std::to_string(res->status), false);
	}
	return std::pair(res->body, true);
}

bool cliServer::certifyAuth() {
	auto res = client.Get("/my/characters", {
		{"Accept", "application/json"},
		{"Authorization", std::string("Bearer " + std::string(std::getenv(AUTHKEY)))}
	});
	if(res->status != httplib::OK_200) return false;
	return true;
}

std::string truncateIfLarge(std::string in, int code) {
	if(in.size() >= 80 && code == httplib::OK_200) {
		return "TRUNCATED";
	}
	return in;
}

void cliServer::serverSetup() {
	// api-path: string - the path to forward to the api
	// api-params: string(json) - the URL params to forward to the api URL
	// 			 - an object with key as the param and val to pass to param 
	server.Get("/get", [this](const httplib::Request& req, httplib::Response& res) {
		std::string jsonError;
		auto path = req.get_header_value("api-path");
		std::map<std::string, Json> params = Json::parse(req.get_header_value("api-params"), jsonError).object_items();
		if(!params.empty()) {
			path.append("?");
			for(auto i: params) {
				path.append(i.first.c_str());
				path.append("=");
				path.append(i.second.string_value().c_str());
				path.push_back('&');
			}
			path.pop_back();
		}
		auto result = client.Get(path, {
			{"Accept", "application/json"},
			{"Authorization", AUTHMAP}
		});
		if(result.error() == httplib::Error::Success) {
			res.status = result->status;
			res.body = result->body;
		} else {
			Json error = Json::object {
				{"error", "cliServer: HTTPLIB ERROR, ENUM #" + std::to_string((int)result.error())}
			};
			res.status = httplib::InternalServerError_500;
			res.body = error.dump();
		}
		printf("got get req: %s\n", path.c_str());
		printf("got status %d\n", res.status);
		printf("got status %d\n", res.status);
		printf("of body %s\n", truncateIfLarge(res.body, res.status).c_str());
		printf("---------------------------------\n");
	});

	// api-path: string - the path to forward to the api 
	// api-body: string - the body to forward to the api
	server.Post("/post", [this](const httplib::Request& req, httplib::Response& res){
		std::string jsonError;
		auto path = req.get_header_value("api-path");
		auto result = client.Post(path,
				{
					{"Authorization", AUTHMAP}
				},
				req.body, "application/json");
		if(result.error() == httplib::Error::Success) {
			res.status = result->status;
			res.body = result->body;
		} else {
			Json error = Json::object {
				{"error", "cliServer: HTTPLIB ERROR, ENUM #" + std::to_string((int)result.error())}
			};
			printf("ERROR: HTTPLIB ENUM ERROR %d\n", ((int)result.error()));
			res.status = httplib::InternalServerError_500;
			res.body = error.dump();
		}
		printf("got post req: %s\n", path.c_str());
		printf("of body: %s\n", req.body.c_str());
		printf("got status %d\n", res.status);
		printf("of body %s\n", truncateIfLarge(res.body, res.status).c_str());
		printf("---------------------------------\n");
	});
	server.listen("127.0.0.1", 6969);
}
