extends Control

signal returnPressed

const ACHIEVEMENT_CARD_SCENE: PackedScene = preload("res://Scenes/HUD/achievement_card.tscn")
const AchievementData = preload("res://Scripts/achievement_data.gd")
const HEADER_FONT: FontFile = preload("res://Resources/Copperplate.otf")

@onready var _card_list: VBoxContainer = $MarginContainer/VBoxContainer/ListMargin/ScrollContainer/CardList
@onready var _return_button: Panel = $MarginContainer/VBoxContainer/ReturnMargin/ReturnButton

func _ready() -> void:
	_return_button.gui_input.connect(_on_return_gui_input)
	_build_cards()


func _build_cards() -> void:
	for category: String in AchievementData.CATEGORIES:
		_card_list.add_child(_make_category_header(category))

		for achievement: Dictionary in AchievementData.ACHIEVEMENTS:
			if achievement["category"] != category:
				continue

			var card := ACHIEVEMENT_CARD_SCENE.instantiate()
			_card_list.add_child(card)
			card.setup(
				achievement["id"],
				achievement["title"],
				achievement["type"] == AchievementData.TYPE_LIFETIME,
				AchievementManager.get_progress(achievement["id"]),
				achievement["target"],
				achievement["reward"],
				AchievementManager.is_claimed(achievement["id"])
			)
			card.claim_requested.connect(_on_claim_requested.bind(card))


func _make_category_header(category: String) -> Control:
	var header := Label.new()
	header.text = category.to_upper()
	header.add_theme_font_override("font", HEADER_FONT)
	header.add_theme_font_size_override("font_size", 26)
	header.add_theme_color_override("font_color", Color(0.95, 0.8, 0.42, 1))

	# Extra space above each heading so categories read as separate groups.
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_left", 6)
	margin.mouse_filter = Control.MOUSE_FILTER_PASS
	margin.add_child(header)
	return margin


func _on_claim_requested(achievement_id: String, card: Node) -> void:
	# AchievementManager checks it is completed and unclaimed, saves the claim,
	# and adds the reward to the player's Echoes.
	if AchievementManager.claim(achievement_id) > 0:
		_play_ui_sfx()
		card.set_claimed(true)


func _on_return_gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.is_pressed():
		_play_ui_sfx()
		returnPressed.emit()


func _play_ui_sfx() -> void:
	if global.SFX_TYPES_PERM["ui"]:
		var asp := AudioStreamPlayer.new()
		asp.stream = preload("res://Assets/SFX/UI.mp3")
		asp.pitch_scale = randf_range(0.7, 1.3)
		# Parented to the global autoload so the sound survives this screen being freed on return.
		global.add_child(asp)
		asp.play()
		asp.finished.connect(asp.queue_free)
