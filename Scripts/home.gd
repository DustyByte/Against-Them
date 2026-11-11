extends Node2D

const BACKGROUND_IMAGE_DIMENSION: Vector2 = Vector2(1024.0, 1024.0)
const DISCORD_LINK: String = "https://discord.gg/zjXPsKS2"
const BG_PLANET_PEAK_OFFSET: float = 17.0
 
@export var vbox_width_ratio: float = 0.5
@export var vbox_height_ratio: float = 0.5
@export var vbox_separation: int = 12

@onready var _descend_btn: Panel = $CanvasLayer/VBoxContainer/Descend
@onready var _quit_btn: Panel = $CanvasLayer/VBoxContainer/Quit
@onready var _discord_btn: Panel = $CanvasLayer/VBoxContainer/Discord
@onready var _settings_btn: Panel = $CanvasLayer/VBoxContainer/Settings
@onready var _achievements_btn: Panel = $CanvasLayer/VBoxContainer/Achievements
@onready var _echoes_value: Label = $CanvasLayer/VBoxContainer/Vault/HBoxContainer/EchoesValue
@onready var planetSprite: Sprite2D = $Planet
@onready var UIPressAS: AudioStreamPlayer = $AudioStreamPlayer

var bgPlanetInitPosY: float = NAN
var bgPlanetInitScale: Vector2


func _bg_planet_animation() -> void:
	create_tween().tween_method(func(x: float):
		var offsetY: float = sin(PI * 0.5 + TAU * x) * BG_PLANET_PEAK_OFFSET
		planetSprite.position.y = bgPlanetInitPosY + offsetY
	, 0.0, 1.0, 5.0).finished.connect(_bg_planet_animation)

func _ready() -> void:
	bgPlanetInitScale = planetSprite.scale
	get_viewport().size_changed.connect(Callable(self, "_update_layout"))
	_update_layout()
	bgPlanetInitPosY = planetSprite.position.y
	
	global.SFX_TYPES_PERM["ui"] = SettingsManager.settings.ui_sfx
	global.SFX_TYPES_PERM["game_world"] = SettingsManager.settings.game_world_sfx

	_echoes_value.text = str(MetaProgression.echoes)
	MetaProgression.echoes_changed.connect(_on_echoes_changed)

	_bg_planet_animation()
	
	_descend_btn.gui_input.connect(_check_if_touch_then_execute.bind(_on_descend_pressed))
	_quit_btn.gui_input.connect(_check_if_touch_then_execute.bind(get_tree().quit))
	_discord_btn.gui_input.connect(_check_if_touch_then_execute.bind(OS.shell_open.bind(DISCORD_LINK)))
	_settings_btn.gui_input.connect(_check_if_touch_then_execute.bind(_on_settings_pressed))
	_achievements_btn.gui_input.connect(_check_if_touch_then_execute.bind(_on_achievements_pressed))

func _check_if_touch_then_execute(event: InputEvent, functionToExecute: Callable):
	if event is InputEventScreenTouch and event.is_pressed():
		play_ui_sfx()
		functionToExecute.call()

func play_ui_sfx() -> void:
	if global.SFX_TYPES_PERM["ui"]:
		UIPressAS.pitch_scale = randf_range(0.7, 1.3)
		UIPressAS.play()

func _on_echoes_changed(total: int) -> void:
	_echoes_value.text = str(total)

func _update_layout() -> void:
	var windowDim: Vector2 = get_viewport_rect().size
	$ABlackImage.scale = windowDim / BACKGROUND_IMAGE_DIMENSION
	$ABlackImage.position = windowDim * 0.5
	
	var vbox: VBoxContainer = $CanvasLayer/VBoxContainer
	vbox.size.x = windowDim.x * vbox_width_ratio
	vbox.position = (windowDim - vbox.size) * 0.5
	
	planetSprite.position = Vector2(windowDim.x * 0.5, windowDim.y * 0.6)
	planetSprite.scale = bgPlanetInitScale * windowDim.y / 900.0 # 900.0 is a reference I took. Now, the planet size is absolute.

func _on_settings_pressed() -> void:
	$CanvasLayer/VBoxContainer.visible = false
	
	var settings: Control = preload("res://Scenes/HUD/settings.tscn").instantiate()
	settings.returnPressed.connect(func():
		$CanvasLayer/VBoxContainer.visible = true
		settings.queue_free()
	)
	
	$CanvasLayer.add_child(settings)

func _on_achievements_pressed() -> void:
	$CanvasLayer/VBoxContainer.visible = false

	var achievements: Control = preload("res://Scenes/HUD/achievements.tscn").instantiate()
	achievements.returnPressed.connect(func():
		$CanvasLayer/VBoxContainer.visible = true
		achievements.queue_free()
	)

	$CanvasLayer.add_child(achievements)

func _on_descend_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/world.tscn")
