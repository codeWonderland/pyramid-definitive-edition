extends GutTest

# Tests tag editing in the mod manager's pack editor (submodule UI, exercised
# here because it needs the parent project's PopupContainer and autoloads).

const PACK_EDITOR: PackedScene = preload("res://source/mod-manager/popups/pack_editor.tscn")


func _make_editor(pack: PackData = null) -> PackEditor:
	var editor := PACK_EDITOR.instantiate() as PackEditor
	add_child_autofree(editor)
	await get_tree().process_frame
	editor.pack_data = pack
	editor.open()
	await get_tree().process_frame
	return editor


func _pack(tags: Array[String]) -> PackData:
	var pack := PackData.new()
	pack.title = "Test Pack"
	pack.tags = tags
	return pack


func _tag_button_labels(editor: PackEditor) -> Array:
	var labels: Array = []
	for child in editor._tag_list.get_children():
		labels.append(child.text)
	return labels


func test_adds_a_tag() -> void:
	var editor := await _make_editor()

	assert_true(editor.add_tag("Roguelike"), "a fresh tag is accepted")
	assert_eq(editor.pack_data.tags, ["Roguelike"], "the tag lands on the pack")
	assert_eq(_tag_button_labels(editor).size(), 1, "and gets a button in the list")


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
	assert_eq(_tag_button_labels(editor).size(), 1, "its button goes with it")


func test_removing_an_unknown_tag_is_safe() -> void:
	var editor := await _make_editor()
	editor.add_tag("Roguelike")

	editor.remove_tag("Nonexistent")

	assert_eq(editor.pack_data.tags, ["Roguelike"], "removing a tag that isn't there is a no-op")


func test_pressing_a_tag_button_removes_it() -> void:
	var editor := await _make_editor()
	editor.add_tag("Roguelike")

	editor._tag_list.get_child(0).pressed.emit()

	assert_eq(editor.pack_data.tags, [], "clicking a tag removes it")


func test_add_button_takes_the_field_text_and_clears_it() -> void:
	var editor := await _make_editor()

	editor._tag_line_edit.text = "Roguelike"
	editor._add_tag_button.pressed.emit()

	assert_eq(editor.pack_data.tags, ["Roguelike"], "the field's text became a tag")
	assert_eq(editor._tag_line_edit.text, "", "and the field was cleared")


func test_rejected_tag_leaves_the_field_alone() -> void:
	var editor := await _make_editor()
	editor.add_tag("Roguelike")

	editor._tag_line_edit.text = "roguelike"
	editor._add_tag_button.pressed.emit()

	assert_eq(
		editor._tag_line_edit.text, "roguelike", "a rejected duplicate stays in the field to fix"
	)


func test_submitting_the_field_adds_the_tag() -> void:
	var editor := await _make_editor()

	editor._tag_line_edit.text = "Roguelike"
	editor._tag_line_edit.text_submitted.emit("Roguelike")

	assert_eq(editor.pack_data.tags, ["Roguelike"], "pressing enter adds the tag")


func test_editing_an_existing_pack_shows_its_tags() -> void:
	var editor := await _make_editor(_pack(["Roguelike", "Deckbuilder"] as Array[String]))

	assert_eq(_tag_button_labels(editor).size(), 2, "existing tags each get a button")


func test_reopening_clears_the_previous_packs_tags() -> void:
	var editor := await _make_editor(_pack(["Roguelike"] as Array[String]))
	assert_eq(_tag_button_labels(editor).size(), 1, "first pack's tag is shown")

	editor.pack_data = _pack([] as Array[String])
	editor.open()
	await get_tree().process_frame

	assert_eq(_tag_button_labels(editor), [], "the untagged pack shows no tag buttons")
