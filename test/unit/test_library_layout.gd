extends GutTest

# Tests the Library's details panel adapting to its width: the Versus and Co-op
# tiles stack on a narrow panel, and "Your marks" folds away like an FAQ entry.

const LIBRARY: PackedScene = preload("res://source/menus/library.tscn")

var _saved_all_packs: Array[PackData]
var _saved_marks_open: bool


func before_each() -> void:
	_saved_all_packs = PacksManager.all_packs
	_saved_marks_open = Library.marks_open
	Library.marks_open = false
	var pack := PackData.new()
	pack.title = "a to z"
	pack.folder_path = "user://__test_library_layout"
	var back := ImageTexture.create_from_image(Image.create(4, 4, false, Image.FORMAT_RGBA8))
	pack.backs.append(back)
	pack.primaries.append(back)
	var packs: Array[PackData] = [pack]
	PacksManager.all_packs = packs


func after_each() -> void:
	PacksManager.all_packs = _saved_all_packs
	Library.marks_open = _saved_marks_open


func _make() -> Library:
	var library := LIBRARY.instantiate() as Library
	add_child_autofree(library)
	await get_tree().process_frame
	library._show_details(PacksManager.all_packs[0])
	return library


func test_the_rule_tiles_stack_on_a_narrow_panel() -> void:
	var library := await _make()

	library._rules_row.size.x = Library.RULES_SIDE_BY_SIDE_WIDTH - 1.0
	library._stack_rules()
	assert_true(library._rules_row.vertical, "one column when narrow")

	library._rules_row.size.x = Library.RULES_SIDE_BY_SIDE_WIDTH + 1.0
	library._stack_rules()
	assert_false(library._rules_row.vertical, "side by side when there's room")


func test_marks_start_folded() -> void:
	var library := await _make()

	assert_false(library._marks.visible, "marks hidden")
	assert_false(library._marks_toggle.button_pressed, "toggle up")
	assert_eq(library._chevron.rotation_degrees, 0.0, "chevron points right")


func test_the_heading_opens_and_closes_the_marks() -> void:
	var library := await _make()

	library._marks_toggle.button_pressed = true
	assert_true(library._marks.visible, "opened")
	assert_eq(library._chevron.rotation_degrees, 90.0, "chevron points down")

	library._marks_toggle.button_pressed = false
	assert_false(library._marks.visible, "closed again")


func test_an_open_marks_list_stays_open_next_time() -> void:
	var library := await _make()
	library._marks_toggle.button_pressed = true

	var reopened := await _make()

	assert_true(reopened._marks.visible, "remembered")
	assert_true(reopened._marks_toggle.button_pressed, "toggle matches")
