extends Resource
class_name GameSettings

@export var music: bool = true
@export var ui_sfx: bool = true
@export var game_world_sfx: bool = true
@export var is_heptic_feedback_enabled: bool = true
## Locale code of the game language (see SettingsManager.LANGUAGES).
@export var language: String = "en"
## True once the player picks a language in Settings; until then the game
## follows the device's language.
@export var language_chosen: bool = false
