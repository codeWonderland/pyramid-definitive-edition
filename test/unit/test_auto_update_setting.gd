extends GutTest

# Tests the automatic mod update setting (#42): boot no longer stops to ask
# before downloading new mod data, and the prompt is still available to players
# who turn the setting off.

const PAUSE_MENU: PackedScene = preload("res://source/menus/pause_menu.tscn")

var _saved_auto_update: bool


func before_each() -> void:
	_saved_auto_update = UserSettingsManager.auto_update_mods


func after_each() -> void:
	UserSettingsManager.update_auto_update_mods(_saved_auto_update)


# --- The setting ---


func test_defaults_to_on() -> void:
	var config := ConfigFile.new()
	config.load(UserSettingsManager.SAVE_PATH)
	assert_true(
		config.get_value("settings", "auto_update_mods", true),
		"a settings file without the key reads as automatic updates enabled"
	)


func test_update_emits_signal() -> void:
	watch_signals(UserSettingsManager)
	UserSettingsManager.update_auto_update_mods(false)
	assert_signal_emitted(UserSettingsManager, "auto_update_mods_updated")


func test_update_persists_both_ways() -> void:
	UserSettingsManager.update_auto_update_mods(false)
	var config := ConfigFile.new()
	assert_eq(config.load(UserSettingsManager.SAVE_PATH), OK, "settings written")
	assert_false(config.get_value("settings", "auto_update_mods", true), "off persisted")

	UserSettingsManager.update_auto_update_mods(true)
	assert_eq(config.load(UserSettingsManager.SAVE_PATH), OK, "settings written again")
	assert_true(config.get_value("settings", "auto_update_mods", false), "on persisted")


# --- The settings popup ---


func _build_menu() -> PauseMenu:
	var menu := PAUSE_MENU.instantiate() as PauseMenu
	add_child_autofree(menu)
	await get_tree().process_frame
	return menu


func test_toggle_seeds_from_the_setting() -> void:
	UserSettingsManager.update_auto_update_mods(false)

	var menu := await _build_menu()

	assert_true(is_instance_valid(menu._auto_update_toggle), "the toggle resolved")
	assert_false(menu._auto_update_toggle.button_pressed, "seeded from the saved setting")


func test_clicking_the_toggle_flips_the_setting() -> void:
	UserSettingsManager.update_auto_update_mods(true)
	var menu := await _build_menu()

	menu._auto_update_toggle.pressed.emit()
	assert_false(UserSettingsManager.auto_update_mods, "click turns automatic updates off")

	menu._auto_update_toggle.pressed.emit()
	assert_true(UserSettingsManager.auto_update_mods, "clicking again turns them back on")


# --- The updater's decision ---


func _updater() -> Updater:
	# Instantiated outside the tree, like the zip-safety tests: this exercises
	# only the decision, never the boot flow's network request or timers.
	return Updater.new()


func test_updater_downloads_without_asking_when_enabled() -> void:
	UserSettingsManager.update_auto_update_mods(true)
	var updater := _updater()

	assert_true(
		updater._should_download_without_asking(), "an available update is applied unprompted"
	)

	updater.free()


func test_updater_still_prompts_when_disabled() -> void:
	UserSettingsManager.update_auto_update_mods(false)
	var updater := _updater()

	assert_false(
		updater._should_download_without_asking(),
		"turning the setting off brings the download prompt back"
	)

	updater.free()
