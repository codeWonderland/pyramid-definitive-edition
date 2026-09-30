extends GutTest

# Tests for source/mod-manager PackDataLoader's full metadata records (submodule
# code): pack.json can carry far more than tags, and saving from the editor must
# write those fields back rather than dropping them.

var _tag_root: String


func before_each() -> void:
	_tag_root = "user://test_packmeta_%d" % randi()
	DirAccess.make_dir_recursive_absolute(_tag_root)


func after_each() -> void:
	var dir = DirAccess.open(_tag_root)
	if dir:
		Helpers.delete_recursive(dir)


func _write_metadata(contents: String) -> void:
	var file := FileAccess.open(_tag_root.path_join(PackDataLoader.METADATA_FILE), FileAccess.WRITE)
	file.store_string(contents)
	file.close()


func test_load_metadata_returns_the_whole_record() -> void:
	_write_metadata('{"tags": ["Roguelike"], "is_free": true, "estimated_time": "30m"}')

	var record := PackDataLoader.load_metadata(_tag_root)

	assert_eq(record.get("is_free"), true, "non-tag fields are read")
	assert_eq(record.get("estimated_time"), "30m", "all of them")


func test_load_metadata_of_a_broken_file_is_empty() -> void:
	_write_metadata("{not json")

	assert_eq(PackDataLoader.load_metadata(_tag_root), {}, "broken JSON reads as an empty record")
	_expect_loader_warnings()


func test_save_tags_keeps_the_rest_of_the_record() -> void:
	_write_metadata('{"tags": ["Roguelike"], "is_free": true, "name": "Test Game"}')

	PackDataLoader.save_tags(_tag_root, ["Deckbuilder"] as Array[String])

	var record := PackDataLoader.load_metadata(_tag_root)
	assert_eq(PackDataLoader.load_tags(_tag_root), ["Deckbuilder"], "the tags were replaced")
	assert_eq(record.get("is_free"), true, "but the free flag survived")
	assert_eq(record.get("name"), "Test Game", "and so did the name")


func test_clearing_tags_keeps_a_file_that_still_has_other_fields() -> void:
	_write_metadata('{"tags": ["Roguelike"], "is_free": true}')

	PackDataLoader.save_tags(_tag_root, [] as Array[String])

	var path := _tag_root.path_join(PackDataLoader.METADATA_FILE)
	assert_true(FileAccess.file_exists(path), "the record still has content, so the file stays")
	assert_false(PackDataLoader.load_metadata(_tag_root).has("tags"), "with no tags entry")
	assert_eq(PackDataLoader.load_metadata(_tag_root).get("is_free"), true, "and the rest intact")


func test_save_metadata_writes_back_fields_it_was_handed() -> void:
	var record := {"objectives": {"co_op_rules": "Play together"}, "is_free": false}

	PackDataLoader.save_metadata(_tag_root, record, ["Action"] as Array[String])

	var read := PackDataLoader.load_metadata(_tag_root)
	assert_eq(read["objectives"]["co_op_rules"], "Play together", "nested fields round-trip")
	assert_eq(PackDataLoader.load_tags(_tag_root), ["Action"], "alongside the tags")


func test_save_metadata_does_not_mutate_the_record_passed_in() -> void:
	var record := {"is_free": true}

	PackDataLoader.save_metadata(_tag_root, record, ["Action"] as Array[String])

	assert_false(record.has("tags"), "the caller's dictionary is left as it was")


func test_loading_a_pack_carries_its_metadata() -> void:
	for stem in ["b1", "p1"]:
		var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
		img.save_png(_tag_root.path_join(stem + ".png"))
	_write_metadata('{"tags": ["Puzzle"], "estimated_time": "15m"}')

	var pack := PackDataLoader.load_pack_from_path(_tag_root)

	assert_not_null(pack, "the pack loaded")
	assert_eq(pack.tags, ["Puzzle"], "with its tags")
	assert_eq(pack.metadata.get("estimated_time"), "15m", "and the rest of its record")


func test_saving_an_unchanged_record_leaves_the_file_alone() -> void:
	var original := '{\n  "tags": [ "Roguelike" ],\n  "is_free": true\n}\n'
	_write_metadata(original)

	PackDataLoader.save_tags(_tag_root, ["Roguelike"] as Array[String])

	var path := _tag_root.path_join(PackDataLoader.METADATA_FILE)
	assert_eq(FileAccess.get_file_as_string(path), original, "not rewritten, formatting and all")


func test_whole_numbers_are_written_as_whole_numbers() -> void:
	_write_metadata('{"objectives": {"primary_count": 22, "ratio": 1.5}, "tags": ["A"]}')

	PackDataLoader.save_tags(_tag_root, ["A", "B"] as Array[String])

	var written := FileAccess.get_file_as_string(_tag_root.path_join(PackDataLoader.METADATA_FILE))
	assert_string_contains(written, '"primary_count": 22', "22, not 22.0")
	assert_string_contains(written, '"ratio": 1.5', "real fractions are kept")
	assert_true(written.ends_with("\n"), "ends with a newline")


## The loader warns about broken metadata by design. Mark those warnings as
## expected, so a test runner that counts warnings as failures (GUT 9.5, which
## the Godot 4.5 standalone app uses) doesn't flag a test for doing its job.
## Only PackDataLoader warnings are touched; a real error still fails.
func _expect_loader_warnings() -> void:
	for error in get_errors():
		if error.error_type == 1 and error.contains_text("PackDataLoader"):
			error.handled = true
