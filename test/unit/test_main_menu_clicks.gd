extends GutTest

# Tests the main menu's "press anything to start" (fixing the Library button
# sometimes starting a run). Whether a click starts a run is decided at the press:
# buttons act on release, and waiting to see whether one had claimed the click
# raced the player's hold, so a slightly long click on Library went to the
# updater instead.

const MAIN_MENU: PackedScene = preload("res://source/menus/main_menu.tscn")


func _menu() -> Control:
	var menu := MAIN_MENU.instantiate()
	add_child_autofree(menu)
	await get_tree().process_frame
	return menu


func test_every_menu_button_claims_its_clicks() -> void:
	var menu := await _menu()

	for button in [
		menu._load_game_button,
		menu._settings_button,
		menu._exit_button,
		menu._credits_button,
		menu._library_button,
		menu._github_button,
	]:
		assert_true(
			menu.is_over_menu_button(button.get_global_rect().get_center()),
			"a click on %s is the button's, not a run start" % button.name
		)


func test_a_click_away_from_the_buttons_is_not_claimed() -> void:
	var menu := await _menu()
	var far := Vector2(-1000, -1000)

	assert_false(menu.is_over_menu_button(far), "empty space starts a run")


func test_there_is_no_timer_race_left() -> void:
	# The old approach waited 0.2s after the press and then checked a flag the
	# button set on release. That flag is gone; nothing should reintroduce it.
	var menu := await _menu()

	assert_false("_hold_scene_transition" in menu, "no deferred claim flag")


func test_library_button_is_an_icon() -> void:
	var menu := await _menu()

	assert_true(menu._library_button is TextureButton, "an icon, like its neighbours")
	assert_not_null(menu._library_button.texture_normal, "with the bookshelf art")
	assert_eq(menu._library_button.size, menu._settings_button.size, "the same size as settings")
