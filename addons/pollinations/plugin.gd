@tool
extends EditorPlugin

## Registers the Pollinations autoload singleton when the plugin is enabled.

const AUTOLOAD_NAME := "Pollinations"
const AUTOLOAD_PATH := "res://addons/pollinations/autoload/pollinations.gd"

func _enter_tree() -> void:
	if not ProjectSettings.has_setting("autoload/" + AUTOLOAD_NAME):
		add_autoload_singleton(AUTOLOAD_NAME, AUTOLOAD_PATH)

func _exit_tree() -> void:
	if ProjectSettings.has_setting("autoload/" + AUTOLOAD_NAME):
		remove_autoload_singleton(AUTOLOAD_NAME)
