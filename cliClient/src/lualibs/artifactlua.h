#include <string>
namespace lualib {
	const std::string ARTIFACTLIB = R"(
		function arti:post(path, params)
			return json.parse(self.str_post(path, json.stringify(params)))
		end
		function arti:get(path, params)
			return json.parse(self.str_get(path, json.stringify(params)))
		end
	)";
}
