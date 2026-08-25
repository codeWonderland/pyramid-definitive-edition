extends GutTest

# Tests for RunManager.get_random_loadout() — must not reorder or alias the
# player's persistent selection, must pad when there are fewer packs than
# games, and must not crash on an empty selection.
#
# Also covers the duplicate-culling setting: on (the default) a draft must not
# repeat a pack while an undrafted one is still available; off, every slot is an
# independent roll and repeats are allowed.

# Enough trials that "culling off eventually repeats a pack" is not flaky: with
# 5 packs over 5 slots the chance of an all-distinct roll is ~3.8%, so the odds
# of every trial coming back distinct are vanishingly small.
const TRIALS: int = 50

var _saved_culling: bool


func _packs(count: int) -> Array[PackData]:
	var packs: Array[PackData] = []
	for i in range(count):
		var p := PackData.new()
		p.title = "Pack%d" % i
		p.folder_path = "user://mods/p%d" % i
		packs.append(p)
	return packs


func _has_duplicate(loadout: Array[PackData]) -> bool:
	var seen := {}
	for pack in loadout:
		if seen.has(pack.folder_path):
			return true
		seen[pack.folder_path] = true
	return false


func before_each() -> void:
	# Set the field directly rather than going through update_duplicate_culling()
	# so the test never writes the player's real settings file.
	_saved_culling = UserSettingsManager.duplicate_culling
	UserSettingsManager.duplicate_culling = true


func after_each() -> void:
	UserSettingsManager.duplicate_culling = _saved_culling
	RunManager.clear()


func test_empty_selection_returns_empty_loadout() -> void:
	RunManager.selected_packs = []
	RunManager.num_games = 5

	assert_eq(RunManager.get_random_loadout(), [], "no crash, empty loadout")


func test_loadout_matches_num_games_when_enough_packs() -> void:
	RunManager.selected_packs = _packs(5)
	RunManager.num_games = 3

	var loadout := RunManager.get_random_loadout()
	assert_eq(loadout.size(), 3, "loadout trimmed to num_games")


func test_pads_when_fewer_packs_than_games() -> void:
	RunManager.selected_packs = _packs(2)
	RunManager.num_games = 5

	var loadout := RunManager.get_random_loadout()
	assert_eq(loadout.size(), 5, "loadout padded up to num_games")
	for pack in loadout:
		assert_not_null(pack, "padding never inserts null")


func test_does_not_reorder_or_alias_selection() -> void:
	var original := _packs(5)
	RunManager.selected_packs = original.duplicate()
	RunManager.num_games = 5

	var loadout := RunManager.get_random_loadout()

	# The persistent selection keeps its original order...
	for i in range(original.size()):
		assert_eq(
			RunManager.selected_packs[i].title,
			original[i].title,
			"selected_packs order is preserved"
		)
	# ...and the returned loadout is a distinct array: mutating it must not
	# affect the persistent selection.
	var selection_size := RunManager.selected_packs.size()
	loadout.append(PackData.new())
	assert_eq(
		RunManager.selected_packs.size(),
		selection_size,
		"mutating the loadout does not change the selection (no aliasing)"
	)


func test_culling_on_never_repeats_when_enough_packs() -> void:
	RunManager.selected_packs = _packs(5)
	RunManager.num_games = 5

	for _trial in range(TRIALS):
		var loadout := RunManager.get_random_loadout()
		assert_false(_has_duplicate(loadout), "culling on: no repeated pack")


func test_culling_on_uses_every_pack_before_repeating() -> void:
	# 2 packs over 3 games: both must appear before the pad slot repeats one.
	RunManager.selected_packs = _packs(2)
	RunManager.num_games = 3

	for _trial in range(TRIALS):
		var loadout := RunManager.get_random_loadout()
		var titles := {}
		for pack in loadout:
			titles[pack.title] = true
		assert_eq(titles.size(), 2, "culling on: every selected pack drafted once first")


func test_culling_off_allows_repeats() -> void:
	UserSettingsManager.duplicate_culling = false
	RunManager.selected_packs = _packs(5)
	RunManager.num_games = 5

	var saw_duplicate := false
	for _trial in range(TRIALS):
		if _has_duplicate(RunManager.get_random_loadout()):
			saw_duplicate = true
			break

	assert_true(saw_duplicate, "culling off: a pack can be drafted more than once")


func test_culling_off_still_fills_every_slot() -> void:
	UserSettingsManager.duplicate_culling = false
	RunManager.selected_packs = _packs(3)
	RunManager.num_games = 5

	var loadout := RunManager.get_random_loadout()
	assert_eq(loadout.size(), 5, "culling off: loadout still matches num_games")
	for pack in loadout:
		assert_not_null(pack, "culling off: no null slots")


func test_culling_off_with_empty_selection_is_safe() -> void:
	UserSettingsManager.duplicate_culling = false
	RunManager.selected_packs = []
	RunManager.num_games = 5

	assert_eq(RunManager.get_random_loadout(), [], "culling off: empty selection still safe")
