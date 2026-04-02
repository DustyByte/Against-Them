class_name HangerWeaponCard
extends Panel

@onready var reloadPB: ProgressBar = $ProgressBar
@onready var ammoCountIndicator: Label = $AmmoIndicator
@onready var ammoIcon: Panel = $AmmoIcon
@onready var avatar: Sprite2D = $Avatar
var selectedColor: Color = Color(1, 1, 1, 0.5)
var deselectedColor: Color = Color(1, 1, 1, 0.0)
var displayingWeapon: Weapon = null


func set_weapon_ref(ref: Weapon) -> void:
	displayingWeapon = ref


func set_avatar(avatarTexture: Texture) -> void:
	avatar.texture = avatarTexture


func switch_state_reload() -> void:
	reloadPB.visible = true
	ammoCountIndicator.visible = false
	ammoIcon.visible = false


func switch_state_ammo() -> void:
	reloadPB.visible = false
	ammoCountIndicator.visible = true
	ammoIcon.visible = true


func set_ammo_count(count: int) -> void:
	ammoCountIndicator.text = str(count)


func set_reload_bar_values(val: float, maxVal: float) -> void:
	reloadPB.max_value = maxVal
	reloadPB.value = val


func switch_state_selected() -> void:
	material.set_shader_parameter('color', selectedColor)


func switch_state_deselected() -> void:
	material.set_shader_parameter('color', deselectedColor)


func _on_touch_screen_button_released() -> void:
	global.PLAYERS_WEAPON_SYSTEM.select_weapon(displayingWeapon)
