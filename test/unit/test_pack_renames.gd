extends GutTest

# Tests following an official pack that the mods renamed (renames.json): saves,
# favorites and marks remember packs by folder, so they're pointed at the new one.

const OFFICIAL: String = PacksManager.PACKS_FOLDER_PATH

var _root: String
var _saved_renames: Variant


func before_each() -> void:
	_root = "user://test_renames_%d" % randi()
	DirAccess.make_dir_recursive_absolute(_root)
	_saved_renames = PacksManager._renames


func after_each() -> void:
	PacksManager._renames = _saved_renames
	ModsSync.clear(_root)


func _write(text: String) -> String:
	var path := _root.path_join("renames.json")
	FileAccess.open(path, FileAccess.WRITE).store_string(text)
	return path


func test_renames_are_read_from_the_mods() -> void:
	var path := _write('{"renames": {"monolith": "star of providence", "bad": 3}}')

	assert_eq(PacksManager.load_renames(path), {"monolith": "star of providence"}, "junk skipped")
	assert_eq(PacksManager.load_renames(_root.path_join("missing.json")), {}, "none")


func test_a_broken_renames_file_means_no_renames() -> void:
	assert_eq(PacksManager.load_renames(_write("[1, 2]")), {})
	assert_push_warning("has no renames")


func test_a_renamed_pack_is_found_under_its_new_name() -> void:
	PacksManager._renames = {"monolith": "star of providence"}

	assert_eq(PacksManager.current_path(OFFICIAL + "monolith"), OFFICIAL + "star of providence")
	assert_eq(
		PacksManager.current_path(OFFICIAL + "hades"), OFFICIAL + "hades", "others as they are"
	)
	assert_eq(
		PacksManager.current_path("user://mods/local/PACKS/monolith"),
		"user://mods/local/PACKS/monolith",
		"a player's own pack is never renamed"
	)


func test_renames_chain_and_a_loop_stops() -> void:
	PacksManager._renames = {"a": "b", "b": "c", "x": "y", "y": "x"}

	assert_eq(PacksManager.current_path(OFFICIAL + "a"), OFFICIAL + "c", "a rename of a rename")
	assert_true(PacksManager.current_path(OFFICIAL + "x").begins_with(OFFICIAL), "no hang")


func test_favorites_follow_a_rename() -> void:
	var old_path := OFFICIAL + "__test_old_%d" % randi()
	var new_path := OFFICIAL + "__test_new_%d" % randi()
	FavoritesManager.toggle(old_path)

	FavoritesManager.migrate(
		func(path: String) -> String: return new_path if path == old_path else path
	)

	assert_false(FavoritesManager.is_favorite(old_path), "not under the old folder")
	assert_true(FavoritesManager.is_favorite(new_path), "under the new one")
	FavoritesManager.toggle(new_path)


func test_marks_follow_a_rename_and_merge() -> void:
	var old_path := OFFICIAL + "__test_old_%d" % randi()
	var new_path := OFFICIAL + "__test_new_%d" % randi()
	PlayerMarksManager.set_mark(old_path, "owned", true)
	PlayerMarksManager.set_mark(new_path, "too_long", true)

	PlayerMarksManager.migrate(
		func(path: String) -> String: return new_path if path == old_path else path
	)

	assert_false(PlayerMarksManager.has_mark(old_path, "owned"), "moved away")
	assert_true(PlayerMarksManager.has_mark(new_path, "owned"), "moved here")
	assert_true(PlayerMarksManager.has_mark(new_path, "too_long"), "and kept what was there")
	PlayerMarksManager.set_mark(new_path, "owned", false)
	PlayerMarksManager.set_mark(new_path, "too_long", false)
