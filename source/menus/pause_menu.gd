class_name PauseMenu extends PopupContainer

@onready var music_volume: VolumeChanger = %MusicVolume
@onready var sfx_volume: VolumeChanger = %SFXVolume
@onready var fullscreen_toggle: CheckBox = %FullscreenToggle


func _ready() -> void:
	super._ready()

	# set initial values
	music_volume.set_level(floor(UserSettingsManager.music_volume * 10))
	sfx_volume.set_level(floor(UserSettingsManager.sfx_volume * 10))
	fullscreen_toggle.button_pressed = UserSettingsManager.fullscreen

	# callbacks
	music_volume.on_volume_changed.connect(_music_volume_changed)
	sfx_volume.on_volume_changed.connect(_sfx_volume_changed)
	fullscreen_toggle.pressed.connect(_fullscreen_toggled)


func _music_volume_changed(new_volume: int) -> void:
	UserSettingsManager.update_music_volume((new_volume as float) / 10.0)


func _sfx_volume_changed(new_volume: int) -> void:
	UserSettingsManager.update_sfx_volume((new_volume as float) / 10.0)


func _fullscreen_toggled() -> void:
	UserSettingsManager.update_fullscreen(!UserSettingsManager.fullscreen)
