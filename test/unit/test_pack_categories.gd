extends GutTest

# Tests reading the official categories.json the pack editor offers as tags:
# in the file's order, and forgiving of a missing or broken file.

var _path: String


func before_each() -> void:
	_path = "user://test_categories_%d.json" % randi()


func after_each() -> void:
	if FileAccess.file_exists(_path):
		DirAccess.remove_absolute(_path)


func _write(text: String) -> void:
	var file := FileAccess.open(_path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func test_categories_are_read_in_order() -> void:
	_write(
		(
			JSON
			. stringify(
				{
					"categories":
					[
						{"id": "action", "name": "Action", "description": "Skill"},
						{"id": "puzzle", "name": "Puzzle"},
					]
				}
			)
		)
	)

	assert_eq(
		PackDataLoader.load_categories(_path),
		[
			{"id": "action", "name": "Action", "description": "Skill"},
			{"id": "puzzle", "name": "Puzzle", "description": ""},
		]
	)


func test_entries_without_a_name_are_skipped() -> void:
	_write(JSON.stringify({"categories": [{"description": "no name"}, {"name": "  "}, "junk"]}))

	assert_eq(PackDataLoader.load_categories(_path), [] as Array[Dictionary])


func test_a_missing_or_broken_file_is_no_categories() -> void:
	assert_eq(PackDataLoader.load_categories(_path), [] as Array[Dictionary], "missing")
	_write("not json")
	assert_eq(PackDataLoader.load_categories(_path), [] as Array[Dictionary], "broken")
