class_name PollinationsBase
extends Node

## Shared plumbing for the Pollinations generation nodes: key resolution,
## JSON/binary HTTP requests, and error reporting. Every request method is a
## coroutine: call it with `await`.

const GENERATION_URL := "https://gen.pollinations.ai"

signal failed(message: String)

## Development API key override. Leave empty to use the Pollinations autoload
## (device token, api_key, POLLINATIONS_API_KEY env var, or project setting).
var api_key: String = ""

## Set by PollinationsAuth on the autoload, or assign a player token here.
var device_token: String = ""

var _http: HTTPRequest

func _ready() -> void:
	_http = HTTPRequest.new()
	add_child(_http)

func resolve_key() -> String:
	if device_token != "":
		return device_token
	if api_key != "":
		return api_key
	var autoload := get_node_or_null("/root/Pollinations")
	if autoload != null and autoload.has_method("resolve_key"):
		var shared: String = autoload.resolve_key()
		if shared != "":
			return shared
	return ""

func _request_json(method: int, url: String, body: Dictionary, token: String) -> Dictionary:
	var headers := PackedStringArray(["Content-Type: application/json", "Accept: application/json"])
	if token != "":
		headers.append("Authorization: Bearer " + token)
	var err := OK
	if method == HTTPClient.METHOD_POST:
		err = _http.request(url, headers, method, JSON.stringify(body))
	else:
		err = _http.request(url, headers)
	if err != OK:
		return _failure(0, "The HTTP request could not start (error %d)." % err)
	var result: Array = await _http.request_completed
	if result[0] != HTTPRequest.RESULT_SUCCESS:
		return _failure(0, "The request to Pollinations failed (network error %d)." % result[0])
	var status: int = result[1]
	var text: String = result[3].get_string_from_utf8()
	var parsed: Variant = JSON.parse_string(text) if text != "" else null
	if status < 200 or status >= 300:
		return _failure(status, _error_message(parsed, status))
	return {"ok": true, "status": status, "json": parsed, "text": text}

func _request_bytes(method: int, url: String, body: Dictionary, token: String) -> Dictionary:
	var headers := PackedStringArray(["Content-Type: application/json"])
	if token != "":
		headers.append("Authorization: Bearer " + token)
	var err := _http.request(url, headers, method, JSON.stringify(body))
	if err != OK:
		return _failure(0, "The HTTP request could not start (error %d)." % err)
	var result: Array = await _http.request_completed
	if result[0] != HTTPRequest.RESULT_SUCCESS:
		return _failure(0, "The request to Pollinations failed (network error %d)." % result[0])
	var status: int = result[1]
	if status < 200 or status >= 300:
		var parsed: Variant = JSON.parse_string(result[3].get_string_from_utf8())
		return _failure(status, _error_message(parsed, status))
	return {"ok": true, "status": status, "bytes": result[3]}

func _download_bytes(url: String, token: String) -> PackedByteArray:
	var headers := PackedStringArray([])
	if token != "":
		headers.append("Authorization: Bearer " + token)
	var err := _http.request(url, headers)
	if err != OK:
		failed.emit("The image download could not start (error %d)." % err)
		return PackedByteArray()
	var result: Array = await _http.request_completed
	if result[0] != HTTPRequest.RESULT_SUCCESS or result[1] < 200 or result[1] >= 300:
		failed.emit("The image download failed (HTTP %d)." % result[1])
		return PackedByteArray()
	return result[3]

func _failure(status: int, message: String) -> Dictionary:
	failed.emit(message)
	return {"ok": false, "status": status, "message": message}

func _error_message(parsed: Variant, status: int) -> String:
	if parsed is Dictionary:
		var error_obj: Variant = parsed.get("error", null)
		if error_obj is Dictionary and error_obj.has("message"):
			return str(error_obj["message"])
	return "Pollinations request failed (HTTP %d)." % status
