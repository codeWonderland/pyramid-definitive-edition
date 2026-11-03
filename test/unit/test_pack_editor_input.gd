extends GutTest

# Tests typing a pack name and adding card images in the mod manager's pack editor
# (submodule UI, exercised here because it needs the parent project's
# PopupContainer and autoloads).

const PACK_EDITOR: PackedScene = preload("res://source/mod-manager/popups/pack_editor.tscn")
const IMAGE_DIR: String = "user://__test_pack_editor_input/"


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(IMAGE_DIR)


func after_each() -> void:
	for file_name in DirAccess.get_files_at(IMAGE_DIR):
		DirAccess.remove_absolute(IMAGE_DIR + file_name)
	DirAccess.remove_absolute(IMAGE_DIR)


func _make_editor() -> PackEditor:
	var editor := PACK_EDITOR.instantiate() as PackEditor
	add_child_autofree(editor)
	await get_tree().process_frame
	editor.pack_data = null
	editor.open()
	await get_tree().process_frame
	return editor


## Puts `text` in the name field with the cursor at `caret`, as typing would.
func _type_name(editor: PackEditor, text: String, caret: int) -> void:
	editor._pack_name_line_edit.text = text
	editor._pack_name_line_edit.caret_column = caret
	editor._pack_name_line_edit.text_changed.emit(text)


func _image(file_name: String) -> String:
	var path := IMAGE_DIR + file_name
	Image.create(4, 4, false, Image.FORMAT_RGBA8).save_png(path)
	return ProjectSettings.globalize_path(path)


func _card_files(container: HBoxContainer) -> Array:
	var names: Array = []
	for child in container.get_children():
		# The row's own add button is a card too, without a source file.
		if child is ModManagerCard and child.texture != null:
			var source := String(child.texture.get_meta(PackDataLoader.SOURCE_META, ""))
			if not source.is_empty():
				names.append(source.get_file())
	return names


func test_a_colon_is_dropped_without_moving_the_cursor() -> void:
	var editor := await _make_editor()

	_type_name(editor, "Chicken TD:", 11)

	assert_eq(editor._pack_name_line_edit.text, "Chicken TD", "the colon is dropped")
	assert_eq(editor._pack_name_line_edit.caret_column, 10, "the cursor stays at the end")
	assert_eq(editor.pack_data.title, "Chicken TD", "the name is kept")
	assert_true(editor._pack_name_hint.visible, "and the hint explains why")


func test_a_paste_keeps_everything_a_folder_can_hold() -> void:
	var editor := await _make_editor()
	_type_name(editor, "Pack", 4)

	_type_name(editor, "Chicken TD: Defenders/Pack", 25)

	assert_eq(editor._pack_name_line_edit.text, "Chicken TD DefendersPack", "only the : and / go")
	assert_eq(editor._pack_name_line_edit.caret_column, 23, "the cursor ends after the paste")


func test_the_hint_clears_once_the_name_is_fine() -> void:
	var editor := await _make_editor()
	_type_name(editor, "Chicken:", 8)

	_type_name(editor, "Chicken TD", 10)

	assert_false(editor._pack_name_hint.visible)


func test_several_images_are_added_in_filename_order() -> void:
	var editor := await _make_editor()
	var files := PackedStringArray([_image("p10.png"), _image("p2.png"), _image("p1.png")])

	editor._select_new_card(editor._primary_cards, editor._add_primary_card_button)
	editor._file_dialog.hide()
	editor._file_dialog.files_selected.emit(files)

	assert_eq(_card_files(editor._primary_cards), ["p1.png", "p2.png", "p10.png"])


func test_a_cancelled_pick_doesnt_add_to_that_row_later() -> void:
	var editor := await _make_editor()

	editor._select_new_card(editor._primary_cards, editor._add_primary_card_button)
	editor._file_dialog.hide()
	editor._select_new_card(editor._secondary_cards, editor._add_secondary_card_button)
	editor._file_dialog.hide()
	editor._file_dialog.files_selected.emit(PackedStringArray([_image("s1.png")]))

	assert_eq(_card_files(editor._primary_cards), [], "nothing lands in the cancelled row")
	assert_eq(_card_files(editor._secondary_cards), ["s1.png"], "only in the row picked last")
