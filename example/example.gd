extends Node2D

## End-to-end demo: one prompt drives text, image, and speech generation.
## The generation nodes are added at runtime, so the example scene itself
## carries no keys.

const PROMPT := "A tiny pixel-art garden on an alien planet"

@onready var sprite: Sprite2D = $Sprite
@onready var status: Label = $StatusLabel
@onready var player: AudioStreamPlayer = $AudioPlayer

func _ready() -> void:
	run_demo()

func run_demo() -> void:
	var text_node := PollinationsText.new()
	var image_node := PollinationsImage.new()
	var speech_node := PollinationsSpeech.new()
	add_child(text_node)
	add_child(image_node)
	add_child(speech_node)

	_set_status("Generating text...")
	var sentence: String = await text_node.generate("Describe this scene in one cheerful sentence: " + PROMPT)
	if sentence == "":
		_set_status("Text generation failed (check the key).")
		return
	_set_status(sentence)

	_set_status("Generating image...")
	var texture: Texture2D = await image_node.generate(PROMPT, 512, 512)
	if texture != null:
		sprite.texture = texture

	_set_status("Generating speech...")
	var stream: AudioStream = await speech_node.generate(sentence)
	if stream != null:
		player.stream = stream
		player.play()

	_set_status("Done - the sentence was also spoken.")

func _set_status(message: String) -> void:
	status.text = message
	print("[Pollinations] " + message)
