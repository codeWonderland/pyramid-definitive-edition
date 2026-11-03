extends GutTest

# Tests picking a pack in the mod manager's list (submodule code, exercised here
# because ModManager depends on the parent project's autoloads and base classes).
# Selection used to show only as keyboard focus, so it vanished the moment an
# action button was clicked.

const MOD_MANAGER: PackedScene = preload("res://source/mod-manager/mod_manager.tscn")

var _mods_root: String


func before_each() -> void:
	_mods_root = "user://test_modselect_%d/" % randi()
	for title in ["Alpha", "Beta"]:
		var folder := _mods_root.path_join(title)
		DirAccess.make_dir_recursive_absolute(folder)
		Image.create(4, 4, false, Image.FORMAT_RGBA8).save_png(folder.path_join("b1.png"))
		Image.create(4, 4, false, Image.FORMAT_RGBA8).save_png(folder.path_join("p1.png"))


func after_each() -> void:
	var dir = DirAccess.open(_mods_root)
	if dir:
		Helpers.delete_recursive(dir)


func _manager() -> ModManager:
	var manager := MOD_MANAGER.instantiate() as ModManager
	manager.mods_path = _mods_root
	manager.scene_to_return_to = null
	add_child_autofree(manager)
	for i in 5:
		await get_tree().process_frame
	return manager


func _pack_buttons(manager: ModManager) -> Array:
	return manager._mods_list.get_children()


func test_the_picked_pack_stays_lit_while_an_action_is_chosen() -> void:
	var manager := await _manager()
	var buttons := _pack_buttons(manager)
	assert_eq(buttons.size(), 2, "both packs are listed")

	buttons[0].button_pressed = true
	buttons[0].pressed.emit()
	manager._edit_mod_button.grab_focus()

	assert_true(buttons[0].button_pressed, "still shown as selected")
	assert_eq(manager._selected_pack.title, "Alpha")


func test_picking_another_pack_moves_the_selection() -> void:
	var manager := await _manager()
	var buttons := _pack_buttons(manager)

	buttons[0].button_pressed = true
	buttons[1].button_pressed = true

	assert_false(buttons[0].button_pressed, "only one pack is selected at a time")
	assert_true(buttons[1].button_pressed)
