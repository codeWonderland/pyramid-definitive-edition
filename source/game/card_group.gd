class_name CardGroup extends Control

var pack: PackData = null:
	set(value):
		pack = value

		if not _loading_from_save:
			_roll_cards()
			_load_cards()

var _primary_index: int = -1
var _secondary_index: int = -1
var _curse_index: int = -1
var _loading_from_save: bool = false

@onready var _primary: ChallengeCard = %Primary
@onready var _secondary: ChallengeCard = %Secondary
@onready var _curse: ChallengeCard = %Curse


func _ready() -> void:
	_resize()
	get_tree().get_root().size_changed.connect(_resize)

	if pack != null:
		_roll_cards()
		_load_cards()

	_primary.pressed.connect(_redraw_primary)
	_secondary.pressed.connect(_redraw_secondary)
	_curse.pressed.connect(_redraw_curse)


func generate_card_group_data() -> CardGroupData:
	var data = CardGroupData.new()

	data.pack_path = pack.folder_path
	data.primary = _primary_index
	data.secondary = _secondary_index
	data.curse = _curse_index

	return data


func load_from_card_group_data(data: CardGroupData) -> void:
	_loading_from_save = true

	pack = PackLoader.load_pack_from_path(data.pack_path)
	_primary_index = data.primary
	_secondary_index = data.secondary
	_curse_index = data.curse

	_load_cards()

	_loading_from_save = false


func _resize() -> void:
	var screen_size = get_viewport().size as Vector2
	var scale_mult = screen_size.x / 1280.0

	if screen_size.y / 720.0 < scale_mult:
		scale_mult = screen_size.y / 720.0

	var card_size = RunManager.get_card_size()
	custom_minimum_size = Vector2(card_size.x * 2 * scale_mult, card_size.y * 1.5 * scale_mult)
	size = custom_minimum_size

	_secondary.position.x = card_size.x * scale_mult
	_curse.position = Vector2(card_size.x / 2 * scale_mult, card_size.x / 2 * scale_mult)


func _roll_cards() -> void:
	var has_curse = randf() <= 0.05 and pack.curses.size() > 0

	if has_curse:
		_curse_index = randi() % pack.curses.size()
	else:
		_curse_index = -1

	_primary_index = randi() % pack.primaries.size()

	if pack.secondaries.size() > 0:
		_secondary_index = randi() % pack.secondaries.size()
		_secondary.texture = pack.secondaries[_secondary_index]
	else:
		_secondary_index = -1

	_load_cards()


func _load_cards() -> void:
	_primary.texture = pack.primaries[_primary_index]
	_primary.accounting_for_curse = _curse_index != -1

	if _secondary_index != -1:
		_secondary.texture = pack.secondaries[_secondary_index]
		_secondary.accounting_for_curse = _curse_index != -1
		_secondary.show()
	else:
		_secondary.hide()

	if _curse_index != -1:
		_curse.texture = pack.curses[_curse_index]
		_curse.show()
	else:
		_curse.hide()


func _redraw_primary() -> void:
	if RunManager.popup_open:
		return

	if _curse.visible and _curse.hovering:
		return

	_primary_index = randi() % pack.primaries.size()
	_primary.texture = pack.primaries[_primary_index]


func _redraw_secondary() -> void:
	if RunManager.popup_open:
		return

	if _curse.visible and _curse.hovering:
		return

	_secondary_index = randi() % pack.secondaries.size()
	_secondary.texture = pack.secondaries[_secondary_index]


func _redraw_curse() -> void:
	if RunManager.popup_open:
		return

	_curse_index = randi() % pack.curses.size()
	_curse.texture = pack.curses[_curse_index]
