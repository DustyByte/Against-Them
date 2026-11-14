class_name HangerWeaponCard
extends Control
## One weapon in the run HUD's hanger: ammo count (or reload progress), the
## weapon in a hexagon, and a highlight when it's the selected weapon.
## Drawn by weapon_card.gdshader; the weapon's accent color is taken from the
## pastel circle behind its hanger picture.

const STATE_TIME := 0.2
const FALLBACK_ACCENT := Color(0.62, 0.88, 0.95)

@onready var _visual: ColorRect = $Visual
@onready var _status: Label = $Status
@onready var ammoCountIndicator: Label = $AmmoIndicator
var _mat: ShaderMaterial
var displayingWeapon: Weapon = null
var _accent: Color = FALLBACK_ACCENT
var _selected: float = 0.0
var _selectTween: Tween
var _isSelected: bool = false


func _ready() -> void:
	_mat = _visual.material
	_mat.set_shader_parameter("rect_size", size)
	_mat.set_shader_parameter("selected", _selected)
	get_parent().set_hanger_on_screen_pivot_center_right(1.0, 0.3)


func set_weapon_ref(ref: Weapon) -> void:
	displayingWeapon = ref


func set_avatar(avatarTexture: Texture) -> void:
	_mat.set_shader_parameter("icon_tex", avatarTexture)
	_accent = _accent_from(avatarTexture)
	_mat.set_shader_parameter("accent", _accent)
	if _isSelected:
		_share_accent()


func switch_state_reload() -> void:
	_status.text = "RELOAD"
	ammoCountIndicator.modulate.a = 0.35
	_mat.set_shader_parameter("reloading", 1.0)
	_mat.set_shader_parameter("bar_value", 0.0)


func switch_state_ammo() -> void:
	_status.text = "AMMO"
	ammoCountIndicator.modulate.a = 1.0
	_mat.set_shader_parameter("reloading", 0.0)


func set_ammo_count(count: int) -> void:
	ammoCountIndicator.text = str(count)
	var maxAmmo: int = displayingWeapon.stats.maxAmmo if displayingWeapon else 0
	_mat.set_shader_parameter("bar_value", float(count) / maxAmmo if maxAmmo > 0 else 1.0)


func set_reload_bar_values(val: float, maxVal: float) -> void:
	_mat.set_shader_parameter("bar_value", clampf(val / maxVal, 0.0, 1.0) if maxVal > 0.0 else 0.0)


func switch_state_selected() -> void:
	_isSelected = true
	_animate_selected(1.0)
	_share_accent()


func switch_state_deselected() -> void:
	_isSelected = false
	_animate_selected(0.0)


## The fire button takes the selected weapon's color.
func _share_accent() -> void:
	if global.ON_RUN_HUD:
		global.ON_RUN_HUD.set_fire_accent(_accent)


func _animate_selected(target: float) -> void:
	if _selectTween:
		_selectTween.kill()
	_selectTween = create_tween()
	_selectTween.tween_method(func(v: float):
		_selected = v
		_mat.set_shader_parameter("selected", v)
		_status.modulate.a = 0.6 + 0.4 * v
	, _selected, target, STATE_TIME)


## The hanger pictures are weapons on a pastel circle; that circle's color
## becomes the weapon's accent. Read once, when the card is set up.
func _accent_from(tex: Texture) -> Color:
	var img: Image = tex.get_image() if tex else null
	if img == null:
		return FALLBACK_ACCENT
	if img.is_compressed():
		img.decompress()
	var c: Color = img.get_pixel(int(img.get_width() * 0.5), int(img.get_height() * 0.12))
	if c.a < 0.5:
		return FALLBACK_ACCENT
	# The circles are soft pastels; push the saturation so the glow reads.
	return Color.from_hsv(c.h, clampf(c.s * 2.2, 0.35, 0.75), clampf(c.v * 1.05, 0.8, 1.0))


func _on_touch_screen_button_released() -> void:
	global.PLAYERS_WEAPON_SYSTEM.select_weapon(displayingWeapon)
