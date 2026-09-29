extends GutTest

# Tests the category descriptions shown as tooltips on the draft screen's filters.

const FILTER_PANEL: PackedScene = preload("res://source/menus/menu_widgets/pack_filter_panel.tscn")

var _path: String
var _saved_all_packs: Array[PackData]


func before_each() -> void:
	_path = "user://test_categories_%d.json" % randi()
	_saved_all_packs = PacksManager.all_packs


func after_each() -> void:
	if FileAccess.file_exists(_path):
		DirAccess.remove_absolute(_path)
	PacksManager.all_packs = _saved_all_packs
	PacksManager.load_categories("user://definitely_missing.json")


func _write(contents: String) -> void:
	var file := FileAccess.open(_path, FileAccess.WRITE)
	file.store_string(contents)
	file.close()


func test_reads_descriptions_by_name() -> void:
	_write('{"categories": [{"name": "Deckbuilder", "description": "Cards!"}]}')
	PacksManager.load_categories(_path)

	assert_eq(PacksManager.category_description("Deckbuilder"), "Cards!", "described by name")


func test_matching_ignores_case() -> void:
	_write('{"categories": [{"name": "Deckbuilder", "description": "Cards!"}]}')
	PacksManager.load_categories(_path)

	assert_eq(PacksManager.category_description("deckbuilder"), "Cards!", "like the tags do")


func test_unknown_category_has_no_description() -> void:
	_write('{"categories": [{"name": "Deckbuilder", "description": "Cards!"}]}')
	PacksManager.load_categories(_path)

	assert_eq(PacksManager.category_description("Racing"), "", "nothing for an undescribed tag")


func test_missing_file_is_harmless() -> void:
	PacksManager.load_categories("user://definitely_missing.json")

	assert_eq(PacksManager.category_description("Deckbuilder"), "", "no file, no descriptions")


func test_malformed_file_is_harmless() -> void:
	_write("{not json")
	PacksManager.load_categories(_path)

	assert_eq(PacksManager.category_description("Deckbuilder"), "", "broken file, no descriptions")


func test_bad_entries_are_skipped() -> void:
	_write(
		(
			'{"categories": [7, {"name": "A"}, {"description": "x"},'
			+ ' {"name": "Puzzle", "description": "Thinky"}]}'
		)
	)
	PacksManager.load_categories(_path)

	assert_eq(PacksManager.category_description("Puzzle"), "Thinky", "the good entry still loads")


func test_filter_checkboxes_carry_the_description() -> void:
	_write('{"categories": [{"name": "Puzzle", "description": "Thinky"}]}')
	PacksManager.load_categories(_path)
	var pack := PackData.new()
	pack.title = "A"
	pack.tags = ["Puzzle"] as Array[String]
	PacksManager.all_packs = [pack] as Array[PackData]

	var panel := FILTER_PANEL.instantiate() as PackFilterPanel
	add_child_autofree(panel)
	await get_tree().process_frame

	assert_eq(panel._checkboxes[0].tooltip_text, "Thinky", "hovering a filter explains it")
