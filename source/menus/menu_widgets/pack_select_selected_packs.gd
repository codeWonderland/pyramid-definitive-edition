class_name PackSelectSelectedPacks extends HBoxContainer

signal pack_pressed

const PACK_SELECT_CARD: PackedScene = preload(
	"res://source/menus/menu_widgets/pack_select_card.tscn"
)


func _ready() -> void:
	_populate()
	get_tree().get_root().size_changed.connect(_populate)
	RunManager.packs_updated.connect(_populate)


func _populate() -> void:
	var card_size = _get_card_size()

	custom_minimum_size.y = card_size.y

	for child in get_children():
		child.queue_free()

	for pack_data in RunManager.selected_packs:
		var card = PACK_SELECT_CARD.instantiate()
		card.custom_minimum_size = card_size
		card.pack_data = pack_data
		card.pressed.connect(_pack_pressed)
		add_child(card)


func _get_card_size() -> Vector2:
	var screen_size = get_viewport().size
	var screen_scale = screen_size.x / 1280.0

	if screen_size.y / 720.0 < screen_scale:
		screen_scale = screen_size.y / 720.0

	return Vector2(0, 75.0 * screen_scale)


func _pack_pressed(pack_data: PackData, _button_index: int) -> void:
	self.pack_pressed.emit(pack_data)
