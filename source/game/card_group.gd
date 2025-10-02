class_name CardGroup extends Control

var pack: PackData = null:
	set(value):
		pack = value
		_load_pack()

@onready var _primary: ChallengeCard = %Primary
@onready var _secondary: ChallengeCard = %Secondary
@onready var _curse: ChallengeCard = %Curse


func _ready() -> void:
	_resize()
	get_tree().get_root().size_changed.connect(_resize)

	if pack != null:
		_load_pack()

	_primary.pressed.connect(_redraw_primary)
	_secondary.pressed.connect(_redraw_secondary)
	_curse.pressed.connect(_redraw_curse)


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


func _load_pack() -> void:
	var has_curse = randf() <= 0.05 and pack.curses.size() > 0

	if has_curse:
		_curse.texture = pack.curses.pick_random()
		_curse.show()
	else:
		_curse.hide()

	_primary.texture = pack.primaries.pick_random()

	if pack.secondaries.size() > 0:
		_secondary.texture = pack.secondaries.pick_random()
		_secondary.show()
	else:
		_secondary.hide()


func _redraw_primary() -> void:
	if RunManager.popup_open:
		return

	_primary.texture = pack.primaries.pick_random()


func _redraw_secondary() -> void:
	if RunManager.popup_open:
		return

	_secondary.texture = pack.secondaries.pick_random()


func _redraw_curse() -> void:
	if RunManager.popup_open:
		return

	_curse.texture = pack.curses.pick_random()
