extends GutTest

# Regression tests for ModManager._save_mod() (submodule code, exercised here
# because ModManager depends on the parent project's autoloads and base classes).
#
# Each card category used to be written by its own copy of the same loop, with a
# counter that was initialised to 1 and never advanced — so every card in a
# category wrote to the same filename and a saved pack kept only its last back,
# primary, secondary and curse.

const MOD_MANAGER: PackedScene = preload("res://source/mod-manager/mod_manager.tscn")

var _mods_root: String


func before_each() -> void:
	_mods_root = "user://test_modsave_%d/" % randi()
	DirAccess.make_dir_recursive_absolute(_mods_root)


func after_each() -> void:
	var dir = DirAccess.open(_mods_root)
	if dir:
		Helpers.delete_recursive(dir)


func _texture(fill: Color) -> ImageTexture:
	var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(fill)
	return ImageTexture.create_from_image(img)


func _textures(count: int) -> Array[ImageTexture]:
	var out: Array[ImageTexture] = []
	for i in range(count):
		out.append(_texture(Color(i / 8.0, 0.5, 0.5)))
	return out


func _manager() -> ModManager:
	var manager := MOD_MANAGER.instantiate() as ModManager
	manager.mods_path = _mods_root
	manager.scene_to_return_to = null
	add_child_autofree(manager)
	await get_tree().process_frame
	return manager


func _pack(backs: int, primaries: int, secondaries: int, curses: int) -> PackData:
	var pack := PackData.new()
	pack.title = "Saved Pack"
	pack.folder_path = _mods_root.path_join(pack.title)
	pack.backs = _textures(backs)
	pack.primaries = _textures(primaries)
	pack.secondaries = _textures(secondaries)
	pack.curses = _textures(curses)
	return pack


func _files_in(folder: String) -> Array:
	var dir = DirAccess.open(folder)
	if dir == null:
		return []
	var files := Array(dir.get_files())
	files.sort()
	return files


func test_every_primary_gets_its_own_file() -> void:
	var manager := await _manager()
	var pack := _pack(1, 3, 0, 0)

	manager._save_mod(pack)

	assert_eq(
		_files_in(pack.folder_path),
		["b1.png", "p1.png", "p2.png", "p3.png"],
		"three primaries write three numbered files, not one"
	)


func test_every_category_is_numbered_independently() -> void:
	var manager := await _manager()
	var pack := _pack(2, 2, 2, 2)

	manager._save_mod(pack)

	assert_eq(
		_files_in(pack.folder_path),
		["b1.png", "b2.png", "c1.png", "c2.png", "p1.png", "p2.png", "s1.png", "s2.png"],
		"each category numbers from 1 without clobbering the others"
	)


func test_saved_pack_reloads_with_every_card() -> void:
	var manager := await _manager()
	var pack := _pack(1, 4, 2, 1)

	manager._save_mod(pack)
	var reloaded := PackDataLoader.load_pack_from_path(pack.folder_path)

	assert_not_null(reloaded, "the saved pack loads back")
	assert_eq(reloaded.backs.size(), 1, "back survives")
	assert_eq(reloaded.primaries.size(), 4, "all four primaries survive the round trip")
	assert_eq(reloaded.secondaries.size(), 2, "both secondaries survive")
	assert_eq(reloaded.curses.size(), 1, "curse survives")


func test_empty_categories_write_nothing() -> void:
	var manager := await _manager()
	var pack := _pack(1, 1, 0, 0)

	manager._save_mod(pack)

	assert_eq(
		_files_in(pack.folder_path), ["b1.png", "p1.png"], "categories with no cards write no files"
	)


func test_resaving_with_fewer_cards_leaves_no_stale_files() -> void:
	var manager := await _manager()

	var big := _pack(1, 4, 0, 0)
	manager._save_mod(big)
	assert_eq(_files_in(big.folder_path).size(), 5, "four primaries written")

	var small := _pack(1, 2, 0, 0)
	manager._save_mod(small)

	assert_eq(
		_files_in(small.folder_path),
		["b1.png", "p1.png", "p2.png"],
		"the higher-numbered images from the bigger save are gone"
	)


func test_tags_are_saved_alongside_the_cards() -> void:
	var manager := await _manager()
	var pack := _pack(1, 1, 0, 0)
	pack.tags = ["Roguelike"] as Array[String]

	manager._save_mod(pack)

	assert_eq(
		PackDataLoader.load_tags(pack.folder_path), ["Roguelike"], "tags persist with the pack"
	)
