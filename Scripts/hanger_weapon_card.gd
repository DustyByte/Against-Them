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


var initammoIndicatorFontsize: int = 10
func increase_card_size(by: float) -> void:
	size *= by
	custom_minimum_size = size
	var current_stylebox: StyleBoxFlat = get_theme_stylebox("panel")
	var unique_stylebox: StyleBoxFlat = current_stylebox.duplicate()
	unique_stylebox.corner_radius_top_right = int(float(current_stylebox.corner_radius_top_right) * by)
	unique_stylebox.corner_radius_bottom_right = int(float(current_stylebox.corner_radius_bottom_right) * by)
	add_theme_stylebox_override("panel", unique_stylebox)
	
	avatar.scale *= by
	avatar.position *= by
	
	reloadPB.size *= by
	reloadPB.position *= by
	var current_bg: StyleBoxFlat = reloadPB.get_theme_stylebox("background")
	var unique_bg: StyleBoxFlat = current_bg.duplicate()
	unique_bg.set_corner_radius_all(int(float(current_bg.corner_radius_top_left) * by))
	reloadPB.add_theme_stylebox_override("background", unique_bg)
	var current_fill: StyleBoxFlat = reloadPB.get_theme_stylebox("fill")
	var unique_fill: StyleBoxFlat = current_fill.duplicate()
	unique_fill.set_corner_radius_all(int(float(current_fill.corner_radius_top_left) * by))
	reloadPB.add_theme_stylebox_override("fill", unique_fill)
	
	$UltIndicator.size *= by
	$UltIndicator.position *= by
	var ult_current_stylebox: StyleBoxFlat = $UltIndicator.get_theme_stylebox("panel")
	var ult_unique_stylebox: StyleBoxFlat = ult_current_stylebox.duplicate()
	ult_unique_stylebox.set_corner_radius_all(int(float(current_stylebox.corner_radius_top_right) * by))
	$UltIndicator.add_theme_stylebox_override("panel", ult_unique_stylebox)
	
	ammoIcon.size *= by
	ammoIcon.position *= by
	
	initammoIndicatorFontsize = int(float(initammoIndicatorFontsize)*by)
	ammoCountIndicator.position *= by
	ammoCountIndicator.add_theme_font_size_override("font_size", initammoIndicatorFontsize)
	
	$TouchScreenButton.scale *= by
	$TouchScreenButton.position *= by


func _on_touch_screen_button_released() -> void:
	global.PLAYERS_WEAPON_SYSTEM.select_weapon(displayingWeapon)


func _ready() -> void:
	increase_card_size(get_viewport_rect().size.y * 0.085 / size.y) # 0.1 is an imaginative value that will be visually appealing
	get_parent().set_hanger_on_screen_pivot_center_right(1.0, 0.3)
