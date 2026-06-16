extends GutTest

# Tests for RunManager.get_random_loadout() — must not reorder or alias the
# player's persistent selection, must pad when there are fewer packs than
# games, and must not crash on an empty selection.


func _packs(count: int) -> Array[PackData]:
	var packs: Array[PackData] = []
	for i in range(count):
		var p := PackData.new()
		p.title = "Pack%d" % i
		p.folder_path = "user://mods/p%d" % i
		packs.append(p)
	return packs


func after_each() -> void:
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
