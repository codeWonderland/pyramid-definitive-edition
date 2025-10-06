class_name PauseMenu extends PopupContainer

@onready var _music_volume: VolumeChanger = %MusicVolume
@onready var _sfx_volume: VolumeChanger = %SFXVolume
@onready var _background_select: OptionButton = %BackgroundSelect
@onready var _fullscreen_toggle: CheckBox = %FullscreenToggle
@onready var _offical_mods_button: Button = %OfficialMods
@onready var _local_mods_button: Button = %LocalMods


func _ready() -> void:
	super._ready()

	# set initial values
	_music_volume.set_level(floor(UserSettingsManager.music_volume * 10))
	_sfx_volume.set_level(floor(UserSettingsManager.sfx_volume * 10))
	_fullscreen_toggle.button_pressed = UserSettingsManager.fullscreen
	_setup_background_options()

	# callbacks
	_music_volume.on_volume_changed.connect(_music_volume_changed)
	_sfx_volume.on_volume_changed.connect(_sfx_volume_changed)
	_background_select.item_selected.connect(_on_background_selected)
	_fullscreen_toggle.pressed.connect(_fullscreen_toggled)
	_offical_mods_button.pressed.connect(_open_official_mods)
	_local_mods_button.pressed.connect(_open_mod_manager)


func _music_volume_changed(new_volume: int) -> void:
	UserSettingsManager.update_music_volume((new_volume as float) / 10.0)


func _sfx_volume_changed(new_volume: int) -> void:
	UserSettingsManager.update_sfx_volume((new_volume as float) / 10.0)


func _fullscreen_toggled() -> void:
	UserSettingsManager.update_fullscreen(!UserSettingsManager.fullscreen)


func _setup_background_options() -> void:
	var current_background_index = 0

	var current_index = 0
	for background_name in BackgroundManager.backgrounds.keys():
		_background_select.add_item(background_name)

		if background_name == UserSettingsManager.background:
			current_background_index = current_index

		current_index += 1

	_background_select.select(current_background_index)


func _on_background_selected(background_index: int) -> void:
	var image_name = _background_select.get_item_text(background_index)
	UserSettingsManager.update_background(image_name)


func _open_official_mods() -> void:
	OS.shell_open("https://github.com/codeWonderland/pyramid-mods")


func _open_mod_manager() -> void:
	var local_mods_folder = ProjectSettings.globalize_path(PackLoader.LOCAL_PACKS_FOLDER_PATH)
	var err = OS.shell_open(local_mods_folder)
