class_name CardGroupCollection extends Control

var packs: Array[PackData] = []:
	set(value):
		packs = value
		if not _loading_from_save:
			_load_packs()
var _loading_from_save: bool = false

@onready var _card_groups: Array[CardGroup] = [
	%CardGroup,
	%CardGroup2,
	%CardGroup3,
	%CardGroup4,
	%CardGroup5,
]


func _ready() -> void:
	_resize()
	get_tree().get_root().size_changed.connect(_resize)

	if RunManager.save_data == null and packs.size() > 0:
		_load_packs()

	_update_pack_visibility()


func generate_card_groups_data() -> Array[CardGroupData]:
	var card_groups_data: Array[CardGroupData] = []

	for group in _card_groups:
		if group.pack != null:
			var data: CardGroupData = group.generate_card_group_data()
			card_groups_data.append(data)

	return card_groups_data


func load_packs_from_save(save_data: SaveData) -> void:
	_loading_from_save = true

	packs = []

	for pack_path in save_data.rolled_loadout_paths:
		var pack_data: PackData = PackDataLoader.load_pack_from_path(pack_path)
		packs.append(pack_data)

	for index in range(RunManager.num_games):
		_card_groups[index].load_from_card_group_data(save_data.card_groups[index])

	_loading_from_save = false


func _resize() -> void:
	var screen_size = get_viewport().size as Vector2
	var scale_mult = screen_size.x / 1280.0

	if screen_size.y / 720.0 < scale_mult:
		scale_mult = screen_size.y / 720.0

	var card_size = RunManager.get_card_size()
	var one_row_height = card_size.y * 1.5
	var two_row_height = card_size.y * 2.5
	var second_row_y = 175.0
	if RunManager.num_games == 5:
		var section_width = 945.0
		custom_minimum_size = Vector2(section_width * scale_mult, two_row_height * scale_mult)
		_card_groups[1].position.x = (section_width / 2.0 - card_size.x) * scale_mult
		_card_groups[2].position.x = (section_width - card_size.x * 2) * scale_mult
		_card_groups[3].position = Vector2(
			((card_size.x + section_width / 2.0) / 2.0 - card_size.x) * scale_mult,
			second_row_y * scale_mult
		)
		_card_groups[4].position = Vector2(
			((section_width / 2.0 + section_width - card_size.x) / 2.0 - card_size.x) * scale_mult,
			second_row_y * scale_mult
		)
	elif RunManager.num_games == 3:
		var section_width = 1050.0
		custom_minimum_size = Vector2(section_width * scale_mult, one_row_height * scale_mult)
		_card_groups[1].position.x = ((section_width / 2.0) - card_size.x) * scale_mult
		_card_groups[2].position.x = (section_width - card_size.x * 2) * scale_mult
	else:
		custom_minimum_size = Vector2(card_size.x * 2 * scale_mult, one_row_height * scale_mult)

	size = custom_minimum_size


func _update_pack_visibility() -> void:
	if RunManager.num_games == 5:
		_card_groups[1].show()
		_card_groups[2].show()
		_card_groups[3].show()
		_card_groups[4].show()
	elif RunManager.num_games == 3:
		_card_groups[1].show()
		_card_groups[2].show()
		_card_groups[3].hide()
		_card_groups[4].hide()
	else:
		_card_groups[1].hide()
		_card_groups[2].hide()
		_card_groups[3].hide()
		_card_groups[4].hide()


func _load_packs() -> void:
	for index in range(RunManager.num_games):
		_card_groups[index].pack = packs[index]
