class_name ChallengeCard extends TextureRect

signal pressed

@export var focus_on_hover: bool = false


func _ready() -> void:
	_resize()
	get_tree().get_root().size_changed.connect(_resize)
	gui_input.connect(_on_gui_input)


func _physics_process(_delta: float) -> void:
	if not focus_on_hover:
		return

	var local_mouse_pos := get_local_mouse_position()
	var hovering := Rect2(Vector2.ZERO, size).has_point(local_mouse_pos)
	# These extra checks are here because we are only
	# using hover effects on curse cards, and we want
	# to be thoroughly in the card before triggering
	if (
		hovering
		and local_mouse_pos.y >= size.y * 0.25
		and local_mouse_pos.x >= size.x * 0.1
		and local_mouse_pos.x <= size.x * 0.9
	):
		z_index = 2
	else:
		z_index = 0


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.is_pressed():
		self.pressed.emit()


func _resize() -> void:
	var screen_size = get_viewport().size as Vector2
	var scale_mult = screen_size.x / 1280.0

	if screen_size.y / 720.0 < scale_mult:
		scale_mult = screen_size.y / 720.0

	var card_size = RunManager.get_card_size()
	custom_minimum_size = Vector2(card_size.x * scale_mult, card_size.y * scale_mult)
	size = custom_minimum_size
