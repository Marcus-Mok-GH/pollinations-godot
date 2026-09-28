class_name PollinationsAuth
extends Node

## Player-funded device flow (BYOP). Call `await authorize(app_key)` with a
## publishable pk_ App Key; show `code_received` in your UI so the player can
## approve at enter.pollinations.ai/device and pay with their own Pollen.
## Handles authorization_pending, slow_down, access_denied, and expired_token.
## The resulting token is kept in memory only (set it on the Pollinations
## autoload's device_token, or on each node's device_token).

signal code_received(user_code: String, verification_uri: String)
signal authorized(access_token: String)
signal denied(error: String)

const AUTH_URL := "https://enter.pollinations.ai"

func authorize(app_key: String) -> Dictionary:
	if not app_key.begins_with("pk_"):
		push_error("Pollinations: the device flow requires a publishable App Key starting with pk_.")
		denied.emit("invalid_app_key")
		return {"granted": false, "error": "invalid_app_key"}
	var http := HTTPRequest.new()
	add_child(http)
	var code := await _post_json(http, AUTH_URL + "/api/device/code", {"client_id": app_key})
	if code.get("ok", false) == false:
		http.queue_free()
		denied.emit(str(code.get("error", "device_code_failed")))
		return {"granted": false, "error": str(code.get("error", "device_code_failed"))}
	var parsed: Dictionary = code.get("json", {})
	var device_code := str(parsed.get("device_code", ""))
	if device_code == "":
		http.queue_free()
		denied.emit("no_device_code")
		return {"granted": false, "error": "no_device_code"}
	var verification_uri := str(parsed.get("verification_uri", "/device"))
	if not verification_uri.begins_with("http"):
		verification_uri = AUTH_URL + ("/" if not verification_uri.begins_with("/") else "") + verification_uri
	var user_code := str(parsed.get("user_code", ""))
	code_received.emit(user_code, verification_uri)
	var interval := 5
	if int(parsed.get("interval", 5)) > 0:
		interval = int(parsed.get("interval", 5))
	var expires_at := Time.get_unix_time_from_system() + float(parsed.get("expires_in", 600))
	while Time.get_unix_time_from_system() < expires_at:
		await get_tree().create_timer(float(interval)).timeout
		var token := await _post_json(http, AUTH_URL + "/api/device/token", {"client_id": app_key, "device_code": device_code})
		if token.get("ok", false) == false:
			http.queue_free()
			denied.emit(str(token.get("error", "token_request_failed")))
			return {"granted": false, "error": str(token.get("error", "token_request_failed"))}
		var body: Dictionary = token.get("json", {})
		var access_token := str(body.get("access_token", ""))
		if access_token != "":
			http.queue_free()
			authorized.emit(access_token)
			return {"granted": true, "access_token": access_token}
		var error := str(body.get("error", ""))
		if error == "authorization_pending":
			continue
		elif error == "slow_down":
			interval += 5
			continue
		elif error == "access_denied" or error == "expired_token":
			http.queue_free()
			denied.emit(error)
			return {"granted": false, "error": error}
	http.queue_free()
	denied.emit("expired_token")
	return {"granted": false, "error": "expired_token"}

func _post_json(http: HTTPRequest, url: String, body: Dictionary) -> Dictionary:
	var err := http.request(url, PackedStringArray(["Content-Type: application/json", "Accept: application/json"]), HTTPClient.METHOD_POST, JSON.stringify(body))
	if err != OK:
		return {"ok": false, "error": "request_failed"}
	var result: Array = await http.request_completed
	if result[0] != HTTPRequest.RESULT_SUCCESS or result[1] < 200 or result[1] >= 300:
		return {"ok": false, "error": "http_%d" % result[1]}
	var parsed: Variant = JSON.parse_string(result[3].get_string_from_utf8())
	if parsed is Dictionary:
		return {"ok": true, "json": parsed}
	return {"ok": false, "error": "bad_response"}
