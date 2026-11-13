extends PanelContainer
## Inventory cell for one consumable item: icon, name, short description and
## how many the player has.

@onready var _icon: TextureRect = $VBox/Top/IconFrame/Icon
@onready var _name_label: Label = $VBox/Top/Info/NameLabel
@onready var _amount: Label = $VBox/Top/Info/AmountPill/HBox/Value
@onready var _desc: Label = $VBox/DescLabel

var item_id: String = ""


func setup(item: Dictionary) -> void:
	item_id = item["id"]
	_icon.texture = load(item["icon"])
	_name_label.text = String(item["name"]).to_upper()
	_desc.text = item["description"]
	refresh()


func refresh() -> void:
	_amount.text = str(InventoryManager.get_item_amount(item_id))
