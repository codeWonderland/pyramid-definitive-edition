extends GutTest

# Smoke test: the settings popup exposes the duplicate-culling toggle, seeds it
# from the saved setting, and drives the setting when clicked.

const PAUSE_MENU: PackedScene = preload("res://source/menus/pause_menu.tscn")

var _saved_culling: bool


func before_each() -> void:
	_saved_culling = UserSettingsManager.duplicate_culling


func after_each() -> void:
	UserSettingsManager.update_duplicate_culling(_saved_culling)


func _build() -> PauseMenu:
	var menu := PAUSE_MENU.instantiate() as PauseMenu
	add_child_autofree(menu)
	await get_tree().process_frame
	return menu


func test_toggle_resolves_and_seeds_from_setting() -> void:
	UserSettingsManager.update_duplicate_culling(false)

	var menu := await _build()

	assert_true(is_instance_valid(menu._duplicate_culling_toggle), "culling toggle resolved")
	assert_false(
		menu._duplicate_culling_toggle.button_pressed, "checkbox seeded from the saved setting"
	)


func test_clicking_toggle_flips_the_setting() -> void:
	UserSettingsManager.update_duplicate_culling(true)

	var menu := await _build()

	menu._duplicate_culling_toggle.pressed.emit()
	assert_false(UserSettingsManager.duplicate_culling, "click turns culling off")

	menu._duplicate_culling_toggle.pressed.emit()
	assert_true(UserSettingsManager.duplicate_culling, "clicking again turns it back on")
