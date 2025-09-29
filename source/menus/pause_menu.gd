class_name PauseMenu extends PanelContainer

@onready var music_volume: VolumeChanger = %MusicVolume
@onready var sfx_volume: VolumeChanger = %SFXVolume
@onready var fullscreen_toggle: CheckBox = %FullscreenToggle
@onready var close_button: TextureButton = %Close


func _ready() -> void:
	# responsive sizing
	_resize()
	get_tree().get_root().size_changed.connect(_resize)

	# set initial values
	music_volume.level = floor(UserSettingsManager.music_volume * 10)
	sfx_volume.level = floor(UserSettingsManager.sfx_volume * 10)
	fullscreen_toggle.button_pressed = UserSettingsManager.fullscreen

	# callbacks
	music_volume.on_volume_changed.connect(_music_volume_changed)
	sfx_volume.on_volume_changed.connect(_sfx_volume_changed)
	fullscreen_toggle.pressed.connect(_fullscreen_toggled)
	close_button.pressed.connect(_close_settings)


func _resize() -> void:
	var screen_size = get_viewport().size as Vector2
	var scale_mult = screen_size.x / 1920.0

	if screen_size.y / 1080.0 < scale_mult:
		scale_mult = screen_size.y / 1080.0

	scale = Vector2(scale_mult, scale_mult)
	size = screen_size * 0.8
	position = screen_size / 2 - size * scale / 2


func _music_volume_changed(new_volume: int) -> void:
	UserSettingsManager.update_music_volume((new_volume as float) / 10.0)


func _sfx_volume_changed(new_volume: int) -> void:
	UserSettingsManager.update_sfx_volume((new_volume as float) / 10.0)


func _fullscreen_toggled() -> void:
	UserSettingsManager.fullscreen = !UserSettingsManager.fullscreen


func _close_settings() -> void:
	hide()
