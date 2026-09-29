extends GutTest

# Tests the player's own marks on games (#36): toggling, persistence, the
# owned/don't-own contradiction, and Favorite staying in sync with the hearts.

const FAKE_PATH: String = "user://__test_marks_pack__"


func after_each() -> void:
	for mark in PlayerMarksManager.MARKS:
		PlayerMarksManager.set_mark(FAKE_PATH, mark["id"], false)


func test_ten_marks_are_offered() -> void:
	assert_eq(PlayerMarksManager.MARKS.size(), 10, "every mark from the issue")


func test_set_and_clear_a_mark() -> void:
	PlayerMarksManager.set_mark(FAKE_PATH, "never_draft", true)
	assert_true(PlayerMarksManager.has_mark(FAKE_PATH, "never_draft"), "mark set")

	PlayerMarksManager.set_mark(FAKE_PATH, "never_draft", false)
	assert_false(PlayerMarksManager.has_mark(FAKE_PATH, "never_draft"), "mark cleared")


func test_marks_are_independent() -> void:
	PlayerMarksManager.set_mark(FAKE_PATH, "too_long", true)
	PlayerMarksManager.set_mark(FAKE_PATH, "avoid_on_stream", true)

	assert_eq(
		PlayerMarksManager.marks_for(FAKE_PATH),
		["avoid_on_stream", "too_long"],
		"both kept, reported in display order"
	)


func test_owned_and_dont_own_exclude_each_other() -> void:
	PlayerMarksManager.set_mark(FAKE_PATH, "owned", true)
	PlayerMarksManager.set_mark(FAKE_PATH, "dont_own", true)

	assert_false(PlayerMarksManager.has_mark(FAKE_PATH, "owned"), "setting don't own clears owned")
	assert_true(PlayerMarksManager.has_mark(FAKE_PATH, "dont_own"), "and keeps don't own")

	PlayerMarksManager.set_mark(FAKE_PATH, "owned", true)
	assert_false(PlayerMarksManager.has_mark(FAKE_PATH, "dont_own"), "and the other way round")


func test_favorite_is_the_same_as_the_draft_screen_heart() -> void:
	PlayerMarksManager.set_mark(FAKE_PATH, "favorite", true)
	assert_true(FavoritesManager.is_favorite(FAKE_PATH), "marking favorite fills the heart")

	FavoritesManager.toggle(FAKE_PATH)
	assert_false(
		PlayerMarksManager.has_mark(FAKE_PATH, "favorite"), "and un-hearting clears the mark"
	)


func test_unknown_marks_are_ignored() -> void:
	PlayerMarksManager.set_mark(FAKE_PATH, "definitely_not_a_mark", true)

	assert_eq(PlayerMarksManager.marks_for(FAKE_PATH), [], "an unknown mark is not stored")


func test_changing_a_mark_emits() -> void:
	watch_signals(PlayerMarksManager)
	PlayerMarksManager.set_mark(FAKE_PATH, "owned", true)
	assert_signal_emitted_with_parameters(PlayerMarksManager, "marks_changed", [FAKE_PATH])


func test_setting_a_mark_it_already_has_does_not_emit() -> void:
	PlayerMarksManager.set_mark(FAKE_PATH, "owned", true)
	watch_signals(PlayerMarksManager)

	PlayerMarksManager.set_mark(FAKE_PATH, "owned", true)

	assert_signal_not_emitted(PlayerMarksManager, "marks_changed")


func test_marks_persist_to_disk() -> void:
	PlayerMarksManager.set_mark(FAKE_PATH, "controller_friendly", true)

	var config := ConfigFile.new()
	assert_eq(config.load(PlayerMarksManager.SAVE_PATH), OK, "marks file written")
	var stored: Dictionary = config.get_value("marks", "packs", {})
	assert_true(stored.get(FAKE_PATH, []).has("controller_friendly"), "the mark is on disk")


func test_clearing_the_last_mark_removes_the_pack_from_disk() -> void:
	PlayerMarksManager.set_mark(FAKE_PATH, "owned", true)
	PlayerMarksManager.set_mark(FAKE_PATH, "owned", false)

	var config := ConfigFile.new()
	config.load(PlayerMarksManager.SAVE_PATH)
	var stored: Dictionary = config.get_value("marks", "packs", {})
	assert_false(stored.has(FAKE_PATH), "no empty entries left behind")
