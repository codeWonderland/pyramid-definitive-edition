extends GutTest

# Tests the main menu: its choices are plain text along the bottom - Start a run,
# Load a run, Library, Settings, Exit - rising in once the logo lands, with Start
# a run focused for the keyboard. A click elsewhere no longer starts a run.

const MAIN_MENU: PackedScene = preload("res://source/menus/main_menu.tscn")


func _menu() -> MainMenu:
	var menu := MAIN_MENU.instantiate() as MainMenu
	add_child_autofree(menu)
	await get_tree().process_frame
	return menu


func test_the_choices_are_text_in_order() -> void:
	var menu := await _menu()

	var labels: Array = []
	for button in menu._menu.get_children().filter(func(child): return child is Button):
		labels.append(button.text)
		assert_true(button is Button, "%s is a button" % button.text)
		assert_eq(button.theme_type_variation, &"MenuTextButton", "styled as menu text")
	assert_eq(labels, ["Start a run", "Load a run", "Library", "Settings", "Exit"])


func test_every_choice_is_wired() -> void:
	var menu := await _menu()

	for button in menu._menu.get_children().filter(func(child): return child is Button):
		assert_gt(button.pressed.get_connections().size(), 0, "%s does something" % button.text)


func test_the_menu_arrives_after_the_logo_with_start_focused() -> void:
	var menu := await _menu()
	assert_false(menu._menu.visible, "hidden while the logo lands")

	await get_tree().create_timer(0.8).timeout

	assert_true(menu._menu.visible, "then shown")
	assert_true(menu._start_button.has_focus(), "with Start a run ready for Enter")


func test_a_click_on_empty_space_does_nothing() -> void:
	var menu := await _menu()

	assert_false(menu.has_method("is_over_menu_button"), "no more press-anything-to-start")
	assert_false(menu.has_method("_input"), "nothing listening for stray clicks")
