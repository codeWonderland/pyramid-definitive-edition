class_name PackSelectPacks extends GridContainer

signal pack_added(pack_data: PackData)
signal pack_removed(pack_data: PackData)

const PAGE_SIZE: int = 12
const PACK_SELECT_CARD: PackedScene = preload(
	"res://source/menus/menu_widgets/pack_select_card.tscn"
)

var _current_page: int = 0


func _ready() -> void:
	_populate()
	get_tree().get_root().size_changed.connect(_populate)


func prev_page() -> void:
	_current_page -= 1

	if _current_page < 0:
		_current_page = floori(PackLoader.all_packs.size() / PAGE_SIZE)

		if PackLoader.all_packs.size() % PAGE_SIZE == 0:
			_current_page -= 1

	_populate()


func next_page() -> void:
	_current_page += 1

	if _current_page * PAGE_SIZE >= PackLoader.all_packs.size():
		_current_page = 0

	_populate()


func _populate() -> void:
	var visible_packs = _get_visible_packs()
	var card_size = _get_card_size()

	custom_minimum_size.y = card_size.y * 2.0 + 16.0

	# Clear Old Packs
	for child in get_children():
		child.queue_free()

	# Create New Ones
	for pack_data in visible_packs:
		var card = PACK_SELECT_CARD.instantiate()
		card.custom_minimum_size = card_size
		card.pack_data = pack_data
		card.pressed.connect(_pack_pressed)
		add_child(card)


func _get_visible_packs() -> Array[PackData]:
	var starting_index = _current_page * PAGE_SIZE
	var last_index = starting_index + PAGE_SIZE

	return PackLoader.all_packs.slice(starting_index, last_index)


func _get_card_size() -> Vector2:
	var screen_size = get_viewport().size
	var screen_scale = screen_size.x / 1280.0

	if screen_size.y / 720.0 < screen_scale:
		screen_scale = screen_size.y / 720.0

	return Vector2(0, 150.0 * screen_scale)


func _pack_pressed(pack_data: PackData, button_index: int) -> void:
	if button_index == MOUSE_BUTTON_LEFT:
		self.pack_added.emit(pack_data)
	else:
		self.pack_removed.emit(pack_data)
