extends Node

const SAVE_PATH = "user://saves.cfg"

var config := ConfigFile.new()

var _saves: Array[SaveData] = [null, null, null]


func _ready() -> void:
	config.load(SAVE_PATH)

	_load_config()

	_save_config()


func _load_config() -> void:
	if config.has_section("user_data"):
		_saves = config.get_value("user_data", "saves", [null, null, null])


func _save_config() -> void:
	if _saves[0] != null:
		config.set_value("user_data", "saves", _saves)

	config.save(SAVE_PATH)


func create_save(save_index: int, data: SaveData) -> void:
	_saves[save_index] = data
	_save_config()


func load_save(save_index: int) -> SaveData:
	return _saves[save_index]


func delete_save(save_index: int) -> void:
	create_save(save_index, null)
