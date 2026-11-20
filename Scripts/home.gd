extends Node2D

## Home screen: Echo's view from orbit. A breathing planet with Echo's ship
## circling it, and a minimal menu on the left.

const DISCORD_LINK: String = "https://discord.gg/5BBKuufMV"

# Planet placement as fractions of the screen; size is relative to screen height.
const PLANET_CENTER: Vector2 = Vector2(0.71, 0.53)
const PLANET_HEIGHT_RATIO: float = 0.74
const PLANET_TEXTURE_DISC_RATIO: float = 0.91 # the disc fills ~91% of Planet.png
const BG_PLANET_PEAK_OFFSET: float = 14.0
const BREATHE_PERIOD: float = 6.0

const ORBIT_RADII_RATIO: Vector2 = Vector2(0.62, 0.15) # of the planet's diameter
const ORBIT_TILT: float = -0.2
const SHIP_ORBIT_PERIOD: float = 26.0

## Quiet looping background music (Assets/Music/umbra_ambient.wav, mixed
## soft already). Fades in on arrival and out on Descend.
const AMBIENT_MUSIC: AudioStream = preload("res://Assets/Music/umbra_ambient.wav")
const AMBIENT_VOLUME_DB: float = -3.0
const AMBIENT_FADE_IN: float = 3.0

const INTRO_STAGGER: float = 0.06
const INTRO_SLIDE: float = 24.0

@onready var _menu: Control = $UI/Menu
@onready var _column: VBoxContainer = $UI/Menu/Column
@onready var _descend_btn: Panel = $UI/Menu/Column/Descend
@onready var _shop_btn: Panel = $UI/Menu/Column/Shop
@onready var _inventory_btn: Panel = $UI/Menu/Column/Inventory
@onready var _upgrades_btn: Panel = $UI/Menu/Column/Upgrades
@onready var _achievements_btn: Panel = $UI/Menu/Column/Achievements
@onready var _settings_btn: Panel = $UI/Menu/Column/Settings
@onready var _discord_btn: Panel = $UI/Menu/DiscordButton
@onready var _quit_btn: Panel = $UI/Menu/Column/Quit
@onready var _profile_btn: Panel = $UI/Menu/ProfileNotch
@onready var _profile_avatar: AvatarPortrait = $UI/Menu/ProfileNotch/Avatar
@onready var _profile_name: Label = $UI/Menu/ProfileNotch/Text/Username
@onready var _profile_id: Label = $UI/Menu/ProfileNotch/Text/PlayerId
@onready var _leaderboard_btn: Panel = $UI/Menu/LeaderboardButton
# The Echoes counter lives outside the menu so it stays visible on sub screens.
@onready var _echoes_counter: PanelContainer = $UI/EchoesCounter
@onready var _echoes_value: Label = $UI/EchoesCounter/HBox/Value
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
## Ripples and grass splashes when Umbra is tapped. Drawn just above the planet.
var _umbra_touch: Node2D = null
var _ambient: AudioStreamPlayer = null
## Nebulas for the backdrop, drawn once at half resolution (nebula_bake.gdshader).
var _nebula_view: SubViewport = null


func _ready() -> void:
	_umbra_touch = preload("res://Scripts/umbra_touch.gd").new()
	_umbra_touch.name = "UmbraTouch"
	add_child(_umbra_touch)
	move_child(_umbra_touch, planetSprite.get_index() + 1)
	_umbra_touch.setup(planetSprite)
	get_viewport().size_changed.connect(_update_layout)
	_update_layout()

	global.SFX_TYPES_PERM["ui"] = SettingsManager.settings.ui_sfx
	global.SFX_TYPES_PERM["game_world"] = SettingsManager.settings.game_world_sfx

	_echoes_value.text = str(MetaProgression.echoes)
	MetaProgression.echoes_changed.connect(_on_echoes_changed)
	_version.text = "v" + global.GAME_VERSION
	_show_profile()
	PlayerProfile.changed.connect(_show_profile)

	_connect_button(_descend_btn, _on_descend_pressed)
	_connect_button(_shop_btn, _on_shop_pressed)
	_connect_button(_inventory_btn, _on_inventory_pressed)
	_connect_button(_upgrades_btn, _on_upgrades_pressed)
	_connect_button(_achievements_btn, _on_achievements_pressed)
	_connect_button(_settings_btn, _on_settings_pressed)
	_connect_button(_discord_btn, OS.shell_open.bind(DISCORD_LINK))
	_connect_button(_quit_btn, get_tree().quit)
	_connect_button(_profile_btn, _on_profile_pressed)
	_connect_button(_leaderboard_btn, _on_leaderboard_pressed)
	_connect_button(_echoes_counter, _on_echoes_counter_pressed)   # the whole notch, not just its +

	_start_ambient()
	_play_intro()
	_pulse_status_light()
	_maybe_prompt_account()


func _process(delta: float) -> void:
	_time += delta

	# Planet breathing: a slow float up and down, with the glow following.
	var offset_y: float = sin(TAU * _time / BREATHE_PERIOD) * BG_PLANET_PEAK_OFFSET
	planetSprite.position = _planet_rest_position + Vector2(0.0, offset_y)
	_planet_glow.position = planetSprite.position

	# Echo's ship circling the planet.
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
	if _umbra_touch:
		_umbra_touch.radius = diameter * 0.5
	_bake_nebula(screen)

	var glow_size: float = diameter * 1.65
	_planet_glow.scale = Vector2.ONE * glow_size / _planet_glow.texture.get_width()
	_planet_glow.position = _planet_rest_position

	for orbit in [_orbit_back, _orbit_front]:
		orbit.radii = ORBIT_RADII_RATIO * diameter
		orbit.tilt = ORBIT_TILT
		orbit.center = _planet_rest_position


func _start_ambient() -> void:
	_ambient = AudioStreamPlayer.new()
	_ambient.name = "AmbientMusic"
	_ambient.stream = AMBIENT_MUSIC
	_ambient.volume_db = -60.0
	add_child(_ambient)
	if SettingsManager.settings.music:
		_fade_ambient_in()


func _fade_ambient_in() -> void:
	if not _ambient.playing:
		_ambient.play()
	_ambient_fade(AMBIENT_VOLUME_DB, AMBIENT_FADE_IN, Tween.EASE_OUT)


var _ambient_tween: Tween = null

func _ambient_fade(to_db: float, time: float, easing: Tween.EaseType) -> Tween:
	if _ambient_tween:
		_ambient_tween.kill()
	_ambient_tween = create_tween()
	_ambient_tween.tween_property(_ambient, "volume_db", to_db, time).set_trans(Tween.TRANS_SINE).set_ease(easing)
	return _ambient_tween


## Music toggle in Settings: fades the music in or out right away.
func set_music_enabled(on: bool) -> void:
	if on:
		_fade_ambient_in()
	else:
		_ambient_fade(-60.0, 0.6, Tween.EASE_IN).tween_callback(_ambient.stop)


## Draws the nebulas once into a half-resolution image the backdrop reads
## every frame. Redrawn only if the window size changes.
func _bake_nebula(screen: Vector2) -> void:
	var size := Vector2i((screen * 0.5).round())
	if _nebula_view == null:
		_nebula_view = SubViewport.new()
		_nebula_view.name = "NebulaBake"
		_nebula_view.disable_3d = true
		_nebula_view.transparent_bg = false
		var painter := ColorRect.new()
		var mat := ShaderMaterial.new()
		mat.shader = preload("res://Shaders/nebula_bake.gdshader")
		painter.material = mat
		painter.set_anchors_preset(Control.PRESET_FULL_RECT)
		_nebula_view.add_child(painter)
		$Backdrop.add_child(_nebula_view)
		var space_mat: ShaderMaterial = $Backdrop/Space.material
		space_mat.set_shader_parameter("nebula", _nebula_view.get_texture())
		space_mat.set_shader_parameter("has_nebula", true)
	elif _nebula_view.size == size:
		return
	_nebula_view.size = size
	var painter_mat: ShaderMaterial = _nebula_view.get_child(0).material
	painter_mat.set_shader_parameter("aspect", screen.x / screen.y)
	_nebula_view.render_target_update_mode = SubViewport.UPDATE_ONCE


# --- Buttons -----------------------------------------------------------------

func _connect_button(button: Control, action: Callable) -> void:
	button.gui_input.connect(func(event: InputEvent):
		if _is_leaving:
			return
		var was_held := Tap.is_held(button)
		if Tap.is_tap(button, event):
			play_ui_sfx()
			_flash(button)
			action.call()
		elif Tap.is_held(button) and not was_held:
			_set_highlight(button, 0.1, 0.06)    # finger down: show it's armed
		elif was_held and not Tap.is_held(button):
			_set_highlight(button, 0.0, 0.2)     # slid off / lifted elsewhere: cancelled
	)


## Used by the Settings screen (settings_menu.gd looks it up on this node) to
## make its own buttons respond to taps (on release) with the menu sound.
func _check_if_touch_then_execute(event: InputEvent, control: Control, functionToExecute: Callable) -> void:
	if Tap.is_tap(control, event):
		play_ui_sfx()
		functionToExecute.call()


## Brief highlight on the tapped row so every press is acknowledged.
func _flash(button: Control) -> void:
	var tween := _set_highlight(button, 0.22, 0.06)
	tween.tween_property(_highlight_of(button), "color:a", 0.0, 0.35).set_trans(Tween.TRANS_SINE)


## Tweens the row's highlight, replacing any highlight tween already running.
func _set_highlight(button: Control, alpha: float, time: float) -> Tween:
	if button.has_meta(&"highlight_tween"):
		var old: Tween = button.get_meta(&"highlight_tween")
		if old.is_valid():
			old.kill()
	var tween := create_tween()
	tween.tween_property(_highlight_of(button), "color:a", alpha, time)
	button.set_meta(&"highlight_tween", tween)
	return tween


## A button's highlight overlay. The Echoes notch is a container, so its
## highlight sits one level down (HighlightLayer/Highlight) to cover the margins.
func _highlight_of(button: Control) -> ColorRect:
	var highlight: ColorRect = button.get_node_or_null(^"Highlight")
	return highlight if highlight else button.get_node(^"HighlightLayer/Highlight")


func play_ui_sfx() -> void:
	if global.SFX_TYPES_PERM["ui"]:
		UIPressAS.pitch_scale = randf_range(0.7, 1.3)
		UIPressAS.play()


func _on_echoes_changed(total: int) -> void:
	_echoes_value.text = str(total)


func _show_profile() -> void:
	_profile_avatar.avatar = PlayerProfile.avatar
	_profile_name.text = PlayerProfile.username
	_profile_id.text = "ID  " + PlayerProfile.player_id


## Watch an ad for Echoes. Also works over sub screens, where the notch stays visible.
func _on_echoes_counter_pressed() -> void:
	_show_popup(preload("res://Scenes/HUD/echoes_ad_card.tscn").instantiate())


## The profile card pops up over the home screen (the menu stays behind the dim).
func _on_profile_pressed() -> void:
	_show_popup(preload("res://Scenes/HUD/profile_card.tscn").instantiate())


## Someone else's profile card, opened from a leaderboard entry
## ({"id", "name", "avatar"}). Your own entry opens your own card.
func show_player_profile(entry: Dictionary) -> void:
	var card: Control = preload("res://Scenes/HUD/profile_card.tscn").instantiate()
	if str(entry.get("id", "")) != PlayerProfile.player_id:
		card.other = entry
	_show_popup(card)


## The username + password popup. Also opened from the profile card.
func open_account_setup() -> void:
	_open_account_dialog(0)   # CLAIM


## Settings > Switch Account.
func open_switch_account() -> void:
	_open_account_dialog(1)   # LOGIN


## Settings > Delete Account.
func open_delete_account() -> void:
	_open_account_dialog(2)   # DELETE


func _open_account_dialog(mode: int) -> void:
	var dialog: Control = preload("res://Scenes/HUD/account_setup.tscn").instantiate()
	dialog.mode = mode
	_show_popup(dialog)


## Back from the first descend: ask the player to claim a username (once).
func _maybe_prompt_account() -> void:
	if not PlayerProfile.should_prompt_account():
		return
	PlayerProfile.mark_account_prompt_shown()
	await get_tree().create_timer(0.9).timeout   # let the home screen settle in first
	if not _is_leaving:
		open_account_setup()


func _show_popup(popup: Control) -> void:
	$UI.add_child(popup)
	$UI.move_child(popup, _fade.get_index())   # above the menu, counters and other popups


func _on_leaderboard_pressed() -> void:
	_open_sub_screen(preload("res://Scenes/HUD/leaderboard.tscn").instantiate(), false)


func _on_settings_pressed() -> void:
	_open_sub_screen(preload("res://Scenes/HUD/settings.tscn").instantiate(), false)


func _on_shop_pressed() -> void:
	_open_sub_screen(preload("res://Scenes/HUD/shop.tscn").instantiate())


func _on_inventory_pressed() -> void:
	_open_sub_screen(preload("res://Scenes/HUD/inventory.tscn").instantiate())


func _on_upgrades_pressed() -> void:
	_open_sub_screen(preload("res://Scenes/HUD/upgrades.tscn").instantiate())


func _on_achievements_pressed() -> void:
	_open_sub_screen(preload("res://Scenes/HUD/achievements.tscn").instantiate())


## `show_echoes` keeps the Echoes counter visible over the sub screen.
func _open_sub_screen(screen: Control, show_echoes: bool = true) -> void:
	_menu.visible = false
	_echoes_counter.visible = show_echoes
	screen.returnPressed.connect(func():
		_menu.visible = true
		_echoes_counter.visible = true
		screen.queue_free()
	)
	$UI.add_child(screen)
	# Draw the sub screen beneath the Echoes counter (and the fade) so the counter stays on top.
	$UI.move_child(screen, _echoes_counter.get_index())


## Descend: the planet swells as Echo drops toward it and the view fades out.
func _on_descend_pressed() -> void:
	_is_leaving = true
	set_process(false)

	var tween := create_tween().set_parallel()
	tween.tween_property(planetSprite, "scale", _planet_base_scale * 1.35, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(_planet_glow, "modulate:a", 0.0, 0.4)
	tween.tween_property(_orbit_back, "modulate:a", 0.0, 0.25)
	tween.tween_property(_orbit_front, "modulate:a", 0.0, 0.25)
	tween.tween_property(_menu, "modulate:a", 0.0, 0.25)
	tween.tween_property(_echoes_counter, "modulate:a", 0.0, 0.25)
	tween.tween_property(_fade, "color:a", 1.0, 0.45).set_delay(0.15)
	if _ambient.playing:
		_ambient_fade(-60.0, 0.6, Tween.EASE_IN)
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

	# The profile, the resource counter and the Discord button drop in from the top edge.
	for notch: Control in [_profile_btn, _leaderboard_btn, _echoes_counter, _discord_btn]:
		var notch_y: float = notch.position.y
		notch.modulate.a = 0.0
		notch.position.y = notch_y - INTRO_SLIDE
		var notch_tween := create_tween().set_parallel()
		notch_tween.tween_property(notch, "modulate:a", 1.0, 0.45).set_delay(0.15)
		notch_tween.tween_property(notch, "position:y", notch_y, 0.55).set_delay(0.15).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	for orbit in [_orbit_back, _orbit_front]:
		orbit.modulate.a = 0.0
		create_tween().tween_property(orbit, "modulate:a", 1.0, 1.2).set_delay(0.3)


## The footer's status light blinks softly like a ship console indicator.
func _pulse_status_light() -> void:
	var tween := create_tween().set_loops()
	tween.tween_property(_status_light, "modulate:a", 0.25, 1.1).set_trans(Tween.TRANS_SINE)
	tween.tween_property(_status_light, "modulate:a", 1.0, 1.1).set_trans(Tween.TRANS_SINE)
