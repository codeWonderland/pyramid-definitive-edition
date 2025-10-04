extends Node

signal packs_updated

var selected_packs: Array[PackData] = []
var num_games: int = 5
var popup_open: bool = false
var save_data: SaveData = null:
	set(value):
		save_data = value

		if value != null:
			selected_packs = []

			for path in value.selected_pack_paths:
				var pack = PackLoader.load_pack_from_path(path)
				selected_packs.append(pack)

			num_games = value.num_games


func clear() -> void:
	selected_packs = []
	num_games = 5
	popup_open = false
	save_data = null


func add_pack(pack_data: PackData) -> void:
	if selected_packs.size() < 10:
		selected_packs.append(pack_data)
		self.packs_updated.emit()


func remove_pack(pack_data: PackData) -> void:
	var index = 0
	for pack in selected_packs:
		if pack.title == pack_data.title:
			selected_packs.remove_at(index)
			break

		index += 1
	self.packs_updated.emit()


func get_random_loadout() -> Array[PackData]:
	var loadout: Array[PackData] = []
	selected_packs.shuffle()

	if num_games == selected_packs.size():
		loadout = selected_packs
	elif num_games < selected_packs.size():
		loadout = selected_packs.slice(0, num_games)
	else:
		for pack in selected_packs:
			loadout.append(pack)

		for _index in range(num_games - selected_packs.size()):
			loadout.append(selected_packs.pick_random())

	return loadout


func get_card_size() -> Vector2:
	if num_games == 1:
		return Vector2(210, 300)

	if num_games == 3:
		return Vector2(157.5, 225)

	return Vector2(105, 150)
