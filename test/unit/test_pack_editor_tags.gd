extends GutTest

# Tests the pack editor's categories (submodule UI, exercised here because it
# needs the parent project's PopupContainer and autoloads): the official
# categories are offered as toggles to tick, rather than typed from memory.

const PACK_EDITOR: PackedScene = preload("res://source/mod-manager/popups/pack_editor.tscn")

var _categories: Array[Dictionary] = [
	{"name": "Action", "description": "Real-time skill"},
	{"name": "Puzzle", "description": "Thinking"},
	{"name": "Strategy", "description": "Planning"},
	{"id": "workshop-mods", "name": "Workshop Mods", "description": "From the Workshop"},
]


## With the test categories unless `categories` says otherwise.
func _make_editor(pack: PackData = null, categories: Variant = null) -> PackEditor:
	var editor := PACK_EDITOR.instantiate() as PackEditor
	add_child_autofree(editor)
	await get_tree().process_frame
	editor.categories = _categories if categories == null else categories
	editor.pack_data = pack
	editor.open()
	await get_tree().process_frame
	return editor


func _pack(tags: Array[String]) -> PackData:
	var pack := PackData.new()
	pack.title = "Test Pack"
	pack.tags = tags
	return pack


func _toggle(editor: PackEditor, label: String) -> Button:
	for child in editor._tag_list.get_children():
		if child is Button and child.text == label and not child.is_queued_for_deletion():
			return child
	return null


func _labels(editor: PackEditor) -> Array:
	var labels: Array = []
	for child in editor._tag_list.get_children():
		if not child.is_queued_for_deletion():
			labels.append(child.text)
	return labels


func test_adds_a_tag() -> void:
	var editor := await _make_editor()

	assert_true(editor.add_tag("Roguelike"), "a fresh tag is accepted")
	assert_eq(editor.pack_data.tags, ["Roguelike"], "the tag lands on the pack")
	assert_has(_labels(editor), "Roguelike", "and gets a toggle in the list")


func test_rejects_blank_tags() -> void:
	var editor := await _make_editor()

	assert_false(editor.add_tag(""), "an empty tag is rejected")
	assert_false(editor.add_tag("   "), "a whitespace-only tag is rejected")
	assert_eq(editor.pack_data.tags, [], "no tags were added")


func test_trims_whitespace() -> void:
	var editor := await _make_editor()

	editor.add_tag("  Roguelike  ")

	assert_eq(editor.pack_data.tags, ["Roguelike"], "the stored tag is trimmed")


func test_rejects_duplicates_case_insensitively() -> void:
	var editor := await _make_editor()

	assert_true(editor.add_tag("Roguelike"), "first add succeeds")
	assert_false(editor.add_tag("roguelike"), "a case variant is rejected")
	assert_false(editor.add_tag("ROGUELIKE"), "so is another")
	assert_eq(editor.pack_data.tags, ["Roguelike"], "only the first spelling is kept")


func test_removes_a_tag() -> void:
	var editor := await _make_editor()
	editor.add_tag("Roguelike")
	editor.add_tag("Deckbuilder")

	editor.remove_tag("Roguelike")

	assert_eq(editor.pack_data.tags, ["Deckbuilder"], "the named tag is removed")
	assert_does_not_have(_labels(editor), "Roguelike", "its toggle goes with it")


func test_removing_an_unknown_tag_is_safe() -> void:
	var editor := await _make_editor()
	editor.add_tag("Roguelike")

	editor.remove_tag("Nonexistent")

	assert_eq(editor.pack_data.tags, ["Roguelike"], "removing a tag that isn't there is a no-op")


func test_every_category_is_offered_with_its_meaning() -> void:
	var editor := await _make_editor()

	assert_eq(_labels(editor), ["Action", "Puzzle", "Strategy"], "in the file's order")
	assert_eq(_toggle(editor, "Puzzle").tooltip_text, "Thinking", "with its description")
	assert_false(_toggle(editor, "Puzzle").button_pressed, "nothing ticked on a new pack")


func test_ticking_and_unticking_a_category() -> void:
	var editor := await _make_editor()

	_toggle(editor, "Puzzle").button_pressed = true
	assert_eq(editor.pack_data.tags, ["Puzzle"], "ticked")
	_toggle(editor, "Strategy").button_pressed = true
	_toggle(editor, "Puzzle").button_pressed = false
	assert_eq(editor.pack_data.tags, ["Strategy"], "unticked")


func test_a_packs_tags_are_ticked_whatever_their_case() -> void:
	var editor := await _make_editor(_pack(["strategy"] as Array[String]))

	assert_true(_toggle(editor, "Strategy").button_pressed)
	_toggle(editor, "Strategy").button_pressed = false
	assert_eq(editor.pack_data.tags, [], "and unticking removes it")


func test_the_workshop_category_isnt_offered() -> void:
	var editor := await _make_editor(_pack(["Workshop Mods"] as Array[String]))

	assert_does_not_have(_labels(editor), "Workshop Mods", "the game applies it itself")
	assert_eq(editor.pack_data.tags, ["Workshop Mods"], "and a pack that has it keeps it")


func test_a_tag_that_isnt_a_category_is_kept_ticked() -> void:
	var editor := await _make_editor(_pack(["Tower Defense"] as Array[String]))

	assert_eq(_labels(editor), ["Action", "Puzzle", "Strategy", "Tower Defense"], "shown last")
	assert_true(_toggle(editor, "Tower Defense").button_pressed, "still on the pack")


func test_without_categories_the_hint_says_why() -> void:
	var editor := await _make_editor(null, [] as Array[Dictionary])

	assert_eq(_labels(editor), [], "nothing to tick")
	assert_string_contains(editor._tag_hint.text, "haven't been downloaded")


func test_reopening_shows_the_new_packs_tags() -> void:
	var editor := await _make_editor(_pack(["Action"] as Array[String]))
	assert_true(_toggle(editor, "Action").button_pressed, "first pack's tag")

	editor.pack_data = _pack([] as Array[String])
	editor.open()
	await get_tree().process_frame

	assert_false(_toggle(editor, "Action").button_pressed, "not carried over")
