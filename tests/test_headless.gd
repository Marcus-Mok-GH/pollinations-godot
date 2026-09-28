extends Node

## Headless verification: live model lists and live text generation, plus
## offline checks for the device-flow guard, the WAV parser, and the
## b64_json/PNG decode path. Run with:
##   godot --headless --path . res://tests/test_headless.tscn

var failures := 0

func _ready() -> void:
	await _run_tests()
	get_tree().quit(1 if failures > 0 else 0)

func _run_tests() -> void:
	_autoload_check()
	await _models_check("text")
	await _models_check("image")
	await _models_check("audio")
	_auth_guard_check()
	_wav_check()
	_png_check()
	if _has_key():
		await _live_text_check()
		await _live_image_check()
		await _live_speech_check()
	else:
		await _text_check()
		await _image_no_key_check()
	print("RESULT: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])

func _has_key() -> bool:
	var autoload := get_node_or_null("/root/Pollinations")
	return autoload != null and autoload.resolve_key() != ""

func check(condition: bool, name: String) -> void:
	print("[%s] %s" % ["ok" if condition else "FAIL", name])
	if not condition:
		failures += 1

func _autoload_check() -> void:
	var autoload := get_node_or_null("/root/Pollinations")
	check(autoload != null, "autoload Pollinations registered")
	if not _has_key():
		check(autoload != null and autoload.resolve_key() == "", "resolve_key empty without credentials")
	else:
		check(true, "resolve_key finds a credential from the environment")

func _models_check(modality: String) -> void:
	var models: Array = await get_node("/root/Pollinations").fetch_models(modality)
	check(models.size() > 0 and models[0] is Dictionary and str(models[0].get("name", "")) != "", "live %s model list" % modality)

func _text_check() -> void:
	var node := PollinationsText.new()
	add_child(node)
	var failures_seen: Array = []
	node.failed.connect(func(message): failures_seen.append(message))
	var text: String = await node.generate("Answer with one word: yes")
	if text == "" and failures_seen.size() > 0 and str(failures_seen[0]).begins_with("A valid API key is required"):
		print("[skip] live text generation (no API key in this environment)")
		node.queue_free()
		return
	if text == "":
		print("  text failure message: " + (str(failures_seen[0]) if failures_seen.size() > 0 else "(none)"))
	check(text != "", "live text generation via /v1/chat/completions")
	node.queue_free()

func _auth_guard_check() -> void:
	var auth := PollinationsAuth.new()
	add_child(auth)
	var result: Dictionary = await auth.authorize("not-a-publishable-key")
	check(result.get("granted", true) == false and str(result.get("error", "")) == "invalid_app_key", "device flow rejects non-pk App Key")
	auth.queue_free()

func _image_no_key_check() -> void:
	var node := PollinationsImage.new()
	add_child(node)
	var failed_messages: Array = []
	node.failed.connect(func(message): failed_messages.append(message))
	var texture: Texture2D = await node.generate("test", 64, 64)
	check(texture == null and failed_messages.size() == 1, "image node fails cleanly without a key")
	node.queue_free()

func _make_wav() -> PackedByteArray:
	var num_samples := 4410
	var pcm := PackedByteArray()
	pcm.resize(num_samples * 4)
	for i in num_samples:
		var value := int(10000.0 * sin(i * 0.05))
		pcm.encode_s16(i * 4, value)
		pcm.encode_s16(i * 4 + 2, value)
	var file := PackedByteArray()
	file.append_array("RIFF".to_ascii_buffer())
	file.append_array(_u32_bytes(36 + pcm.size()))
	file.append_array("WAVE".to_ascii_buffer())
	file.append_array("fmt ".to_ascii_buffer())
	file.append_array(_u32_bytes(16))
	file.append_array(_u16_bytes(1))
	file.append_array(_u16_bytes(2))
	file.append_array(_u32_bytes(44100))
	file.append_array(_u32_bytes(176400))
	file.append_array(_u16_bytes(4))
	file.append_array(_u16_bytes(16))
	file.append_array("data".to_ascii_buffer())
	file.append_array(_u32_bytes(pcm.size()))
	file.append_array(pcm)
	return file

func _u16_bytes(value: int) -> PackedByteArray:
	var bytes := PackedByteArray()
	bytes.resize(2)
	bytes.encode_u16(0, value)
	return bytes

func _u32_bytes(value: int) -> PackedByteArray:
	var bytes := PackedByteArray()
	bytes.resize(4)
	bytes.encode_u32(0, value)
	return bytes

func _wav_check() -> void:
	var speech := PollinationsSpeech.new()
	add_child(speech)
	var stream: AudioStreamWAV = speech._bytes_to_wav(_make_wav())
	check(stream != null, "WAV parser builds a stream")
	check(stream != null and stream.mix_rate == 44100, "WAV parser reads sample rate")
	check(stream != null and stream.stereo, "WAV parser reads channels")
	check(stream != null and stream.format == AudioStreamWAV.FORMAT_16_BITS, "WAV parser reads bit depth")
	check(stream != null and stream.data.size() == 4410 * 4, "WAV parser keeps PCM data")
	speech.queue_free()

func _png_check() -> void:
	var image := Image.create(16, 16, false, Image.FORMAT_RGB8)
	image.fill(Color.RED)
	var png := image.save_png_to_buffer()
	var node := PollinationsImage.new()
	add_child(node)
	var texture: Texture2D = node._decode_texture(png)
	check(texture != null and texture.get_width() == 16, "image decode path handles PNG bytes")
	var round_trip: Texture2D = node._decode_texture(Marshalls.base64_to_raw(Marshalls.raw_to_base64(png)))
	check(round_trip != null and round_trip.get_height() == 16, "b64_json base64 round trip decodes")
	node.queue_free()

func _live_text_check() -> void:
	var node := PollinationsText.new()
	add_child(node)
	var text: String = await node.generate("Answer with exactly two words: pollen works")
	check(text != "", "live text generation via /v1/chat/completions (%d chars)" % text.length())
	print("  text: " + text.substr(0, 120).replace("\n", " "))
	node.queue_free()

func _live_image_check() -> void:
	var node := PollinationsImage.new()
	add_child(node)
	var texture: Texture2D = await node.generate("A tiny pixel-art garden on an alien planet", 512, 512)
	var detail := "null"
	if texture != null:
		# The model may return its native size instead of the requested one.
		detail = "%dx%d decoded from the b64_json response" % [texture.get_width(), texture.get_height()]
	check(texture != null, "live image generation via /v1/images/generations (%s)" % detail)
	node.queue_free()

func _live_speech_check() -> void:
	var node := PollinationsSpeech.new()
	add_child(node)
	var speech_failures: Array = []
	node.failed.connect(func(message): speech_failures.append(message))
	var stream: AudioStream = await node.generate("Hello from the Pollinations Godot add-on.")
	if stream == null and speech_failures.size() > 0 and str(speech_failures[0]).begins_with("Insufficient balance"):
		print("[skip] live speech generation (account balance does not cover audio)")
		node.queue_free()
		return
	var wav := stream as AudioStreamWAV
	var detail := "null"
	if wav != null:
		detail = "%d Hz %s %d bytes (%.1f s)" % [wav.mix_rate, "stereo" if wav.stereo else "mono", wav.data.size(), float(wav.data.size()) / float(wav.mix_rate) / (4 if wav.stereo else 2)]
	check(stream != null and wav != null, "live speech generation via /v1/audio/speech (RIFF parsed: %s)" % detail)
	node.queue_free()
