extends Node

## Persists the player's favorited packs (by folder path) so the draft screen
## can surface them at the top and remember them across sessions.

signal favorites_changed

const SAVE_PATH: String = "user://favorites.cfg"

var _favorites: Dictionary = {}
var _config := ConfigFile.new()


func _ready() -> void:
	_config.load(SAVE_PATH)
	var stored: Array = _config.get_value("favorites", "paths", [])
	for path in stored:
		_favorites[path] = true


func is_favorite(folder_path: String) -> bool:
	return _favorites.has(folder_path)


func toggle(folder_path: String) -> void:
	if _favorites.has(folder_path):
		_favorites.erase(folder_path)
	else:
		_favorites[folder_path] = true

	_save()
	self.favorites_changed.emit()


func favorite_paths() -> Array:
	return _favorites.keys()


func _save() -> void:
	_config.set_value("favorites", "paths", _favorites.keys())
	var error := _config.save(SAVE_PATH)
	if error != OK:
		push_error("FavoritesManager: failed to write %s (error %d)" % [SAVE_PATH, error])
