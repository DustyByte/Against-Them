extends Resource
class_name GameSettings

@export var ui_sfx: bool = true
@export var game_world_sfx: bool = true
@export var is_heptic_feedback_enabled: bool = true
## Locale code of the chosen game language (see SettingsManager.LANGUAGES).
@export var language: String = "en"
