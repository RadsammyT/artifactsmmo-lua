#define JSON11_IMPLEMENTATION

#include <iostream>
#include <map>
#include <vector>


#include "external/httplib.h"
#include "external/json11.hpp"
#include "cliClient.h"

using namespace json11;

int main() {
	client cli;
	std::string jsonError;
	auto chars = cli.getChars();

	printf("Character list:\n");
	for(int i = 0; i < chars.size(); i++) { 
		printf("%d) %s\n", i, chars[i]["name"].string_value().c_str());
	}
	printf("Select Character: #");
	std::string curChar = chars[input::readInt(0, chars.size()).value()]["name"].string_value();
	printf("selected: %s", curChar.c_str());
}
