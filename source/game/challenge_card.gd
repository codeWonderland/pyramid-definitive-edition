class_name ChallengeCard extends TextureRect

signal pressed

## Pixels the pointer must travel while held before a press becomes a drag.
## Below this, releasing counts as a click (which re-rolls the card).
const DRAG_THRESHOLD: float = 6.0
## z_index used while dragging so the card floats above its siblings.
const DRAG_Z_INDEX: int = 10

# Velocity-based tilt: drag velocity (px/sec) maps to a pitch/roll lean.
const TILT_SHADER: Shader = preload("res://source/game/card_tilt.gdshader")
## Radians of lean per px/sec of drag velocity (sign flips the lean direction).
const ROLL_PER_VELOCITY: float = 0.0004
const PITCH_PER_VELOCITY: float = -0.0004
## Hard cap on the lean so a fast flick stays believable (radians).
const MAX_TILT: float = 0.4
## How quickly the current lean chases its target (higher = snappier).
const TILT_RESPONSE: float = 14.0

@export var is_curse: bool = false
@export var accounting_for_curse: bool = false

var hovering: bool = false

var _pressed: bool = false
var _dragging: bool = false
var _press_global_position: Vector2 = Vector2.ZERO
# Parent-local offset between the card's position and the mouse at grab time,
# so the point we grabbed stays under the cursor for the whole drag.
var _grab_offset: Vector2 = Vector2.ZERO

# Mouse motion accumulated since the last _process frame, converted to a
# velocity there so a stationary hold naturally flattens the card back out.
var _frame_motion: Vector2 = Vector2.ZERO
var _pitch: float = 0.0
var _roll: float = 0.0
var _tilt_material: ShaderMaterial


func _ready() -> void:
	_setup_tilt_material()
	_resize()
	get_tree().get_root().size_changed.connect(_resize)
	gui_input.connect(_on_gui_input)


func _setup_tilt_material() -> void:
	_tilt_material = ShaderMaterial.new()
	_tilt_material.shader = TILT_SHADER
	material = _tilt_material


func _process(delta: float) -> void:
	# Convert this frame's accumulated motion into a velocity (zero when the
	# card is held still or not being dragged), then ease the lean toward it.
	var velocity := _frame_motion / maxf(delta, 0.0001)
	_frame_motion = Vector2.ZERO

	var target_roll := 0.0
	var target_pitch := 0.0
	if _dragging:
		target_roll = clampf(velocity.x * ROLL_PER_VELOCITY, -MAX_TILT, MAX_TILT)
		target_pitch = clampf(velocity.y * PITCH_PER_VELOCITY, -MAX_TILT, MAX_TILT)

	var weight := clampf(delta * TILT_RESPONSE, 0.0, 1.0)
	_roll = lerpf(_roll, target_roll, weight)
	_pitch = lerpf(_pitch, target_pitch, weight)

	_tilt_material.set_shader_parameter("roll", _roll)
	_tilt_material.set_shader_parameter("pitch", _pitch)


func _physics_process(_delta: float) -> void:
	# While dragging, position and z_index are driven by the drag; skip the hover
	# logic so it doesn't fight for control of either.
	if _dragging:
		return

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
	# Begin a potential click/drag on left-press. Motion and release are handled
	# in _input() so we keep receiving events even when the cursor leaves the
	# card's rect during a fast drag.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if RunManager.popup_open:
				return
			_pressed = true
			_dragging = false
			_press_global_position = event.global_position
			_grab_offset = position - get_parent().get_local_mouse_position()
			accept_event()


func _input(event: InputEvent) -> void:
	if not _pressed:
		return

	if event is InputEventMouseMotion:
		if (
			not _dragging
			and event.global_position.distance_to(_press_global_position) > DRAG_THRESHOLD
		):
			_begin_drag()

		if _dragging:
			position = get_parent().get_local_mouse_position() + _grab_offset
			_frame_motion += event.relative
			get_viewport().set_input_as_handled()
	elif (
		event is InputEventMouseButton
		and event.button_index == MOUSE_BUTTON_LEFT
		and not event.pressed
	):
		_end_press()


func _begin_drag() -> void:
	_dragging = true
	z_index = DRAG_Z_INDEX


func _end_press() -> void:
	var was_dragging := _dragging
	_pressed = false
	_dragging = false

	if was_dragging:
		# Drop the card where it was released; let the hover loop reclaim z_index.
		z_index = 0
		get_viewport().set_input_as_handled()
	else:
		# A click with no drag re-rolls the card (preserves the old behavior).
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

	# Keep the tilt shader's quad dimensions in sync with the on-screen size.
	if _tilt_material != null:
		_tilt_material.set_shader_parameter("card_size", size)
