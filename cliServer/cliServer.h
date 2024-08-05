#include <string>

#define CPPHTTPLIB_OPENSSL_SUPPORT
#include "external/httplib.h"

#define AUTHKEY "RAD_ARTI_AUTH"
#define AUTHMAP std::string("Bearer " + std::string(std::getenv(AUTHKEY)))
struct cliServer {
	httplib::Server server; // to send to the CLI Client(s)
	httplib::Client client; // to send to Artifact Server
	
	cliServer() : client("https://api.artifactsmmo.com") {}

	// server status of ArtifactsMMO
	std::pair<std::string, bool> getServerStatus();

	//Certify that AUTHKEY is the correct one. 
	//We use the `/my/characters` endpoint for this.
	bool certifyAuth();

	//setup the server to use for the CLI client
	void serverSetup();
};

