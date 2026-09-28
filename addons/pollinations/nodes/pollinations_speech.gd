class_name PollinationsSpeech
extends "res://addons/pollinations/base.gd"

## Speech generation node. `await generate(text)` returns an AudioStream and
## emits `completed`; failures emit `failed` and return null. WAV responses are
## decoded in-memory into an AudioStreamWAV; MP3 responses are returned as an
## AudioStreamMP3.

signal completed(stream: AudioStream)

var model: String = "elevenlabs/eleven-v3"
var voice: String = "alloy"

func generate(text: String, model_override: String = "", voice_override: String = "", response_format: String = "wav") -> AudioStream:
	# An empty key sends an anonymous request; the API answers text prompts
	# anonymously and replies 401 with a clear message for image and speech.
	var token := resolve_key()
	var body := {
		"model": model_override if model_override != "" else model,
		"input": text,
		"voice": voice_override if voice_override != "" else voice,
		"response_format": response_format,
	}
	var response := await _request_bytes(HTTPClient.METHOD_POST, GENERATION_URL + "/v1/audio/speech", body, token)
	if not response.get("ok", false):
		return null
	var bytes: PackedByteArray = response["bytes"]
	var stream: AudioStream = null
	if response_format == "mp3":
		stream = _bytes_to_mp3(bytes)
	else:
		stream = _bytes_to_wav(bytes)
	if stream == null:
		_failure(int(response.get("status", 0)), "The returned audio could not be decoded.")
		return null
	completed.emit(stream)
	return stream

func _bytes_to_mp3(data: PackedByteArray) -> AudioStreamMP3:
	if data.is_empty():
		return null
	var stream := AudioStreamMP3.new()
	stream.data = data
	return stream

## Parses a RIFF/WAVE file with 8-bit or 16-bit PCM, mono or stereo.
func _bytes_to_wav(data: PackedByteArray) -> AudioStreamWAV:
	if data.size() < 44 or data.slice(0, 4).get_string_from_ascii() != "RIFF" or data.slice(8, 12).get_string_from_ascii() != "WAVE":
		return null
	var pos := 12
	var audio_format := 1
	var channels := 1
	var sample_rate := 44100
	var bits := 16
	var pcm := PackedByteArray()
	while pos + 8 <= data.size():
		var id := data.slice(pos, pos + 4).get_string_from_ascii()
		var size: int = data.decode_u32(pos + 4)
		var chunk_start := pos + 8
		if id == "fmt ":
			audio_format = data.decode_u16(chunk_start)
			channels = data.decode_u16(chunk_start + 2)
			sample_rate = data.decode_u32(chunk_start + 4)
			bits = data.decode_u16(chunk_start + 14)
		elif id == "data":
			var chunk_end: int = mini(chunk_start + size, data.size())
			pcm = data.slice(chunk_start, chunk_end)
		pos = chunk_start + size + (size % 2)
	if audio_format != 1 or (bits != 8 and bits != 16) or channels < 1 or channels > 2 or pcm.is_empty():
		return null
	var stream := AudioStreamWAV.new()
	if bits == 16:
		stream.format = AudioStreamWAV.FORMAT_16_BITS
	else:
		stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = sample_rate
	stream.stereo = channels == 2
	stream.data = pcm
	return stream
