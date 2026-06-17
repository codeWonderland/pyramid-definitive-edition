extends Node

signal packs_updated

# Raised when any card grab begins/ends, so the trash zone can show/hide.
signal card_drag_started
signal card_drag_ended

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

# Monotonic z-index handed out so a freshly grabbed card always sits above every
# other card in the scene. z_as_relative is turned off on cards so this is global.
var _card_z_counter: int = 100
# Global-rect of the trash zone (in viewport coordinates) while one is shown,
# used by cards to decide whether a drop should trash the card.
var _trash_zone_rect: Rect2 = Rect2()


func clear() -> void:
	selected_packs = []
	num_games = 5
	popup_open = false
	save_data = null
	_card_z_counter = 100
	_trash_zone_rect = Rect2()


# --- Card drag / z-index coordination ---


## The next z-index a grabbed card should use to float above all others.
## Capped below the popup layer (4096) so dialogs always stay on top.
func next_card_z_index() -> int:
	_card_z_counter = mini(_card_z_counter + 1, 3999)
	return _card_z_counter


func begin_card_drag() -> void:
	self.card_drag_started.emit()


func end_card_drag() -> void:
	self.card_drag_ended.emit()


func set_trash_zone_rect(rect: Rect2) -> void:
	_trash_zone_rect = rect


func point_over_trash(global_position: Vector2) -> bool:
	return _trash_zone_rect.has_area() and _trash_zone_rect.has_point(global_position)


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
