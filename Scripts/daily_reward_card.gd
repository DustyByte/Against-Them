extends Control

## The daily transmission from Earth: today's reward on a 7-day track. Opens
## by itself once a day from the Home screen, and any time from Echo's ship
## circling Umbra. When closed it shrinks into the ship, so the player learns
## where to find it.

const FLY_TIME: float = 0.5
const REWARD_COLOR := Color(0.62, 0.88, 0.95)

@onready var _dim: ColorRect = $Dim
@onready var _dialog: PanelContainer = $Center/Dialog
@onready var _reward: Label = $Center/Dialog/VBox/Reward
@onready var _shards: Label = $Center/Dialog/VBox/Shards
@onready var _shards_gap: Control = $Center/Dialog/VBox/ShardsGap
@onready var _hint: Label = $Center/Dialog/VBox/Hint
@onready var _track: Control = $Center/Dialog/VBox/Track
@onready var _status: Label = $Center/Dialog/VBox/Status
@onready var _close_btn: Panel = $Center/Dialog/VBox/Buttons/CloseButton
@onready var _claim_btn: Panel = $Center/Dialog/VBox/Buttons/ClaimButton
@onready var _claim_label: Label = $Center/Dialog/VBox/Buttons/ClaimButton/Label

var _home: Node   # home.gd: its tap handler and the ship
var _closing := false


func _ready() -> void:
	_home = $"../.."
	var on_tap: Callable = _home._check_if_touch_then_execute
	_close_btn.gui_input.connect(on_tap.bind(_close_btn, _close))
	_claim_btn.gui_input.connect(on_tap.bind(_claim_btn, _claim))
	_dim.gui_input.connect(_on_backdrop_input)

	# The countdown only needs minutes; one cheap tick a second while open.
	var timer := Timer.new()
	timer.wait_time = 1.0
	timer.autostart = true
	timer.timeout.connect(_refresh)
	add_child(timer)

	_refresh()
	_play_entrance()


func _refresh() -> void:
	var waiting: bool = MetaProgression.can_claim_daily_reward()
	var day: int = MetaProgression.daily_reward_day()
	_reward.text = "+%d ECHOES" % MetaProgression.DAILY_REWARDS[day]
	var shards: int = MetaProgression.DAILY_SHARDS[day]
	_shards.visible = shards > 0
	_shards_gap.visible = shards > 0
	_shards.text = "+%d ANCHOR SHARD%s" % [shards, "S" if shards > 1 else ""]
	_hint.text = "DAY %d OF %d" % [day + 1, MetaProgression.DAILY_REWARDS.size()]
	_track.today = day
	_track.waiting = waiting
	_track.queue_redraw()
	if waiting:
		_status.text = "MISSED DAYS NEVER RESET YOUR TRACK"
		_claim_label.text = "RECEIVE"
		_claim_btn.modulate.a = 1.0
	else:
		var seconds: int = MetaProgression.seconds_until_echo_ad_reset()   # local midnight
		_status.text = "NEXT TRANSMISSION IN %dH %02dM" % [seconds / 3600, (seconds / 60) % 60]
		_claim_label.text = "RECEIVED"
		_claim_btn.modulate.a = 0.4


func _claim() -> void:
	if _closing:
		return
	var amount: int = MetaProgression.claim_daily_reward()
	if amount <= 0:
		return
	_home.collect_echoes(_reward.get_global_rect().get_center(), amount)
	_refresh()
	var tween := create_tween()
	tween.tween_property(_track, "pop", 1.0, 0.35).from(0.0)
	tween.parallel().tween_method(func(_v: float): _track.queue_redraw(), 0.0, 1.0, 0.35)
	_reward.pivot_offset = _reward.size * 0.5
	var bump := create_tween()
	bump.tween_property(_reward, "scale", Vector2(1.18, 1.18), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	bump.tween_property(_reward, "scale", Vector2.ONE, 0.25)


# --- Opening and closing ------------------------------------------------------

## The backdrop swallows every touch (so nothing behind reacts) and closes on a tap.
func _on_backdrop_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		accept_event()
	_home._check_if_touch_then_execute(event, _dim, _close)


## Shrinks and fades the card into Echo's ship (following it as it moves),
## which then gives a little flash.
func _close() -> void:
	if _closing:
		return
	_closing = true
	var start: Vector2 = _dialog.position + _dialog.size * 0.5
	_dialog.pivot_offset = _dialog.size * 0.5
	var tween := create_tween().set_parallel()
	tween.tween_property(_dim, "modulate:a", 0.0, FLY_TIME * 0.8)
	tween.tween_method(func(t: float):
		var target: Vector2 = _home.ship_position()
		var centre: Vector2 = start.lerp(target, t * t)               # speeding up into it
		var shrink: float = 1.0 - (1.0 - t) * (1.0 - t)                  # shrinking fast at first
		_dialog.position = centre - _dialog.size * 0.5
		_dialog.scale = Vector2.ONE * lerpf(1.0, 0.03, shrink)
		_dialog.modulate.a = 1.0 - smoothstep(0.5, 1.0, t)
	, 0.0, 1.0, FLY_TIME)
	await tween.finished
	_home.ship_received()
	queue_free()


func _play_entrance() -> void:
	_dim.modulate.a = 0.0
	_dialog.modulate.a = 0.0
	await get_tree().process_frame   # let the panel lay out first
	_dialog.pivot_offset = _dialog.size * 0.5
	_dialog.scale = Vector2(0.96, 0.96)
	var tween := create_tween().set_parallel()
	tween.tween_property(_dim, "modulate:a", 1.0, 0.2)
	tween.tween_property(_dialog, "modulate:a", 1.0, 0.18)
	tween.tween_property(_dialog, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
