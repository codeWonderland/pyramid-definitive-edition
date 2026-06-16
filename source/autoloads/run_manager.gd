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
				var pack = PackDataLoader.load_pack_from_path(path)
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
	var index := selected_packs.find(pack_data)
	if index == -1:
		return

	selected_packs.remove_at(index)
	self.packs_updated.emit()


func get_random_loadout() -> Array[PackData]:
	var loadout: Array[PackData] = []

	if selected_packs.is_empty():
		return loadout

	# Work on a copy so "getting" a loadout doesn't reorder the player's
	# persistent selection, and never alias it into the returned array.
	var pool := selected_packs.duplicate()
	pool.shuffle()

	if num_games <= pool.size():
		return pool.slice(0, num_games)

	# Fewer packs selected than games: use them all, then pad with random repeats.
	loadout = pool.duplicate()
	for _index in range(num_games - pool.size()):
		loadout.append(pool.pick_random())

	return loadout


func get_card_size() -> Vector2:
	if num_games == 1:
		return Vector2(210, 300)

	if num_games == 3:
		return Vector2(157.5, 225)

	return Vector2(105, 150)
