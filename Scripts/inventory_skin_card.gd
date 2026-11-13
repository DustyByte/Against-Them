extends PanelContainer
## Inventory cell for an owned skin: live preview (tap to enlarge), name and
## an Equip button that shows "Equipped" on the skin Echo is wearing.

signal preview_tapped(skin_id: String)
signal equip_tapped(skin_id: String)

const SkinPreview = preload("res://Scripts/skin_preview.gd")
const TAP_MAX_DRAG: float = 24.0

@onready var _stage: PanelContainer = $VBox/Stage
@onready var _name_label: Label = $VBox/NameLabel
@onready var _button: Panel = $VBox/EquipButton
@onready var _button_label: Label = $VBox/EquipButton/Label

var skin_id: String = ""
var _press_positions: Dictionary = {}


func setup(skin: Dictionary) -> void:
	skin_id = skin["id"]
	_name_label.text = String(skin["name"]).to_upper()

	var preview := SkinPreview.new()
	var path: String = skin.get("shader", "")
	preview.setup(load(path) if path != "" else null)
	_stage.add_child(preview)
	_stage.move_child(preview, 0)   # keep the "tap to view" hint on top

	_connect_tap(_stage, func(): preview_tapped.emit(skin_id))
	_connect_tap(_button, func(): equip_tapped.emit(skin_id))
	refresh()


func refresh() -> void:
	var equipped: bool = InventoryManager.equipped_skin == skin_id
	_button_label.text = "EQUIPPED" if equipped else "EQUIP"
	_button.modulate.a = 0.45 if equipped else 1.0


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
