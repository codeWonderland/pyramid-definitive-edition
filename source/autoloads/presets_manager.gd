extends Node

## Saved sets of games to draft: the player's own, made from their picks on the
## draft screen, and featured ones - developer favourites, themed sets - shipped
## with the official mods. Using a preset fills the draft with its games; the
## player can still adjust them before starting.

signal presets_changed

const SAVE_PATH: String = "user://presets.cfg"
## Featured presets: {"presets": [{"name", "description", "packs": [folder names]}]}.
const FEATURED_PATH: String = "user://mods/pyramid-mods-main/presets.json"

# [{"name": String, "packs": Array of pack folder paths}], in the order saved.
var _player_presets: Array[Dictionary] = []
var _config := ConfigFile.new()


func _ready() -> void:
	_config.load(SAVE_PATH)
	var stored = _config.get_value("presets", "list", [])
	if not (stored is Array):
		return
	for entry in stored:
		var preset := _clean(entry)
		if not preset.is_empty():
			_player_presets.append(preset)


func player_presets() -> Array[Dictionary]:
	return _player_presets.duplicate(true)


## Saves `packs` as a preset called `preset_name`, replacing one of the same name
## (ignoring case). Returns false for a blank name or no packs.
func save_preset(preset_name: String, packs: Array[PackData]) -> bool:
	var clean_name := preset_name.strip_edges()
	if clean_name.is_empty() or packs.is_empty():
		return false

	var paths: Array[String] = []
	for pack in packs:
		if pack != null and not paths.has(pack.folder_path):
			paths.append(pack.folder_path)

	var preset := {"name": clean_name, "packs": paths}
	var index := _index_of(clean_name)
	if index == -1:
		_player_presets.append(preset)
	else:
		_player_presets[index] = preset
	_save()
	return true


func delete_preset(preset_name: String) -> void:
	var index := _index_of(preset_name)
	if index == -1:
		return
	_player_presets.remove_at(index)
	_save()


## The featured presets in the installed mods, with their packs as folder paths.
## Optional mod data: a missing or malformed file means none.
func featured_presets() -> Array[Dictionary]:
	return load_featured(FEATURED_PATH, PacksManager.PACKS_FOLDER_PATH)


static func load_featured(path: String, packs_folder: String) -> Array[Dictionary]:
	var featured: Array[Dictionary] = []
	if not FileAccess.file_exists(path):
		return featured

	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (data is Dictionary and data.get("presets") is Array):
		push_warning("PresetsManager: %s has no presets" % path)
		return featured

	for entry in data["presets"]:
		if not (entry is Dictionary and entry.get("packs") is Array):
			continue
		var folders: Array = []
		for folder in entry["packs"]:
			if folder is String and not folder.is_empty():
				folders.append(packs_folder + folder)
		var preset := _clean({"name": entry.get("name"), "packs": folders})
		if preset.is_empty():
			continue
		var description = entry.get("description")
		preset["description"] = description if description is String else ""
		featured.append(preset)
	return featured


## A preset's games that are installed, in its order. Packs since renamed are
## followed; ones since removed are left out.
func packs_for(preset: Dictionary) -> Array[PackData]:
	var by_path := {}
	for pack in PacksManager.all_packs:
		by_path[pack.folder_path] = pack

	var packs: Array[PackData] = []
	for path in preset.get("packs", []):
		var pack: PackData = by_path.get(PacksManager.current_path(path))
		if pack != null and not packs.has(pack):
			packs.append(pack)
	return packs


func _index_of(preset_name: String) -> int:
	var wanted := preset_name.strip_edges().to_lower()
	for i in _player_presets.size():
		if String(_player_presets[i]["name"]).to_lower() == wanted:
			return i
	return -1


## A preset with a name and at least one pack path, or {} if it isn't one.
static func _clean(entry: Variant) -> Dictionary:
	if not (entry is Dictionary):
		return {}
	var preset_name = entry.get("name")
	var packs = entry.get("packs")
	if not (preset_name is String and not preset_name.strip_edges().is_empty()):
		return {}
	if not (packs is Array):
		return {}
	var paths: Array[String] = []
	for path in packs:
		if path is String and not path.is_empty():
			paths.append(path)
	if paths.is_empty():
		return {}
	return {"name": preset_name.strip_edges(), "packs": paths}


func _save() -> void:
	_config.set_value("presets", "list", _player_presets)
	var error := _config.save(SAVE_PATH)
	if error != OK:
		push_error("PresetsManager: failed to write %s (error %d)" % [SAVE_PATH, error])
	self.presets_changed.emit()
