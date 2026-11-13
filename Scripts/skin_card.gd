extends PanelContainer
## Shop card for one Echo skin: live preview (tap to enlarge), name, price
## in Echoes and a Purchase button. The Shop screen handles what taps do.

signal preview_tapped(skin_id: String)
signal purchase_tapped(skin_id: String)

const SkinPreview = preload("res://Scripts/skin_preview.gd")
const TAP_MAX_DRAG: float = 24.0
const PRICE_COLOR := Color(0.95, 0.88, 0.7, 1)
const SHORT_COLOR := Color(1.0, 0.55, 0.56, 1)

@onready var _stage: PanelContainer = $VBox/Stage
@onready var _view_hint: Label = $VBox/Stage/ViewHint
@onready var _name_label: Label = $VBox/NameLabel
@onready var _price_icon: TextureRect = $VBox/PricePanel/HBox/Icon
@onready var _price_value: Label = $VBox/PricePanel/HBox/Value
@onready var _price_unit: Label = $VBox/PricePanel/HBox/Unit
@onready var _button: Panel = $VBox/PurchaseButton
@onready var _button_label: Label = $VBox/PurchaseButton/Label

var skin_id: String = ""
var _price: int = 0
var _press_positions: Dictionary = {}   # control -> touch-down position


func setup(skin: Dictionary) -> void:
	skin_id = skin["id"]
	_price = skin["price"]
	_name_label.text = String(skin["name"]).to_upper()
	_price_value.text = str(_price)

	var preview := SkinPreview.new()
	preview.setup(load(skin["shader"]))
	_stage.add_child(preview)
	_stage.move_child(preview, 0)   # keep the "tap to view" hint on top

	_connect_tap(_stage, func(): preview_tapped.emit(skin_id))
	_connect_tap(_button, func(): purchase_tapped.emit(skin_id))
	refresh()


## Owned skins swap the price for "Owned"; unaffordable prices turn red.
func refresh() -> void:
	var owned: bool = InventoryManager.owns_skin(skin_id)
	_price_icon.visible = not owned
	_price_unit.visible = not owned
	if owned:
		_price_value.text = "OWNED"
		_price_value.add_theme_color_override("font_color", Color(0.62, 0.88, 0.95))
		_button_label.text = "OWNED"
		_button.modulate.a = 0.4
	else:
		_price_value.text = str(_price)
		_price_value.add_theme_color_override("font_color",
			PRICE_COLOR if MetaProgression.echoes >= _price else SHORT_COLOR)
		_button_label.text = "PURCHASE"
		_button.modulate.a = 1.0


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
