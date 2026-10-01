extends Node

signal packs_loaded

const PACKS_FOLDER_PATH: String = "user://mods/pyramid-mods-main/PACKS/"
const LOCAL_PACKS_FOLDER_PATH: String = "user://mods/local/PACKS/"
const CATEGORIES_PATH: String = "user://mods/pyramid-mods-main/categories.json"

var all_packs: Array[PackData]
# Category descriptions keyed by lowercased name, for explaining a filter.
var _category_descriptions: Dictionary = {}


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

	self.packs_loaded.emit()


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
