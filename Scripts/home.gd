extends Node2D

## Home screen: Echo's view from orbit. A breathing planet with Echo's ship
## circling it, and a minimal menu on the left. The ship also holds the daily
## transmission from Earth: it glows while one is waiting, opens the card when
## tapped on the near side of Umbra, and the card opens by itself once a day.

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
const SHIP_TAP_SIZE: float = 96.0
## The daily card opens by itself this long after the Home screen appears.
const DAILY_CARD_DELAY: float = 1.0

## Quiet looping background music (Assets/Music/umbra_ambient.wav, mixed
## soft already). Fades in on arrival and out on Descend.
const AMBIENT_MUSIC: AudioStream = preload("res://Assets/Music/umbra_ambient.wav")
const AMBIENT_VOLUME_DB: float = -3.0
const AMBIENT_FADE_IN: float = 3.0

const INTRO_STAGGER: float = 0.06

## Claimed Echoes: an Echoes icon pops up where the amount was shown, speeds
## into the counter, and the counter counts up when it lands (collect_echoes).
const ECHO_ICON: Texture2D = preload("res://Assets/HUD Elements/echoe_icon.svg")
const FLY_ICON_SIZE: float = 60.0
const FLY_POP_TIME: float = 0.22
const FLY_HOLD_TIME: float = 0.12
const FLY_TIME: float = 0.65
const FLY_ARC: float = 70.0
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
## Invisible tap target that follows the ship (while it is in front of Umbra).
var _ship_btn: Control = null
var _ship_ready: bool = false
var _ship_pop: float = 0.0
var _ship_check: float = 0.0   # seconds until the waiting state is checked again (midnight)
var _planet_radius: float = 0.0   # on screen, for whether Umbra hides the ship
var _account_prompt_pending: bool = false
## The counter shows Echoes owned minus those still flying in.
var _echoes_shown: int = 0
var _echoes_in_flight: int = 0
var _count_tween: Tween = null
var _fly_layer: CanvasLayer = null   # above the whole UI, for the flying icons
## Red dot beside Achievements while a completed one waits to be claimed.
var _achievements_dot: NotifyDot = null


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

	add_to_group(&"home_screen")   # claim screens find collect_echoes() through it
	_set_echoes_shown(MetaProgression.echoes)
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

	_ship_btn = Control.new()
	_ship_btn.name = "ShipTap"
	_ship_btn.size = Vector2(SHIP_TAP_SIZE, SHIP_TAP_SIZE)
	_ship_btn.gui_input.connect(_on_ship_input)
	$UI.add_child(_ship_btn)
	$UI.move_child(_ship_btn, 0)   # under the menu, which lets touches through
	MetaProgression.daily_reward_changed.connect(_refresh_ship)
	_refresh_ship()

	_achievements_dot = NotifyDot.new()
	_achievements_dot.name = "NotifyDot"
	_achievements_btn.get_node("Margin/HBox/Label").add_child(_achievements_dot)
	AchievementManager.achievement_completed.connect(_refresh_achievements_dot.unbind(1))
	AchievementManager.achievement_claimed.connect(_refresh_achievements_dot.unbind(1))
	_refresh_achievements_dot.call_deferred()   # after the label has its size

	_start_ambient()
	_play_intro()
	_pulse_status_light()
	_maybe_prompt_account()
	_maybe_show_daily_reward()


func _process(delta: float) -> void:
	_time += delta

	# Planet breathing: a slow float up and down, with the glow following.
	var offset_y: float = sin(TAU * _time / BREATHE_PERIOD) * BG_PLANET_PEAK_OFFSET
	planetSprite.position = _planet_rest_position + Vector2(0.0, offset_y)
	_planet_glow.position = planetSprite.position

	# Echo's ship circling the planet.
	var ship_angle: float = _ship_angle()
	_ship_check -= delta
	if _ship_check <= 0.0:
		_refresh_ship()   # a new day may have begun
	for orbit in [_orbit_back, _orbit_front]:
		orbit.center = planetSprite.position
		orbit.ship_angle = ship_angle
		orbit.ship_ready = _ship_ready
		orbit.ship_time = _time
		orbit.ship_pop = _ship_pop
		orbit.queue_redraw()
	# Tappable whenever it can be seen: not while Umbra's disc hides it.
	var ship_at: Vector2 = _orbit_front.point_at(ship_angle)
	_ship_btn.position = ship_at - _ship_btn.size * 0.5
	_ship_btn.visible = _menu.visible and not _ship_hidden(ship_angle, ship_at)


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
	_planet_radius = diameter * 0.5
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


## Shows the dot while an achievement waits to be claimed, just past the
## end of the word ACHIEVEMENTS.
func _refresh_achievements_dot() -> void:
	var label: Label = _achievements_dot.get_parent()
	# The label's own text width (it uses LabelSettings, not the theme font).
	var text_width: float = label.get_minimum_size().x
	_achievements_dot.position = Vector2(text_width + 4.0, (label.size.y - _achievements_dot.size.y) * 0.5)
	_achievements_dot.visible = AchievementManager.has_unclaimed()


func _on_echoes_changed(_total: int) -> void:
	_sync_echoes(false)   # spending shows at once; claims hold theirs back while they fly


# --- Claimed Echoes flying into the counter -----------------------------------

## Call when `amount` Echoes are claimed from something shown at `from` (a
## point on screen), before or right after MetaProgression adds them. The
## counter keeps them back until the icon lands, then counts up.
func collect_echoes(from: Vector2, amount: int) -> void:
	hold_echoes(amount)
	fly_echoes(from, amount)


## Keeps `amount` just-added Echoes off the counter until fly_echoes() sends
## them in (e.g. an ad paid out while still covering the screen).
func hold_echoes(amount: int) -> void:
	if amount <= 0:
		return
	_echoes_in_flight += amount
	_sync_echoes(false)


## Sends `amount` held Echoes into the counter as an icon from `from`, after
## `delay` seconds.
func fly_echoes(from: Vector2, amount: int, delay: float = 0.0) -> void:
	if amount <= 0:
		return
	# On its own layer above the whole UI, so no list or card can cover it, and
	# starting on screen even if what it came from is scrolled half out of view.
	if _fly_layer == null:
		_fly_layer = CanvasLayer.new()
		_fly_layer.name = "FlyingEchoes"
		_fly_layer.layer = $UI.layer + 1
		add_child(_fly_layer)
	var screen := Rect2(Vector2.ZERO, get_viewport_rect().size).grow(-FLY_ICON_SIZE * 0.6)
	from = from.clamp(screen.position, screen.end)

	var flier := preload("res://Scripts/flying_echo.gd").new()
	flier.texture = ECHO_ICON
	flier.icon_size = FLY_ICON_SIZE
	flier.move_to(from, 0.0)
	_fly_layer.add_child(flier)

	var target_icon: Control = _echoes_counter.get_node(^"HBox/Icon")
	var tween := create_tween()
	if delay > 0.0:
		tween.tween_interval(delay)
	# Lift the counter above any open card's backdrop so the landing is seen.
	tween.tween_callback(func(): $UI.move_child(_echoes_counter, _fade.get_index()))
	# Pops into being...
	tween.tween_method(func(s: float): flier.move_to(from, s), 0.0, 1.25, FLY_POP_TIME * 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_method(func(s: float): flier.move_to(from, s), 1.25, 1.0, FLY_POP_TIME * 0.4)
	tween.tween_interval(FLY_HOLD_TIME)
	tween.tween_callback(func(): flier.trailing = true)
	# ...then speeds up into the counter along a slight arc, shrinking to its icon.
	tween.tween_method(func(t: float):
		var to: Vector2 = target_icon.get_global_rect().get_center()
		var along: float = t * t   # steady acceleration: no big jumps at the end
		var path: Vector2 = from.lerp(to, along)
		var side: Vector2 = (to - from).orthogonal().normalized()
		path += side * FLY_ARC * sin(PI * along)
		flier.move_to(path, lerpf(1.0, target_icon.size.y / FLY_ICON_SIZE, along))
	, 0.0, 1.0, FLY_TIME)
	tween.tween_callback(func():
		flier.queue_free()
		_echoes_in_flight = maxi(_echoes_in_flight - amount, 0)
		_sync_echoes(true)
		_flash(_echoes_counter)
		_echoes_value.pivot_offset = _echoes_value.size * 0.5
		var bump := create_tween()
		bump.tween_property(_echoes_value, "scale", Vector2.ONE * 1.3, 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		bump.tween_property(_echoes_value, "scale", Vector2.ONE, 0.3)
	)


## Brings the counter to Echoes owned minus those still flying: counting up
## if `animate` and it grows, otherwise at once.
func _sync_echoes(animate: bool) -> void:
	var target: int = MetaProgression.echoes - _echoes_in_flight
	if _count_tween:
		_count_tween.kill()
		_count_tween = null
	if not animate or target <= _echoes_shown:
		_set_echoes_shown(target)
		return
	var time: float = clampf(0.4 + 0.004 * (target - _echoes_shown), 0.4, 1.1)
	_count_tween = create_tween()
	_count_tween.tween_method(func(v: float): _set_echoes_shown(roundi(v)), float(_echoes_shown), float(target), time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _set_echoes_shown(value: int) -> void:
	_echoes_shown = value
	_echoes_value.text = str(value)


func _show_profile() -> void:
	_profile_avatar.avatar = PlayerProfile.avatar
	_profile_name.text = PlayerProfile.username
	_profile_id.text = "ID  " + PlayerProfile.player_id


# --- Daily transmission (Echo's ship) -----------------------------------------

func _ship_angle() -> float:
	return TAU * _time / SHIP_ORBIT_PERIOD


## True while Umbra hides the ship: on the far half of its orbit and inside
## the planet's disc as seen on screen.
func _ship_hidden(angle: float, at: Vector2) -> bool:
	if _orbit_front.is_near_side(angle):
		return false
	return at.distance_squared_to(planetSprite.position) < _planet_radius * _planet_radius


## Where Echo's ship is on screen now (the daily card flies into it).
func ship_position() -> Vector2:
	return _orbit_front.point_at(_ship_angle())


## The daily card has flown back in: a little flash so the eye lands on it.
func ship_received() -> void:
	create_tween().tween_property(self, "_ship_pop", 1.0, 0.4).from(0.0)


func _refresh_ship() -> void:
	_ship_ready = MetaProgression.can_claim_daily_reward()
	_ship_check = 1.0


func _on_ship_input(event: InputEvent) -> void:
	if _is_leaving:
		return
	if Tap.is_tap(_ship_btn, event):
		play_ui_sfx()
		open_daily_reward()


func open_daily_reward() -> void:
	_show_popup(preload("res://Scenes/HUD/daily_reward_card.tscn").instantiate())


## Once a day, while today's reward is waiting, the card opens by itself a
## moment after the Home screen appears (not over the account prompt).
func _maybe_show_daily_reward() -> void:
	await get_tree().create_timer(DAILY_CARD_DELAY).timeout
	if _is_leaving or _account_prompt_pending:
		return
	if MetaProgression.should_show_daily_reward():
		open_daily_reward()


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
	_account_prompt_pending = true   # the daily card waits for another visit
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
		_refresh_achievements_dot()   # claims made on the sub screen
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
