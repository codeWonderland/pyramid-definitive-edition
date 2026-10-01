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
const EXCLUSIVE: Dictionary = {
	"owned": "dont_own",
	"dont_own": "owned",
	"never_draft": "include_anyway",
	"include_anyway": "never_draft",
}

## Marks offered as filters on the draft screen. Never draft and want to include
## anyway decide whether a game is shown at all rather than narrowing the list,
## and favourites already have their own filter there.
const FILTERABLE_MARKS: Array[String] = [
	"owned",
	"dont_own",
	"avoid_on_stream",
	"too_long",
	"multiplayer_only",
	"controller_friendly",
	"free_game",
]

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


## Moves marks to where their packs are now (see PacksManager.current_path). A pack
## renamed onto one that already has marks keeps both sets.
func migrate(current_path: Callable) -> void:
	var moved := {}
	var changed := false
	for path in _marks:
		var now: String = current_path.call(path)
		changed = changed or now != path
		var merged: Dictionary = moved.get(now, {})
		merged.merge(_marks[path])
		moved[now] = merged
	if not changed:
		return

	_marks = moved
	_save()
	for path in _marks:
		self.marks_changed.emit(path)


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


## Whether the draft screen should leave a game out. Never draft hides a game
## unless the player has asked to see those; with "hide games I don't own" on,
## a game marked don't own is hidden too - unless it is also marked want to
## include anyway, which is what that mark is for.
func hidden_from_draft(
	folder_path: String, show_never_draft: bool = false, hide_unowned: bool = false
) -> bool:
	if has_mark(folder_path, "never_draft") and not show_never_draft:
		return true

	if hide_unowned and has_mark(folder_path, "dont_own"):
		return not has_mark(folder_path, "include_anyway")

	return false


func label_for(mark: String) -> String:
	for known in MARKS:
		if known["id"] == mark:
			return known["label"]
	return mark


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
