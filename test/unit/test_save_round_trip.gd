extends GutTest

# Regression test for the save-persistence fix: SaveData / CardGroupData fields
# must be @export so ConfigFile actually serializes them (otherwise every save
# came back empty after a restart). This mirrors how SaveManager persists saves.

var _path: String


func before_each() -> void:
	_path = "user://test_save_%d.cfg" % randi()


func after_each() -> void:
	if FileAccess.file_exists(_path):
		DirAccess.remove_absolute(_path)


func _make_save() -> SaveData:
	var group := CardGroupData.new()
	group.pack_path = "user://mods/example/PACKS/CoolPack"
	group.primary_deck = [0, 2, -1, 5]
	group.secondary_deck = [1, 0, 3]
	group.table_cards = [
		{"entry": 4, "secondary": false, "curse": false, "x": 12.0, "y": 34.0},
		{"entry": -2, "secondary": false, "curse": true, "x": 56.0, "y": 78.0},
	]

	var save := SaveData.new()
	save.title = "My Run"
	save.selected_pack_paths = ["a/b", "c/d"]
	save.rolled_loadout_paths = ["a/b"]
	save.num_games = 3
	save.card_groups = [group]
	return save


func test_save_data_survives_configfile_round_trip() -> void:
	var saves: Array[SaveData] = [_make_save(), null, null]

	var write := ConfigFile.new()
	write.set_value("user_data", "saves", saves)
	assert_eq(write.save(_path), OK, "config saved")

	var read := ConfigFile.new()
	assert_eq(read.load(_path), OK, "config loaded")

	var loaded = read.get_value("user_data", "saves", [])
	assert_eq(loaded.size(), 3)

	var first: SaveData = loaded[0]
	assert_not_null(first, "first slot round-tripped")
	assert_eq(first.title, "My Run", "title persisted")
	assert_eq(first.num_games, 3, "num_games persisted")
	assert_eq(first.selected_pack_paths, ["a/b", "c/d"], "pack paths persisted")
	assert_eq(first.card_groups.size(), 1, "nested card groups persisted")


func test_nested_card_group_fields_persist() -> void:
	var write := ConfigFile.new()
	write.set_value("user_data", "saves", [_make_save()])
	write.save(_path)

	var read := ConfigFile.new()
	read.load(_path)
	var first: SaveData = read.get_value("user_data", "saves", [])[0]
	var group: CardGroupData = first.card_groups[0]

	assert_eq(group.pack_path, "user://mods/example/PACKS/CoolPack")
	assert_eq(group.primary_deck, [0, 2, -1, 5], "primary deck order persisted")
	assert_eq(group.secondary_deck, [1, 0, 3], "secondary deck order persisted")
	assert_eq(group.table_cards.size(), 2, "table cards persisted")
	assert_eq(group.table_cards[1]["curse"], true, "per-card flags persisted")
	assert_eq(group.table_cards[0]["x"], 12.0, "card positions persisted")
