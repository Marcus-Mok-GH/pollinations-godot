# Pollinations for Godot

Text, image, and speech generation nodes for [Pollinations](https://pollinations.ai) in Godot 4,
with live model lists and player-funded device-flow authorization. No dependencies, no GDExtension,
no build step — pure GDScript (typed, async, `await`-first). Submitted for Pollinations quest #15579.

## Features

- **`PollinationsText`** — OpenAI-compatible chat completions (`POST /v1/chat/completions`)
- **`PollinationsImage`** — `POST /v1/images/generations`; decodes `b64_json` **or** URL responses into a ready-to-use `Texture2D` (PNG and JPEG)
- **`PollinationsSpeech`** — `POST /v1/audio/speech`; parses the RIFF/WAVE response in-memory into a playable `AudioStreamWAV` (8/16-bit, mono/stereo), or wraps MP3 in an `AudioStreamMP3`
- **`PollinationsAuth`** — BYOP device flow (`enter.pollinations.ai/api/device/code` → the player approves at `enter.pollinations.ai/device` → polled `/api/device/token`) so players pay with their own Pollen; handles `authorization_pending`, `slow_down`, `access_denied`, `expired_token`
- **`Pollinations` autoload** — shared key resolution + live model lists (`fetch_models("text" / "image" / "audio")`)
- Every node: `await`-able, signals (`completed` / `failed`), provider error messages surfaced from API responses

## Install

1. Copy `addons/pollinations/` into your project (or clone this repo and open it as a project).
2. **Project Settings → Plugins** → enable **Pollinations for Godot**. This registers the `Pollinations` autoload automatically.
3. Development key (any one):
   - set `POLLINATIONS_API_KEY` in the environment, or
   - add `pollinations/dev_api_key` in **Project Settings** (keep it out of shipped builds), or
   - call `await $PollinationsAuth.authorize("pk_...")` and set the returned token on the autoload's `device_token`.

Keys are kept in memory only — never serialized into scenes or builds. Generation requires a key;
without one, requests surface the provider's own "A valid API key is required" message via the
`failed` signal, which makes the reason obvious in the editor.

## Quick start

```gdscript
# Scene nodes, or create them from code:
var text_node := PollinationsText.new()
add_child(text_node)

var sentence: String = await text_node.generate("Give my NPC one cheerful sentence.")

var image_node := PollinationsImage.new()
add_child(image_node)
var texture: Texture2D = await image_node.generate(sentence, 512, 512)
$Sprite2D.texture = texture

var speech_node := PollinationsSpeech.new()
add_child(speech_node)
var stream: AudioStream = await speech_node.generate(sentence)
$AudioStreamPlayer.stream = stream
$AudioStreamPlayer.play()
```

Any model from the live lists works: `node.model = "openai/gpt-5.4-nano"` (default), or pass a
model override per call. Fetch the catalog live:

```gdscript
var text_models: Array = await Pollinations.fetch_models("text")   # also "image", "audio"
```

## Player-funded device flow

```gdscript
var result: Dictionary = await $PollinationsAuth.authorize("pk_your_app_key")
# the code_received signal shows user_code + verification_uri in your UI meanwhile
if result["granted"]:
    Pollinations.device_token = result["access_token"]  # in memory only
```

## Short demo (example scene)

Open `example/example.tscn` and press **F5** (or call `run_demo()`):

1. Console: `[Pollinations] Generating text...`, then a one-sentence scene description
2. The `Sprite2D` fills with a generated 512x512 image of the prompt
3. The sentence is spoken through the `AudioStreamPlayer`
4. Console: `[Pollinations] Done - the sentence was also spoken.`

The example scene adds the generation nodes at runtime, so it carries no keys and stays
copy-and-customize friendly.

## Verification (headless, reproducible)

The whole addon is verified in the real engine, no editor needed:

```bash
godot --headless --path . res://tests/test_headless.tscn
```

Checks (Godot 4.4.1): autoload registration, key resolution, live `text`/`image`/`audio`
model lists, the device-flow `pk_` guard, clean keyless failure with the provider's message
surfaced, WAV parsing (44.1 kHz stereo PCM16), the PNG + base64 image decode path, and the
example scene runs headless with zero script errors. Live generation checks use
`POLLINATIONS_API_KEY` when the environment has one; without a key they are skipped
explicitly rather than counted as passing.

## License

MIT
