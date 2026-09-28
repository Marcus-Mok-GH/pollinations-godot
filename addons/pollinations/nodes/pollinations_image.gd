class_name PollinationsImage
extends "res://addons/pollinations/base.gd"

## Image generation node. `await generate(prompt)` returns a Texture2D and
## emits `completed`; failures emit `failed` and return null. Handles both
## b64_json and URL responses, PNG and JPEG.

signal completed(texture: Texture2D)

var model: String = "tongyi-mai/z-image-turbo"

func generate(prompt: String, width: int = 1024, height: int = 1024, model_override: String = "") -> Texture2D:
	# An empty key sends an anonymous request; the API answers text prompts
	# anonymously and replies 401 with a clear message for image and speech.
	var token := resolve_key()
	var body := {
		"prompt": prompt,
		"model": model_override if model_override != "" else model,
		"width": width,
		"height": height,
		"n": 1,
		"response_format": "b64_json",
	}
	var response := await _request_json(HTTPClient.METHOD_POST, GENERATION_URL + "/v1/images/generations", body, token)
	if not response.get("ok", false):
		return null
	var data: Array = response.get("json", {}).get("data", [])
	if data.is_empty():
		_failure(int(response.get("status", 0)), "Pollinations returned no image data.")
		return null
	var item: Dictionary = data[0]
	var bytes := PackedByteArray()
	if item.has("b64_json") and str(item.get("b64_json", "")) != "":
		bytes = Marshalls.base64_to_raw(str(item["b64_json"]))
	elif item.has("url") and str(item.get("url", "")) != "":
		bytes = await _download_bytes(str(item["url"]), token)
	else:
		_failure(int(response.get("status", 0)), "Pollinations returned an image without bytes or a URL.")
		return null
	var texture := _decode_texture(bytes)
	if texture == null:
		_failure(int(response.get("status", 0)), "The returned image bytes could not be decoded.")
		return null
	completed.emit(texture)
	return texture

func _decode_texture(bytes: PackedByteArray) -> Texture2D:
	if bytes.is_empty():
		return null
	var image := Image.new()
	if image.load_png_from_buffer(bytes) == OK:
		return ImageTexture.create_from_image(image)
	if image.load_jpg_from_buffer(bytes) == OK:
		return ImageTexture.create_from_image(image)
	return null
