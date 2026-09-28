extends Node

## Autoload singleton "Pollinations": shared key resolution and live model lists.
##
## Development key resolution order: PollinationsAuth device token, then
## Pollinations.api_key set in code, then the POLLINATIONS_API_KEY environment
## variable, then the "pollinations/dev_api_key" project setting. Keys are kept
## in memory only and are never serialized into scenes or builds.
##
## For a shipped game, authorize each player at runtime with the
## PollinationsAuth device flow so they pay with their own Pollen.

const GENERATION_URL := "https://gen.pollinations.ai"

var api_key: String = ""
var device_token: String = ""

func resolve_key() -> String:
	if device_token != "":
		return device_token
	if api_key != "":
		return api_key
	var env := OS.get_environment("POLLINATIONS_API_KEY")
	if env != "":
		return env
	return str(ProjectSettings.get_setting("pollinations/dev_api_key", ""))

## Fetches the live model list for a modality: "text", "image", or "audio".
func fetch_models(modality: String) -> Array:
	var http := HTTPRequest.new()
	add_child(http)
	http.request(GENERATION_URL + "/" + modality + "/models", PackedStringArray(["Accept: application/json"]))
	var result: Array = await http.request_completed
	http.queue_free()
	if result[0] != HTTPRequest.RESULT_SUCCESS or result[1] < 200 or result[1] >= 300:
		push_error("Pollinations: could not load the %s model list (HTTP %d)" % [modality, result[1]])
		return []
	var parsed: Variant = JSON.parse_string(result[3].get_string_from_utf8())
	if parsed is Array:
		return parsed
	return []
