extends Node

signal packs_loaded

const PACKS_FOLDER_PATH: String = "user://mods/pyramid-mods-main/PACKS/"
const LOCAL_PACKS_FOLDER_PATH: String = "user://mods/local/PACKS/"
const CATEGORIES_PATH: String = "user://mods/pyramid-mods-main/categories.json"
## Official packs the mods have renamed: {"renames": {"old folder": "new folder"}}.
const RENAMES_PATH: String = "user://mods/pyramid-mods-main/renames.json"

var all_packs: Array[PackData]
# Category descriptions keyed by lowercased name, for explaining a filter.
var _category_descriptions: Dictionary = {}
# Old official pack folder -> new, read on first use; null until then.
var _renames: Variant = null


func _ready() -> void:
	var local_packs_folder = DirAccess.open(LOCAL_PACKS_FOLDER_PATH)

	if !local_packs_folder:
		DirAccess.make_dir_recursive_absolute(LOCAL_PACKS_FOLDER_PATH)


func load() -> void:
	all_packs = []

	var tree = get_tree()

	all_packs += await PackDataLoader.load_packs_from_folder(PACKS_FOLDER_PATH, tree)
	all_packs += await PackDataLoader.load_packs_from_folder(LOCAL_PACKS_FOLDER_PATH, tree)
	# Workshop items each hold one pack folder, in Steam's own download location.
	for item_folder in SteamWorkshop.installed_item_folders():
		all_packs += await PackDataLoader.load_packs_from_folder(item_folder + "/", tree)

	all_packs.sort_custom(PackDataLoader.sort_packs)
	load_categories(CATEGORIES_PATH)

	# The mods may have just been updated with new renames.
	_renames = null
	FavoritesManager.migrate(current_path)
	PlayerMarksManager.migrate(current_path)

	self.packs_loaded.emit()


## Where a pack's folder path points now. Saves, favorites and marks remember a
## pack by its folder, so when the official mods rename one they go through this
## to find it again. Paths outside the official packs are returned as they are.
func current_path(path: String) -> String:
	if not path.begins_with(PACKS_FOLDER_PATH):
		return path

	if _renames == null:
		_renames = load_renames(RENAMES_PATH)

	var folder := path.trim_prefix(PACKS_FOLDER_PATH)
	var seen := {}
	# Follows a rename of a rename, and stops on a loop rather than spinning.
	while _renames.has(folder) and not seen.has(folder):
		seen[folder] = true
		folder = _renames[folder]
	return PACKS_FOLDER_PATH + folder


## Reads a renames file into old folder -> new folder. Optional mod data, so a
## missing or malformed file means no renames.
static func load_renames(path: String) -> Dictionary:
	var renames := {}
	if not FileAccess.file_exists(path):
		return renames

	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (data is Dictionary and data.get("renames") is Dictionary):
		push_warning("PacksManager: %s has no renames" % path)
		return renames

	for old_folder in data["renames"]:
		var new_folder = data["renames"][old_folder]
		if old_folder is String and new_folder is String and not new_folder.is_empty():
			renames[old_folder] = new_folder
	return renames


## Reads the category definitions shipped with the mods. Optional mod data, so a
## missing or malformed file just leaves filters without descriptions.
func load_categories(path: String) -> void:
	_category_descriptions = {}

	if not FileAccess.file_exists(path):
		return

	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		push_warning("PacksManager: %s is not valid JSON" % path)
		return

	if not (json.data is Dictionary and json.data.get("categories") is Array):
		push_warning("PacksManager: %s has no categories list" % path)
		return

	for entry in json.data["categories"]:
		if not (entry is Dictionary):
			continue
		var category_name = entry.get("name")
		var description = entry.get("description")
		if category_name is String and description is String:
			_category_descriptions[category_name.to_lower()] = description


## What a category means, or "" if the mods don't describe it. Matched
## case-insensitively, like the tags themselves.
func category_description(category: String) -> String:
	return _category_descriptions.get(category.to_lower(), "")


## Every distinct tag declared by the loaded packs, for building filter lists.
## De-duplicated case-insensitively (keeping the first spelling seen) and sorted
## so the filter panel's checkbox order is stable between runs.
func all_tags() -> Array[String]:
	var seen := {}
	var tags: Array[String] = []

	for pack in all_packs:
		for tag in pack.tags:
			var key := tag.to_lower()
			if seen.has(key):
				continue

			seen[key] = true
			tags.append(tag)

	tags.sort_custom(func(a: String, b: String) -> bool: return a.naturalnocasecmp_to(b) < 0)
	return tags
