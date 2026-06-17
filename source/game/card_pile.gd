class_name CardPile extends Control

## A face-down draw pile rendered as a small stack of card backs. It sits behind
## the active card; once that card is dragged away the pile is exposed and the
## player can click it to draw (or press-and-drag to draw a card that follows
## the cursor). The owning CardGroup does the actual drawing.
signal draw_requested(start_dragging: bool)

const DRAG_THRESHOLD: float = 6.0
const STACK_COUNT: int = 3
const STACK_OFFSET: float = 2.0

var _pressed: bool = false
var _emitted: bool = false
var _press_global_position: Vector2 = Vector2.ZERO
var _backs: Array[TextureRect] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(_on_gui_input)


## (Re)build the visible stack of backs at the given card size.
func setup(back_texture: Texture2D, card_size: Vector2) -> void:
	for back in _backs:
		back.queue_free()
	_backs.clear()

	for i in range(STACK_COUNT):
		var back := TextureRect.new()
		back.texture = back_texture
		back.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		back.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		back.custom_minimum_size = card_size
		back.size = card_size
		back.position = Vector2(i, i) * STACK_OFFSET
		back.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(back)
		_backs.append(back)

	custom_minimum_size = card_size + Vector2.ONE * STACK_OFFSET * (STACK_COUNT - 1)
	size = custom_minimum_size


## Reflect how many cards remain: hide the pile entirely when empty.
func set_remaining(count: int) -> void:
	visible = count > 0
	for i in range(_backs.size()):
		_backs[i].visible = count > (STACK_COUNT - 1 - i)


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and visible and not RunManager.popup_open:
			_pressed = true
			_emitted = false
			_press_global_position = event.global_position
			accept_event()


func _input(event: InputEvent) -> void:
	if not _pressed:
		return

	if event is InputEventMouseMotion:
		# Drag off the pile -> draw a card that immediately follows the cursor.
		if (
			not _emitted
			and event.global_position.distance_to(_press_global_position) > DRAG_THRESHOLD
		):
			_emitted = true
			_pressed = false
			self.draw_requested.emit(true)
	elif (
		event is InputEventMouseButton
		and event.button_index == MOUSE_BUTTON_LEFT
		and not event.pressed
	):
		# A click with no drag -> draw a card into the slot.
		if not _emitted:
			self.draw_requested.emit(false)
		_pressed = false
		_emitted = false
