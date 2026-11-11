extends Node

signal echoes_changed(total: int)

const SAVE_PATH: String = "user://meta_progression.cfg"
const SAVE_SECTION: String = "meta_progression"
const SAVE_VERSION: int = 1

# Echo rewards are intentionally simple and transparent:
# each completed wave is worth a small amount, and each boss killed is worth
# more. Starting and immediately abandoning a run awards zero because no wave
# has actually been completed yet.
const ECHOES_PER_WAVE: int = 1
const ECHOES_PER_BOSS: int = 5

var echoes: int = 0


func _ready() -> void:
	load_progress()


func load_progress() -> void:
	var save_file := ConfigFile.new()
	var error: Error = save_file.load(SAVE_PATH)

	if error == OK:
		echoes = maxi(int(save_file.get_value(SAVE_SECTION, "echoes", 0)), 0)
	else:
		echoes = 0
		if error != ERR_FILE_NOT_FOUND:
			push_warning("Could not load meta progression save: %s" % error_string(error))


func save_progress() -> void:
	var save_file := ConfigFile.new()
	save_file.set_value(SAVE_SECTION, "version", SAVE_VERSION)
	save_file.set_value(SAVE_SECTION, "echoes", echoes)

	var error: Error = save_file.save(SAVE_PATH)
	if error != OK:
		push_error("Could not save meta progression: %s" % error_string(error))


func add_echoes(amount: int) -> void:
	if amount <= 0:
		return

	echoes += amount
	save_progress()
	echoes_changed.emit(echoes)


func award_run_echoes(waves_completed: int, bosses_killed: int) -> int:
	var earned: int = (
		maxi(waves_completed, 0) * ECHOES_PER_WAVE
		+ maxi(bosses_killed, 0) * ECHOES_PER_BOSS
	)

	add_echoes(earned)
	return earned
