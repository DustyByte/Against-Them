extends Node

const SETTINGS_PATH := "user://settings.tres"

var settings: GameSettings


func _ready() -> void:
	load_settings()


func load_settings() -> void:
	if ResourceLoader.exists(SETTINGS_PATH):
		settings = load(SETTINGS_PATH)
	else:
		settings = GameSettings.new()
		save_settings()


func save_settings() -> void:
	ResourceSaver.save(settings, SETTINGS_PATH)
