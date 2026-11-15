extends Control

signal returnPressed

const ACHIEVEMENT_CARD_SCENE: PackedScene = preload("res://Scenes/HUD/achievement_card.tscn")
const AchievementData = preload("res://Scripts/achievement_data.gd")
const HEADER_FONT: FontFile = preload("res://Resources/Copperplate.otf")

@onready var _card_list: VBoxContainer = $MarginContainer/VBoxContainer/ListMargin/ScrollContainer/CardList
@onready var _return_button: Panel = $MarginContainer/VBoxContainer/ReturnMargin/ReturnButton

func _ready() -> void:
	_return_button.gui_input.connect(_on_return_gui_input)
	for category: String in AchievementData.CATEGORIES:
		_build_queue.append(category)
		for achievement: Dictionary in AchievementData.ACHIEVEMENTS:
			if achievement["category"] == category:
				_build_queue.append(achievement)
	_build_some(FIRST_FRAME_ROWS)


## Cards are built a few at a time against a time budget per frame: with ~150
## cards, building them all at once froze the screen for a moment on phones.
## The first screenful is built right away. (The frame signal connection goes
## away by itself if the screen is closed before everything is built.)
const BUILD_BUDGET_MSEC: int = 8
const FIRST_FRAME_ROWS: int = 10
var _build_queue: Array = []   # category names (headers) and achievements, in order
var _built: int = 0

func _build_some(min_rows: int = 1) -> void:
	var start: int = Time.get_ticks_msec()
	var built_now: int = 0
	while _built < _build_queue.size():
		var item = _build_queue[_built]
		_built += 1
		built_now += 1
		if item is String:
			_card_list.add_child(_make_category_header(item))
		else:
			_add_card(item)
		if built_now >= min_rows and Time.get_ticks_msec() - start >= BUILD_BUDGET_MSEC:
			break
	if _built < _build_queue.size():
		get_tree().process_frame.connect(_build_some, CONNECT_ONE_SHOT)


func _add_card(achievement: Dictionary) -> void:
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
	if Tap.is_tap(_return_button, event):
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
