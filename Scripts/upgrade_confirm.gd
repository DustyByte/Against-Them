extends Control

## Purchase confirmation (an upgrade rank or a shop item): a short message, the cost and
## Cancel / Confirm. Confirm is disabled when the player can't afford it.

signal confirmed
signal cancelled

@onready var _title: Label = $Center/Dialog/VBox/Title
@onready var _message: Label = $Center/Dialog/VBox/Message
@onready var _cost_value: Label = $Center/Dialog/VBox/Cost/Value
@onready var _shortfall: Label = $Center/Dialog/VBox/Shortfall
@onready var _cancel: Panel = $Center/Dialog/VBox/Buttons/Cancel
@onready var _confirm: Panel = $Center/Dialog/VBox/Buttons/Confirm
@onready var _dim: ColorRect = $Dim

var _can_confirm: bool = false


func _ready() -> void:
	_cancel.gui_input.connect(_on_button_input.bind(cancelled))
	_confirm.gui_input.connect(func(event: InputEvent):
		if _can_confirm:
			_on_button_input(event, confirmed)
	)
	# Tapping the dimmed area outside the dialog also cancels.
	_dim.gui_input.connect(_on_button_input.bind(cancelled))


func setup(title: String, next_rank: int, max_rank: int, cost: int, echoes_owned: int) -> void:
	setup_with_message(title, "Upgrade to rank %d / %d?" % [next_rank, max_rank], cost, echoes_owned)


## Same dialog with any message (used by the Shop for skin purchases).
func setup_with_message(title: String, message: String, cost: int, echoes_owned: int) -> void:
	_title.text = title.to_upper()
	_message.text = message
	_cost_value.text = str(cost)

	_can_confirm = echoes_owned >= cost
	_shortfall.visible = not _can_confirm
	_shortfall.text = "You need %d more Echoes." % (cost - echoes_owned)
	_confirm.modulate.a = 1.0 if _can_confirm else 0.35


func _on_button_input(event: InputEvent, result: Signal) -> void:
	if event is InputEventScreenTouch and event.is_pressed():
		accept_event()
		result.emit()
