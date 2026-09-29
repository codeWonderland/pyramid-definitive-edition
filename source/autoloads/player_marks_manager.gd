extends Node

## The player's own notes on each game - owned, never draft, avoid on stream and
## so on - kept per pack folder so they survive across sessions. Favourite is one
## of the marks, but stays stored by FavoritesManager so the draft screen's
## hearts and the library always agree.

signal marks_changed(folder_path: String)

const SAVE_PATH: String = "user://player_marks.cfg"
const FAVORITE: String = "favorite"

## Every mark a player can set, in display order.
const MARKS: Array[Dictionary] = [
	{"id": "owned", "label": "Owned"},
	{"id": "dont_own", "label": "Don't own"},
	{"id": "include_anyway", "label": "Want to include anyway"},
	{"id": "never_draft", "label": "Never draft"},
	{"id": FAVORITE, "label": "Favorite"},
	{"id": "avoid_on_stream", "label": "Avoid on stream"},
	{"id": "too_long", "label": "Too long"},
	{"id": "multiplayer_only", "label": "Multiplayer only"},
	{"id": "controller_friendly", "label": "Controller friendly"},
	{"id": "free_game", "label": "Free game"},
]

## Marks that contradict each other: setting one clears the other.
const EXCLUSIVE: Dictionary = {"owned": "dont_own", "dont_own": "owned"}

# folder path -> { mark id: true }
var _marks: Dictionary = {}
var _config := ConfigFile.new()


func _ready() -> void:
	_config.load(SAVE_PATH)
	var stored = _config.get_value("marks", "packs", {})
	if not (stored is Dictionary):
		return

	for folder_path in stored:
		if not (stored[folder_path] is Array):
			continue
		var pack_marks := {}
		for mark in stored[folder_path]:
			if mark is String and _is_known(mark) and mark != FAVORITE:
				pack_marks[mark] = true
		if not pack_marks.is_empty():
			_marks[folder_path] = pack_marks


func has_mark(folder_path: String, mark: String) -> bool:
	if mark == FAVORITE:
		return FavoritesManager.is_favorite(folder_path)
	return _marks.get(folder_path, {}).has(mark)


func set_mark(folder_path: String, mark: String, on: bool) -> void:
	if not _is_known(mark) or has_mark(folder_path, mark) == on:
		return

	if mark == FAVORITE:
		FavoritesManager.toggle(folder_path)
		self.marks_changed.emit(folder_path)
		return

	var pack_marks: Dictionary = _marks.get(folder_path, {})
	if on:
		pack_marks[mark] = true
		if EXCLUSIVE.has(mark):
			pack_marks.erase(EXCLUSIVE[mark])
	else:
		pack_marks.erase(mark)

	if pack_marks.is_empty():
		_marks.erase(folder_path)
	else:
		_marks[folder_path] = pack_marks

	_save()
	self.marks_changed.emit(folder_path)


## Every mark set on a pack, in display order.
func marks_for(folder_path: String) -> Array[String]:
	var pack_marks: Array[String] = []
	for mark in MARKS:
		if has_mark(folder_path, mark["id"]):
			pack_marks.append(mark["id"])
	return pack_marks


func _is_known(mark: String) -> bool:
	for known in MARKS:
		if known["id"] == mark:
			return true
	return false


func _save() -> void:
	var stored := {}
	for folder_path in _marks:
		stored[folder_path] = _marks[folder_path].keys()

	_config.set_value("marks", "packs", stored)
	var error := _config.save(SAVE_PATH)
	if error != OK:
		push_error("PlayerMarksManager: failed to write %s (error %d)" % [SAVE_PATH, error])
