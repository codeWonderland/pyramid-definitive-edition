extends GutTest

# Tests the duplicate-culling setting on UserSettingsManager: it defaults on,
# round-trips through the settings file, and announces changes so open UI can
# follow along.

var _saved_culling: bool


func before_each() -> void:
	_saved_culling = UserSettingsManager.duplicate_culling


func after_each() -> void:
	UserSettingsManager.update_duplicate_culling(_saved_culling)


func test_defaults_to_on() -> void:
	var config := ConfigFile.new()
	config.load(UserSettingsManager.SAVE_PATH)
	assert_true(
		config.get_value("settings", "duplicate_culling", true),
		"a settings file without the key reads as culling enabled"
	)


func test_update_emits_signal() -> void:
	watch_signals(UserSettingsManager)
	UserSettingsManager.update_duplicate_culling(false)
	assert_signal_emitted(UserSettingsManager, "duplicate_culling_updated")


func test_update_persists_to_disk() -> void:
	UserSettingsManager.update_duplicate_culling(false)

	var config := ConfigFile.new()
	assert_eq(config.load(UserSettingsManager.SAVE_PATH), OK, "settings file written")
	assert_false(
		config.get_value("settings", "duplicate_culling", true), "culling off persisted to disk"
	)

	UserSettingsManager.update_duplicate_culling(true)
	assert_eq(config.load(UserSettingsManager.SAVE_PATH), OK, "settings file written again")
	assert_true(
		config.get_value("settings", "duplicate_culling", false), "culling on persisted to disk"
	)
