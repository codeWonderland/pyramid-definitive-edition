extends GutTest

# Tests for source/mod-manager PackDataLoader (submodule code).

var _tag_root: String


func test_sort_packs_orders_by_title() -> void:
	var a := PackData.new()
	a.title = "Apples"
	var b := PackData.new()
	b.title = "Bananas"

	assert_true(PackDataLoader.sort_packs(a, b), "Apples sorts before Bananas")
	assert_false(PackDataLoader.sort_packs(b, a), "Bananas does not sort before Apples")


func test_missing_pack_path_returns_null() -> void:
	var pack = PackDataLoader.load_pack_from_path("user://definitely_missing_%d" % randi())

	assert_null(pack, "a pack folder with no card backs loads as null, not a crash")


# --- Pack metadata / tags ---


func before_each() -> void:
	_tag_root = "user://test_packtags_%d" % randi()
	DirAccess.make_dir_recursive_absolute(_tag_root)


func after_each() -> void:
	var dir = DirAccess.open(_tag_root)
	if dir:
		Helpers.delete_recursive(dir)


func _write_metadata(contents: String) -> void:
	var file := FileAccess.open(_tag_root.path_join(PackDataLoader.METADATA_FILE), FileAccess.WRITE)
	file.store_string(contents)
	file.close()


func test_no_metadata_file_means_no_tags() -> void:
	assert_eq(PackDataLoader.load_tags(_tag_root), [], "a pack without pack.json has no tags")


func test_reads_tag_list() -> void:
	_write_metadata('{"tags": ["Roguelike", "Deckbuilder"]}')

	assert_eq(
		PackDataLoader.load_tags(_tag_root),
		["Roguelike", "Deckbuilder"],
		"tags load in the order the pack author wrote them"
	)


func test_malformed_json_warns_and_yields_no_tags() -> void:
	_write_metadata("{not json at all")

	assert_eq(PackDataLoader.load_tags(_tag_root), [], "broken JSON degrades to no tags")


func test_non_object_json_yields_no_tags() -> void:
	_write_metadata('["Roguelike"]')

	assert_eq(PackDataLoader.load_tags(_tag_root), [], "a bare JSON array is not valid metadata")


func test_non_list_tags_yields_no_tags() -> void:
	_write_metadata('{"tags": "Roguelike"}')

	assert_eq(PackDataLoader.load_tags(_tag_root), [], "a string tags field degrades to no tags")


func test_missing_tags_key_is_not_an_error() -> void:
	_write_metadata('{"author": "someone"}')

	assert_eq(PackDataLoader.load_tags(_tag_root), [], "metadata without tags is still valid")


func test_skips_blank_and_non_string_entries() -> void:
	_write_metadata('{"tags": ["Roguelike", "", "   ", 7, null, "Deckbuilder"]}')

	assert_eq(
		PackDataLoader.load_tags(_tag_root),
		["Roguelike", "Deckbuilder"],
		"blank and non-string entries are dropped"
	)


func test_trims_whitespace() -> void:
	_write_metadata('{"tags": ["  Roguelike  "]}')

	assert_eq(PackDataLoader.load_tags(_tag_root), ["Roguelike"], "tags are trimmed")


func test_deduplicates_case_insensitively_keeping_first_spelling() -> void:
	_write_metadata('{"tags": ["Roguelike", "roguelike", "ROGUELIKE", "Deckbuilder"]}')

	assert_eq(
		PackDataLoader.load_tags(_tag_root),
		["Roguelike", "Deckbuilder"],
		"case variants collapse to the first spelling the author used"
	)


# --- Writing metadata (save_tags) ---


func test_save_then_load_round_trips() -> void:
	var tags: Array[String] = ["Roguelike", "Deckbuilder"]

	assert_true(PackDataLoader.save_tags(_tag_root, tags), "save reports success")
	assert_eq(PackDataLoader.load_tags(_tag_root), tags, "tags survive a save/load round trip")


func test_save_writes_readable_json() -> void:
	PackDataLoader.save_tags(_tag_root, ["Roguelike"] as Array[String])

	var path := _tag_root.path_join(PackDataLoader.METADATA_FILE)
	var json := JSON.new()
	assert_eq(json.parse(FileAccess.get_file_as_string(path)), OK, "written file is valid JSON")
	assert_eq(json.data, {"tags": ["Roguelike"]}, "written document has the expected shape")


func test_saving_empty_tags_removes_the_file() -> void:
	PackDataLoader.save_tags(_tag_root, ["Roguelike"] as Array[String])
	var path := _tag_root.path_join(PackDataLoader.METADATA_FILE)
	assert_true(FileAccess.file_exists(path), "metadata file written")

	PackDataLoader.save_tags(_tag_root, [] as Array[String])

	assert_false(FileAccess.file_exists(path), "clearing every tag removes the metadata file")
	assert_eq(PackDataLoader.load_tags(_tag_root), [], "and the pack reads back as untagged")


func test_saving_empty_tags_with_no_existing_file_is_safe() -> void:
	assert_true(PackDataLoader.save_tags(_tag_root, [] as Array[String]), "no-op save succeeds")
	assert_eq(PackDataLoader.load_tags(_tag_root), [], "still untagged")


func test_save_overwrites_previous_tags() -> void:
	PackDataLoader.save_tags(_tag_root, ["Roguelike", "Deckbuilder"] as Array[String])
	PackDataLoader.save_tags(_tag_root, ["Metroidvania"] as Array[String])

	assert_eq(
		PackDataLoader.load_tags(_tag_root), ["Metroidvania"], "a later save replaces the old tags"
	)
