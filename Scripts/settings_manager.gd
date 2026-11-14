extends Node

const SETTINGS_PATH := "user://settings.tres"

## Languages offered in Settings. To add one: add its translations, then add a
## line here — `native` is shown big (in its own script), `english` underneath.
const LANGUAGES: Array[Dictionary] = [
	{"code": "en", "native": "English", "english": "English"},
]

var settings: GameSettings


func _ready() -> void:
	load_settings()
	apply_language()


func load_settings() -> void:
	if ResourceLoader.exists(SETTINGS_PATH):
		settings = load(SETTINGS_PATH)
	else:
		settings = GameSettings.new()
		save_settings()


func save_settings() -> void:
	ResourceSaver.save(settings, SETTINGS_PATH)


## Switches the game to the saved language, falling back to English when the
## saved one is no longer offered.
func apply_language() -> void:
	var known := LANGUAGES.any(func(l): return l.code == settings.language)
	if not known:
		settings.language = "en"
	TranslationServer.set_locale(settings.language)


func set_language(code: String) -> void:
	settings.language = code
	apply_language()
	save_settings()
