extends Node2D

## Home screen: Echoe's view from orbit. A breathing planet with Echoe's ship
## circling it, and a minimal menu on the left.

const DISCORD_LINK: String = "https://discord.gg/zjXPsKS2"

# Planet placement as fractions of the screen; size is relative to screen height.
const PLANET_CENTER: Vector2 = Vector2(0.71, 0.53)
const PLANET_HEIGHT_RATIO: float = 0.74
const PLANET_TEXTURE_DISC_RATIO: float = 0.91 # the disc fills ~91% of Planet.png
const BG_PLANET_PEAK_OFFSET: float = 14.0
const BREATHE_PERIOD: float = 6.0

const ORBIT_RADII_RATIO: Vector2 = Vector2(0.62, 0.15) # of the planet's diameter
const ORBIT_TILT: float = -0.2
const SHIP_ORBIT_PERIOD: float = 26.0

const INTRO_STAGGER: float = 0.06
const INTRO_SLIDE: float = 24.0

@onready var _menu: Control = $UI/Menu
@onready var _column: VBoxContainer = $UI/Menu/Column
@onready var _descend_btn: Panel = $UI/Menu/Column/Descend
@onready var _vault_btn: Panel = $UI/Menu/Column/Vault
@onready var _achievements_btn: Panel = $UI/Menu/Column/Achievements
@onready var _settings_btn: Panel = $UI/Menu/Column/Settings
@onready var _discord_btn: Panel = $UI/Menu/Column/Discord
@onready var _quit_btn: Panel = $UI/Menu/Column/Quit
@onready var _echoes_value: Label = $UI/Menu/Column/Vault/Margin/HBox/EchoesValue
@onready var _status_light: ColorRect = $UI/Menu/Footer/StatusLight
@onready var _version: Label = $UI/Menu/Version
@onready var _fade: ColorRect = $UI/Fade
@onready var planetSprite: Sprite2D = $Planet
@onready var _planet_glow: Sprite2D = $PlanetGlow
@onready var _orbit_back: Node2D = $OrbitBack
@onready var _orbit_front: Node2D = $OrbitFront
@onready var UIPressAS: AudioStreamPlayer = $AudioStreamPlayer

var _planet_rest_position: Vector2
var _planet_base_scale: Vector2
var _time: float = 0.0
var _is_leaving: bool = false


func _ready() -> void:
	get_viewport().size_changed.connect(_update_layout)
	_update_layout()

	global.SFX_TYPES_PERM["ui"] = SettingsManager.settings.ui_sfx
	global.SFX_TYPES_PERM["game_world"] = SettingsManager.settings.game_world_sfx

	_echoes_value.text = str(MetaProgression.echoes)
	MetaProgression.echoes_changed.connect(_on_echoes_changed)
	_version.text = "v" + global.GAME_VERSION

	_connect_button(_descend_btn, _on_descend_pressed)
	_connect_button(_vault_btn, func(): pass)
	_connect_button(_achievements_btn, _on_achievements_pressed)
	_connect_button(_settings_btn, _on_settings_pressed)
	_connect_button(_discord_btn, OS.shell_open.bind(DISCORD_LINK))
	_connect_button(_quit_btn, get_tree().quit)

	_play_intro()
	_pulse_status_light()


func _process(delta: float) -> void:
	_time += delta

	# Planet breathing: a slow float up and down, with the glow following.
	var offset_y: float = sin(TAU * _time / BREATHE_PERIOD) * BG_PLANET_PEAK_OFFSET
	planetSprite.position = _planet_rest_position + Vector2(0.0, offset_y)
	_planet_glow.position = planetSprite.position

	# Echoe's ship circling the planet.
	var ship_angle: float = TAU * _time / SHIP_ORBIT_PERIOD
	for orbit in [_orbit_back, _orbit_front]:
		orbit.center = planetSprite.position
		orbit.ship_angle = ship_angle
		orbit.queue_redraw()


func _update_layout() -> void:
	var screen: Vector2 = get_viewport_rect().size
	var texture_size: Vector2 = planetSprite.texture.get_size()

	var diameter: float = screen.y * PLANET_HEIGHT_RATIO
	var planet_scale: float = diameter / (texture_size.y * PLANET_TEXTURE_DISC_RATIO)
	_planet_base_scale = Vector2.ONE * planet_scale
	planetSprite.scale = _planet_base_scale
	_planet_rest_position = screen * PLANET_CENTER
	planetSprite.position = _planet_rest_position

	var glow_size: float = diameter * 1.65
	_planet_glow.scale = Vector2.ONE * glow_size / _planet_glow.texture.get_width()
	_planet_glow.position = _planet_rest_position

	for orbit in [_orbit_back, _orbit_front]:
		orbit.radii = ORBIT_RADII_RATIO * diameter
		orbit.tilt = ORBIT_TILT
		orbit.center = _planet_rest_position


# --- Buttons -----------------------------------------------------------------

func _connect_button(button: Panel, action: Callable) -> void:
	button.gui_input.connect(func(event: InputEvent):
		if _is_leaving:
			return
		if event is InputEventScreenTouch and event.is_pressed():
			play_ui_sfx()
			_flash(button)
			action.call()
	)


## Used by the Settings screen (settings_menu.gd looks it up on this node) to
## make its own buttons respond to taps with the menu sound.
func _check_if_touch_then_execute(event: InputEvent, functionToExecute: Callable) -> void:
	if event is InputEventScreenTouch and event.is_pressed():
		play_ui_sfx()
		functionToExecute.call()


## Brief highlight on the tapped row so every press is acknowledged.
func _flash(button: Panel) -> void:
	var highlight: ColorRect = button.get_node("Highlight")
	var tween := create_tween()
	tween.tween_property(highlight, "color:a", 0.22, 0.06)
	tween.tween_property(highlight, "color:a", 0.0, 0.35).set_trans(Tween.TRANS_SINE)


func play_ui_sfx() -> void:
	if global.SFX_TYPES_PERM["ui"]:
		UIPressAS.pitch_scale = randf_range(0.7, 1.3)
		UIPressAS.play()


func _on_echoes_changed(total: int) -> void:
	_echoes_value.text = str(total)


func _on_settings_pressed() -> void:
	_open_sub_screen(preload("res://Scenes/HUD/settings.tscn").instantiate())


func _on_achievements_pressed() -> void:
	_open_sub_screen(preload("res://Scenes/HUD/achievements.tscn").instantiate())


func _open_sub_screen(screen: Control) -> void:
	_menu.visible = false
	screen.returnPressed.connect(func():
		_menu.visible = true
		screen.queue_free()
	)
	$UI.add_child(screen)


## Descend: the planet swells as Echoe drops toward it and the view fades out.
func _on_descend_pressed() -> void:
	_is_leaving = true
	set_process(false)

	var tween := create_tween().set_parallel()
	tween.tween_property(planetSprite, "scale", _planet_base_scale * 1.35, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(_planet_glow, "modulate:a", 0.0, 0.4)
	tween.tween_property(_orbit_back, "modulate:a", 0.0, 0.25)
	tween.tween_property(_orbit_front, "modulate:a", 0.0, 0.25)
	tween.tween_property(_menu, "modulate:a", 0.0, 0.25)
	tween.tween_property(_fade, "color:a", 1.0, 0.45).set_delay(0.15)
	await tween.finished

	get_tree().change_scene_to_file("res://Scenes/world.tscn")


# --- Ambient motion ----------------------------------------------------------

## Menu items fade in one after another, sliding in slightly from the left.
func _play_intro() -> void:
	await get_tree().process_frame # let the column lay out first

	var delay: float = 0.0
	for item: Control in _column.get_children():
		var target_x: float = item.position.x
		item.modulate.a = 0.0
		item.position.x = target_x - INTRO_SLIDE
		var tween := create_tween().set_parallel()
		tween.tween_property(item, "modulate:a", 1.0, 0.45).set_delay(delay)
		tween.tween_property(item, "position:x", target_x, 0.55).set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		delay += INTRO_STAGGER

	for orbit in [_orbit_back, _orbit_front]:
		orbit.modulate.a = 0.0
		create_tween().tween_property(orbit, "modulate:a", 1.0, 1.2).set_delay(0.3)


## The footer's status light blinks softly like a ship console indicator.
func _pulse_status_light() -> void:
	var tween := create_tween().set_loops()
	tween.tween_property(_status_light, "modulate:a", 0.25, 1.1).set_trans(Tween.TRANS_SINE)
	tween.tween_property(_status_light, "modulate:a", 1.0, 1.1).set_trans(Tween.TRANS_SINE)
