class_name ChallengeCard extends TextureRect

signal pressed

@export var is_curse: bool = false
@export var accounting_for_curse: bool = false

var hovering: bool = false


func _ready() -> void:
	_resize()
	get_tree().get_root().size_changed.connect(_resize)
	gui_input.connect(_on_gui_input)


func _physics_process(_delta: float) -> void:
	var local_mouse_pos := get_local_mouse_position()
	var mouse_over_card := Rect2(Vector2.ZERO, size).has_point(local_mouse_pos)

	if (
		mouse_over_card
		and (
			(is_curse and local_mouse_pos.y >= size.y * 0.25)
			or (!is_curse and accounting_for_curse and local_mouse_pos.y <= size.y * 0.50)
			or (!is_curse and !accounting_for_curse)
		)
		and local_mouse_pos.x >= size.x * 0.1
		and local_mouse_pos.x <= size.x * 0.9
	):
		if is_curse:
			z_index = 3
		else:
			z_index = 2

		if not hovering:
			var size_tween = create_tween()
			size_tween.tween_property(self, "scale", Vector2(1.25, 1.25), 0.2)

		hovering = true
	else:
		z_index = 0

		if hovering:
			var size_tween = create_tween()
			size_tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.2)

		hovering = false


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
	pivot_offset = Vector2(size.x / 2, size.y / 2)
