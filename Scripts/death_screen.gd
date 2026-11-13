extends Control
## Shown when Echo dies: a short run summary, revives left, and Bail Out /
## Revive. Revive spends an Anchor Shard if the player has one, otherwise it
## plays a rewarded ad. The world stays paused until the revive countdown ends.

const COUNTDOWN_FROM := 3
const COUNTDOWN_STEP := 0.8
const FONT: FontFile = preload("res://Resources/Copperplate.otf")

@onready var _dim: ColorRect = $Dim
@onready var _dialog: PanelContainer = $Center/Dialog
@onready var _wave_value: Label = $Center/Dialog/VBox/Stats/Row/Wave/Value
@onready var _kills_value: Label = $Center/Dialog/VBox/Stats/Row/Kills/Value
@onready var _time_value: Label = $Center/Dialog/VBox/Stats/Row/Time/Value
@onready var _revives_left: Label = $Center/Dialog/VBox/RevivesLeft
@onready var _note: Label = $Center/Dialog/VBox/Note
@onready var bail_button: Panel = $Center/Dialog/VBox/Buttons/BailButton
@onready var revive_button: Panel = $Center/Dialog/VBox/Buttons/ReviveButton
@onready var _revive_icon: TextureRect = $Center/Dialog/VBox/Buttons/ReviveButton/HBox/Icon
@onready var revive_label: Label = $Center/Dialog/VBox/Buttons/ReviveButton/HBox/Text/Label
@onready var _revive_sub: Label = $Center/Dialog/VBox/Buttons/ReviveButton/HBox/Text/Sub

# Revive only happens once the reward was granted AND the ad has been closed,
# whichever of the two arrives last. Until then the world stays paused.
var _ad_open: bool = false
var _reward_earned: bool = false
var _reviving: bool = false
var _note_tween: Tween

func _ready() -> void:
	bail_button.gui_input.connect(_check_if_touch_then_execute.bind(_on_okay_button_gui_input))
	revive_button.gui_input.connect(_check_if_touch_then_execute.bind(_on_revive_button_gui_input))

	AdMobManager.rewarded_ad_failed_to_show.connect(_handle_rewarded_ad_failed_to_show)
	AdMobManager.rewarded_earned.connect(_on_rewarded_earned)
	AdMobManager.rewarded_ad_dismissed.connect(_on_rewarded_ad_dismissed)
	_fill_stats()
	_update_revive_button()
	_play_entrance()

func _fill_stats() -> void:
	# Same wave figure the results screen shows after Bail Out.
	_wave_value.text = str(global.WAVE_MANAGER.currentWave - 1) if is_instance_valid(global.WAVE_MANAGER) else "-"
	_kills_value.text = str(global.TOTAL_ENEMY_KILLS)
	var seconds: int = int(global.WORLD.elapsedTime) if is_instance_valid(global.WORLD) else 0
	_time_value.text = "%02d:%02d" % [seconds / 60, seconds % 60]

## Revive spends a shard if the player has one, otherwise it plays an ad.
## After MAX_REVIVES_PER_RUN revives the button greys out.
func _update_revive_button() -> void:
	var left: int = maxi(global.MAX_REVIVES_PER_RUN - global.RUN_REVIVES, 0)
	_revives_left.text = "REVIVES LEFT  %d / %d" % [left, global.MAX_REVIVES_PER_RUN]
	if left == 0:
		_revive_icon.visible = false
		revive_label.text = "NO REVIVES"
		_revive_sub.text = "Limit reached this run"
		revive_button.modulate.a = 0.4
	elif InventoryManager.anchor_shards > 0:
		_revive_icon.visible = true
		revive_label.text = "REVIVE"
		_revive_sub.text = "Use a shard (%d owned)" % InventoryManager.anchor_shards
	else:
		_revive_icon.visible = false
		revive_label.text = "REVIVE"
		_revive_sub.text = "Watch an ad"

## The world behind dims in and the panel rises into place.
func _play_entrance() -> void:
	_dim.modulate.a = 0.0
	_dialog.modulate.a = 0.0
	await get_tree().process_frame   # let the panel lay out first
	_dialog.pivot_offset = _dialog.size * 0.5
	_dialog.scale = Vector2(0.94, 0.94)
	var tween := create_tween().set_parallel()
	tween.tween_property(_dim, "modulate:a", 1.0, 0.35)
	tween.tween_property(_dialog, "modulate:a", 1.0, 0.3).set_delay(0.08)
	tween.tween_property(_dialog, "scale", Vector2.ONE, 0.4).set_delay(0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _on_rewarded_earned(_reward_type: String, _amount: int) -> void:
	if _reward_earned:
		return
	_reward_earned = true
	AchievementManager.register_revive()
	_try_revive()

func _on_rewarded_ad_dismissed() -> void:
	_ad_open = false
	# Closed early without the reward: stay on the death screen.
	_try_revive()

func _try_revive() -> void:
	if _reward_earned and not _ad_open and not _reviving:
		_reviving = true
		_start_countdown()

## World stays paused while a 3-2-1 plays, so the player can get ready.
func _start_countdown() -> void:
	global.RUN_REVIVES += 1
	visible = false
	
	var settings := LabelSettings.new()
	settings.font = FONT
	settings.font_size = 120
	settings.font_color = Color(0.85, 0.97, 1.0)
	settings.outline_size = 14
	settings.outline_color = Color(0.02, 0.05, 0.1, 0.85)
	
	var label := Label.new()
	label.label_settings = settings
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.size = Vector2(240, 180)
	get_parent().add_child(label)
	
	var view: Vector2 = get_viewport_rect().size
	# Below the player, clear of the wave banner and the HUD corners.
	label.position = Vector2(view.x * 0.5, view.y * 0.72) - label.size * 0.5
	label.pivot_offset = label.size * 0.5
	
	var tween: Tween = label.create_tween()
	for n in range(COUNTDOWN_FROM, 0, -1):
		tween.tween_callback(func():
			label.text = str(n)
			global.WORLD.audio_play(preload("res://Assets/SFX/UI.mp3"), "ui")
		)
		tween.tween_property(label, "scale", Vector2.ONE, COUNTDOWN_STEP * 0.35).from(Vector2(1.6, 1.6)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(label, "modulate:a", 1.0, COUNTDOWN_STEP * 0.25).from(0.0)
		tween.tween_interval(COUNTDOWN_STEP * 0.4)
		tween.tween_property(label, "modulate:a", 0.0, COUNTDOWN_STEP * 0.25)
	tween.tween_callback(_finish_revive)

func _finish_revive() -> void:
	get_tree().paused = false
	var player: Player = global.PLAYER
	player.take_heal(player.stats.maxHP * 0.5)
	player.revive_shockwave()
	# Free the whole death screen layer (this script sits on its root control).
	get_parent().queue_free()

func _handle_rewarded_ad_failed_to_show(_err: String) -> void:
	_ad_open = false
	if _note_tween:
		_note_tween.kill()
	_note.visible = true
	_note.modulate.a = 1.0
	_note_tween = create_tween()
	_note_tween.tween_interval(3.0)
	_note_tween.tween_property(_note, "modulate:a", 0.0, 0.4)
	_note_tween.tween_callback(func(): _note.visible = false)

func _check_if_touch_then_execute(event: InputEvent, functionToExecute: Callable):
	if event is InputEventScreenTouch and event.is_pressed():
		global.WORLD.audio_play(preload("res://Assets/SFX/UI.mp3"), "ui")
		functionToExecute.call()

func _on_okay_button_gui_input() -> void:
	var descendResults: Control = load("res://Scenes/HUD/descend_results.tscn").instantiate()
	add_sibling(descendResults)
	descendResults.set_stats(
		global.TOTAL_ENEMY_KILLS,
		global.WAVE_MANAGER.currentWave-1,
		global.WORLD.elapsedTime
	)
	
	queue_free()

func _on_revive_button_gui_input() -> void:
	if _ad_open or _reviving or global.RUN_REVIVES >= global.MAX_REVIVES_PER_RUN:
		return
	# Spend an Anchor Shard if the player has one: no ad, straight to the countdown.
	if InventoryManager.use_anchor_shard():
		AchievementManager.register_revive()
		_reviving = true
		_start_countdown()
		return
	_ad_open = true
	AdMobManager.show_rewarded_ad()
