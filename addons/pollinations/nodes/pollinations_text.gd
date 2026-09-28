class_name PollinationsText
extends "res://addons/pollinations/base.gd"

## Text generation node. `await generate(prompt)` returns the answer text and
## emits `completed`; failures emit `failed` and return an empty string.

signal completed(text: String, model: String)

var model: String = "openai/gpt-5.4-nano"

func generate(prompt: String, model_override: String = "", system: String = "") -> String:
	# An empty key sends an anonymous request; the API answers text prompts
	# anonymously and replies 401 with a clear message for image and speech.
	var token := resolve_key()
	var messages: Array = []
	if system != "":
		messages.append({"role": "system", "content": system})
	messages.append({"role": "user", "content": prompt})
	var body := {
		"model": model_override if model_override != "" else model,
		"messages": messages,
	}
	var response := await _request_json(HTTPClient.METHOD_POST, GENERATION_URL + "/v1/chat/completions", body, token)
	if not response.get("ok", false):
		return ""
	var parsed: Dictionary = response.get("json", {})
	var choices: Array = parsed.get("choices", [])
	if choices.is_empty():
		_failure(int(response.get("status", 0)), "Pollinations returned no text choices.")
		return ""
	var content: String = str(choices[0].get("message", {}).get("content", ""))
	completed.emit(content, str(parsed.get("model", model)))
	return content
