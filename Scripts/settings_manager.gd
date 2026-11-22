extends Node

const SETTINGS_PATH := "user://settings.tres"

## Languages offered in Settings. To add one: add its column to
## Resources/Translations/strings.csv, then add a line here — `native` is shown
## big (in its own script), `english` underneath.
const LANGUAGES: Array[Dictionary] = [
	{"code": "en", "native": "English", "english": "English"},
	{"code": "ja", "native": "日本語", "english": "Japanese"},
]
## Copperplate has no Japanese: M PLUS 1 (cut down to the characters the
## translation uses, plus all kana) draws them. Its weight, 100-900.
const JAPANESE_FONT: FontFile = preload("res://Resources/MPLUS1-Japanese.ttf")
const JAPANESE_WEIGHT: int = 500
## Built from Resources/Translations/strings.csv (keys are the English text, so
## labels translate themselves). Registered here rather than in the project
## settings, so they always ship with the game.
const TRANSLATIONS: Array[Translation] = [
	preload("res://Resources/Translations/strings.en.translation"),
	preload("res://Resources/Translations/strings.ja.translation"),
]

var settings: GameSettings
var _fonts_with_fallback: Array[Font] = []   # held so the shared font resources keep it


func _ready() -> void:
	load_settings()
	for translation in TRANSLATIONS:
		TranslationServer.add_translation(translation)
	_add_japanese_fallback()
	apply_language()


## Loads the saved settings. A missing or unreadable file (e.g. one cut short
## when the device lost power mid-save) falls back to the defaults instead of
## leaving the game without settings.
func load_settings() -> void:
	var loaded: Resource = null
	if ResourceLoader.exists(SETTINGS_PATH):
		loaded = ResourceLoader.load(SETTINGS_PATH, "", ResourceLoader.CACHE_MODE_IGNORE)
	if loaded is GameSettings:
		settings = loaded
	else:
		if loaded == null and ResourceLoader.exists(SETTINGS_PATH):
			push_warning("Settings file was unreadable; starting from the default settings.")
		settings = GameSettings.new()
		save_settings()


func save_settings() -> void:
	ResourceSaver.save(settings, SETTINGS_PATH)


## The game's language: the player's pick if they made one in Settings,
## otherwise the device's language if it is offered, otherwise English.
func apply_language() -> void:
	var code: String = settings.language if settings.language_chosen else OS.get_locale_language()
	if not LANGUAGES.any(func(l): return l.code == code):
		code = "en"
	settings.language = code
	TranslationServer.set_locale(code)


## Picked in Settings: from now on the game stays in this language.
func set_language(code: String) -> void:
	settings.language = code
	settings.language_chosen = true
	apply_language()
	save_settings()


## Every font the UI draws with falls back to M PLUS 1 for characters it lacks
## (Japanese). The fonts are shared resources, so this reaches every scene.
func _add_japanese_fallback() -> void:
	var japanese := FontVariation.new()
	japanese.base_font = JAPANESE_FONT
	japanese.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): JAPANESE_WEIGHT}
	for font: Font in [load("res://Resources/Copperplate.otf"), ThemeDB.fallback_font]:
		if font == null:
			continue
		var fallbacks: Array[Font] = font.fallbacks
		fallbacks.append(japanese)
		font.fallbacks = fallbacks
		_fonts_with_fallback.append(font)
