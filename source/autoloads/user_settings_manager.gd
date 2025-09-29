extends Node

signal music_volume_updated
signal sfx_volume_updated

const SAVE_PATH = "user://settings.cfg"
const DB_LOWER_LIMIT: int = 30

var config := ConfigFile.new()

# settings
var music_volume: float = 0.7
var sfx_volume: float = 0.7
var fullscreen: bool = false

# updater
var latest_version: String = ""


func _ready() -> void:
	config.load(SAVE_PATH)

	_load_config()

	_save_config()


func update_music_volume(new_volume: float) -> void:
	music_volume = _clean_volume(new_volume)
	_save_config()
	self.music_volume_updated.emit()


func update_sfx_volume(new_volume: float) -> void:
	sfx_volume = _clean_volume(new_volume)
	_save_config()
	self.sfx_volume_updated.emit()


func update_fullscreen(new_value: bool) -> void:
	fullscreen = new_value
	_apply_fullscreen_setting()
	_save_config()


func update_latest_version(new_value: String) -> void:
	latest_version = new_value
	_save_config()


func volume_to_db(input_volume: float) -> int:
	# volume: 0.0 - 1.0

	if input_volume == 0.0:
		return -100

	# audio range is -60db to 0db
	return floor((input_volume * DB_LOWER_LIMIT as float) - DB_LOWER_LIMIT as float)


func db_to_volume(input_db: int) -> float:
	if input_db == -100:
		return 0.0

	# audio range is -60db to 0db
	# we multiply by 600 and divide by 10 to get a value in the tenths place
	# the min fn is a probably unnecessary precaution to avoid a 1.1 result
	return min(floor((input_db + DB_LOWER_LIMIT) * DB_LOWER_LIMIT * 10) / 10.0, 1.0)


func reload_config() -> void:
	_load_config()


func _load_config() -> void:
	if config.has_section("settings"):
		music_volume = config.get_value("settings", "music_volume", 0.7)
		self.music_volume_updated.emit()

		sfx_volume = config.get_value("settings", "sfx_volume", 0.7)
		self.sfx_volume_updated.emit()

		fullscreen = config.get_value("settings", "fullscreen", false)
		_apply_fullscreen_setting()

	if config.has_section("updater"):
		latest_version = config.get_value("updater", "latest_version", "")


func _save_config() -> void:
	# Settings
	config.set_value("settings", "music_volume", music_volume)
	config.set_value("settings", "sfx_volume", sfx_volume)
	config.set_value("settings", "fullscreen", fullscreen)

	# Updater
	config.set_value("updater", "latest_version", latest_version)

	config.save(SAVE_PATH)


func _apply_fullscreen_setting() -> void:
	if fullscreen:
		get_window().set_mode(Window.MODE_FULLSCREEN)
	else:
		get_window().set_mode(Window.MODE_WINDOWED)


func _clean_volume(input_volume: float) -> float:
	var clean_volume = input_volume

	if clean_volume > 1.0:
		clean_volume = 1.0

	if clean_volume < 0.0:
		clean_volume = 0.0

	clean_volume = floor(clean_volume * 10.0) / 10.0

	return clean_volume
