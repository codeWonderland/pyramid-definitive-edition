extends Node

signal packs_loaded

const PACKS_FOLDER_PATH: String = "user://mods/pyramid-mods-main/PACKS/"
const LOCAL_PACKS_FOLDER_PATH: String = "user://mods/local/PACKS/"

var all_packs: Array[PackData]


func _ready() -> void:
	var local_packs_folder = DirAccess.open(LOCAL_PACKS_FOLDER_PATH)

	if !local_packs_folder:
		DirAccess.make_dir_recursive_absolute(LOCAL_PACKS_FOLDER_PATH)


func load() -> void:
	all_packs = []

	var tree = get_tree()

	all_packs += await PackDataLoader.load_packs_from_folder(PACKS_FOLDER_PATH, tree)
	all_packs += await PackDataLoader.load_packs_from_folder(LOCAL_PACKS_FOLDER_PATH, tree)

	all_packs.sort_custom(PackDataLoader.sort_packs)

	self.packs_loaded.emit()


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
