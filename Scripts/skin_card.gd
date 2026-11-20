extends PanelContainer
## Shop card for one Echo skin: live preview (tap to enlarge), name, and two
## ways to unlock it: pay Echoes, or watch a number of rewarded ads (progress
## is kept per skin). The Shop screen handles the Echoes purchase; this card
## runs the ad flow itself once the Shop calls watch_ad().

signal preview_tapped(skin_id: String)
signal purchase_tapped(skin_id: String)
signal ad_tapped(skin_id: String)

const SkinPreview = preload("res://Scripts/skin_preview.gd")
const TAP_MAX_DRAG: float = 24.0
## If the ad closes before the reward arrives, keep listening this long.
const REWARD_GRACE: float = 2.0
const PRICE_COLOR := Color(0.95, 0.88, 0.7, 1)
const SHORT_COLOR := Color(1.0, 0.55, 0.56, 1)
const AD_LABEL_COLOR := Color(0.85, 0.96, 1, 1)

@onready var _stage: PanelContainer = $VBox/Stage
@onready var _name_label: Label = $VBox/NameLabel
@onready var _options: VBoxContainer = $VBox/PurchaseArea/Options
@onready var _owned: PanelContainer = $VBox/PurchaseArea/Owned
@onready var _echoes_btn: Panel = $VBox/PurchaseArea/Options/EchoesButton
@onready var _price_value: Label = $VBox/PurchaseArea/Options/EchoesButton/HBox/Value
@onready var _ad_btn: Panel = $VBox/PurchaseArea/Options/AdButton
@onready var _ad_label: Label = $VBox/PurchaseArea/Options/AdButton/Margin/HBox/Label
@onready var _ad_tag: Label = $VBox/PurchaseArea/Options/AdButton/Margin/HBox/Tag/Value
@onready var _ad_fill: ColorRect = $VBox/PurchaseArea/Options/AdButton/Track/Fill

var skin_id: String = ""
var _price: int = 0
var _ads_needed: int = 0
var _awaiting_ad := false   # an ad this card asked for is open or paying out
var _message_tween: Tween
var _press_positions: Dictionary = {}   # control -> touch-down position


func setup(skin: Dictionary) -> void:
	skin_id = skin["id"]
	_price = skin["price"]
	_ads_needed = skin["ads"]
	_name_label.text = String(skin["name"]).to_upper()
	_price_value.text = str(_price)

	var preview := SkinPreview.new()
	preview.setup(load(skin["shader"]))
	_stage.add_child(preview)
	_stage.move_child(preview, 0)   # keep the "tap to view" hint on top

	_connect_tap(_stage, func(): preview_tapped.emit(skin_id))
	_connect_tap(_echoes_btn, func():
		if not _owns():
			purchase_tapped.emit(skin_id))
	_connect_tap(_ad_btn, func():
		if not _owns() and not _awaiting_ad:
			ad_tapped.emit(skin_id))

	InventoryManager.skin_ads_changed.connect(func(id: String, _watched: int):
		if id == skin_id:
			refresh())
	AdMobManager.rewarded_earned.connect(_on_rewarded_earned)
	AdMobManager.rewarded_ad_dismissed.connect(_on_rewarded_ad_dismissed)
	AdMobManager.rewarded_ad_failed_to_show.connect(_on_rewarded_ad_failed_to_show)
	refresh()


## Owned skins swap both options for "Owned"; an unaffordable price turns red.
func refresh() -> void:
	var owned: bool = _owns()
	# Hidden with alpha, not visibility, so owned cards keep the same height.
	_options.modulate.a = 0.0 if owned else 1.0
	_owned.visible = owned
	if owned:
		return
	_price_value.add_theme_color_override("font_color",
		PRICE_COLOR if MetaProgression.echoes >= _price else SHORT_COLOR)

	var watched: int = mini(InventoryManager.skin_ads_watched(skin_id), _ads_needed)
	_ad_tag.text = "%d / %d" % [watched, _ads_needed]
	_ad_fill.anchor_right = float(watched) / float(maxi(_ads_needed, 1))
	_ad_fill.offset_right = 0.0
	_update_ad_label()


func _owns() -> bool:
	return InventoryManager.owns_skin(skin_id)


func _update_ad_label() -> void:
	if _message_tween and _message_tween.is_valid():
		return   # a short message is showing; it restores the label itself
	_ad_label.text = "LOADING..." if _awaiting_ad else "WATCH ADS"
	_ad_btn.modulate.a = 0.5 if _awaiting_ad else 1.0


# --- Ad flow ------------------------------------------------------------------

## Called by the Shop after an ad tap (it plays the tap sound and checks no
## dialog is open).
func watch_ad() -> void:
	if _awaiting_ad or _owns():
		return
	_awaiting_ad = true
	_update_ad_label()
	if OS.has_feature("editor") and not AdMobManager.is_rewarded_ad_ready():
		# No ads on desktop: pretend one was watched so the flow can be tested
		# from the editor. Exported builds never take this path.
		await get_tree().create_timer(0.6).timeout
		_on_rewarded_earned("editor", 1)
		return
	AdMobManager.show_rewarded_ad()


func _on_rewarded_earned(_reward_type: String, _amount: int) -> void:
	if not _awaiting_ad:
		return   # someone else's ad (another card, the Echoes notch...)
	_awaiting_ad = false
	if InventoryManager.register_skin_ad(skin_id, _ads_needed):
		_pulse(_owned)   # unlocked: the shop refreshes every card via skins_changed
	else:
		_pulse(_ad_tag)
		refresh()


func _on_rewarded_ad_dismissed() -> void:
	if not _awaiting_ad:
		return
	# The reward can arrive just after the ad closes; wait briefly for it.
	await get_tree().create_timer(REWARD_GRACE).timeout
	if _awaiting_ad:
		_awaiting_ad = false   # closed early, no reward
		_update_ad_label()


func _on_rewarded_ad_failed_to_show(_error: String) -> void:
	if not _awaiting_ad:
		return
	_awaiting_ad = false
	AdMobManager.retry_now()
	_flash_message("NO AD RIGHT NOW")


# --- Feedback -----------------------------------------------------------------

func _pulse(control: Control) -> void:
	await get_tree().process_frame   # let a just-shown control get its size
	control.pivot_offset = control.size * 0.5
	var tween := create_tween()
	tween.tween_property(control, "scale", Vector2(1.12, 1.12), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "scale", Vector2.ONE, 0.25)


## Shows a short note on the ad button, then restores its normal text.
func _flash_message(text: String) -> void:
	if _message_tween:
		_message_tween.kill()
	_ad_label.text = text
	_ad_label.add_theme_color_override("font_color", SHORT_COLOR)
	_ad_btn.modulate.a = 1.0
	_message_tween = create_tween()
	_message_tween.tween_interval(1.6)
	_message_tween.tween_callback(func():
		_message_tween = null
		_ad_label.add_theme_color_override("font_color", AD_LABEL_COLOR)
		_update_ad_label())


## A tap is a touch released close to where it started, so dragging the grid
## to scroll doesn't count.
func _connect_tap(control: Control, action: Callable) -> void:
	control.gui_input.connect(func(event: InputEvent):
		if not (event is InputEventScreenTouch):
			return
		if event.is_pressed():
			_press_positions[control] = event.position
		elif event.position.distance_to(_press_positions.get(control, event.position)) <= TAP_MAX_DRAG:
			action.call()
	)
