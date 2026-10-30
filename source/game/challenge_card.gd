class_name ChallengeCard extends TextureRect

signal pressed
## Emitted when this card is released over the trash zone; the owning CardGroup
## routes the card back to the bottom of its deck and frees it.
signal request_trash(card: ChallengeCard)
## Emitted when the player marks the challenge met or missed, or clears the mark.
signal result_changed

## How the player says the challenge went. A curse has no result to record.
enum Result { NONE, MET, MISSED }

## Pixels the pointer must travel while held before a press becomes a drag.
## Below this, releasing counts as a click.
const DRAG_THRESHOLD: float = 6.0
## How long a deal/flip takes, in seconds.
const FLIP_TIME: float = 0.22
## How much a hovered card grows, and how fast.
const HOVER_SCALE: float = 1.25
const HOVER_TIME: float = 0.2
## Where a hovered card is lifted to: the top of the cards' z band (2-1900), so it
## shows over every other card while hovered.
const HOVER_Z: int = 1900
## The result badge's size as a share of the card's width, and its inset.
const BADGE_SHARE: float = 0.26
const BADGE_INSET: float = 0.05

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

# Deck bookkeeping set by the owning CardGroup so a trashed card can be routed
# back to the right pile. deck_entry is a CardDeck-encoded int.
var deck_entry: int = 0
var deck_is_secondary: bool = false
var back_texture: Texture2D = null
## The card's face, kept while it is showing its back so it can be flipped over
## later. Set through set_face_down/set_face_up/play_flip rather than directly.
var front_texture: Texture2D = null
## True while this card is showing its back. Face-down cards still drag normally.
var face_down: bool = false

var hovering: bool = false
## How the challenge went, set through the corner badge. Kept while the card is
## turned face-down, and saved with the table.
var result: Result = Result.NONE:
	set(value):
		result = value
		if _badge != null:
			_badge.result = value
			_update_badge()

var _pressed: bool = false
var _dragging: bool = false
var _flipping: bool = false
var _press_global_position: Vector2 = Vector2.ZERO
# Parent-local offset between the card's position and the mouse at grab time,
# so the point we grabbed stays under the cursor for the whole drag.
var _grab_offset: Vector2 = Vector2.ZERO

# Mouse motion accumulated since the last _process frame, converted to a
# velocity there so a stationary hold naturally flattens the card back out.
var _frame_motion: Vector2 = Vector2.ZERO
var _pitch: float = 0.0
var _roll: float = 0.0
# The two factors scale is made of (see _tween_hover).
var _hover_scale: float = 1.0
var _flip_width: float = 1.0
var _hover_tween: Tween = null
# The z-index the card returns to when it stops being hovered.
var _rest_z: int = 0
var _tilt_material: ShaderMaterial

@onready var _badge: ResultBadge = %ResultBadge


func _ready() -> void:
	_badge.result = result
	_badge.clicked.connect(cycle_result)
	_update_badge()
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
	if _dragging and not _flipping:
		target_roll = clampf(velocity.x * ROLL_PER_VELOCITY, -MAX_TILT, MAX_TILT)
		target_pitch = clampf(velocity.y * PITCH_PER_VELOCITY, -MAX_TILT, MAX_TILT)

	var weight := clampf(delta * TILT_RESPONSE, 0.0, 1.0)
	_roll = lerpf(_roll, target_roll, weight)
	_pitch = lerpf(_pitch, target_pitch, weight)

	_tilt_material.set_shader_parameter("roll", _roll)
	_tilt_material.set_shader_parameter("pitch", _pitch)


## Hovers or un-hovers the card. The table decides which card that is - only the
## top one under the cursor - so overlapping cards never all grow at once. A
## hovered card is lifted above the rest while it's hovered, so its grown edges
## don't slip under a neighbouring game's cards, and drops back after.
func set_hovered(on: bool) -> void:
	if _dragging or _flipping or on == hovering:
		return
	hovering = on
	_tween_hover(HOVER_SCALE if on else 1.0)
	_update_badge()
	if on:
		_rest_z = z_index
		z_index = HOVER_Z
	else:
		z_index = _rest_z


## Whether this card is drawn over `other`: a higher z-index wins, and on a tie,
## the one later in the tree - which is what the screen shows, and what mouse
## clicks already go by.
func is_drawn_above(other: ChallengeCard) -> bool:
	if z_index != other.z_index:
		return z_index > other.z_index
	return is_greater_than(other)


func _on_gui_input(event: InputEvent) -> void:
	# Right-click inspects the card, matching what right-click already means on
	# the draft screen. Ignored mid-drag so a stray click can't interrupt one.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		if event.pressed and not RunManager.popup_open and not _dragging:
			RunManager.request_card_inspect(texture, get_global_rect())
		return

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


## Raise this card above every other card in the scene (the user's "highest
## z-index on grab"). z_as_relative is off so the index is scene-global.
func bring_to_front() -> void:
	z_as_relative = false
	set_hovered(false)
	z_index = RunManager.next_card_z_index()
	_rest_z = z_index


func _begin_drag() -> void:
	Motion.settle(self)
	_dragging = true
	bring_to_front()
	RunManager.begin_card_drag()


func _end_press() -> void:
	var was_dragging := _dragging
	_pressed = false
	_dragging = false

	if not was_dragging:
		# A click with no drag.
		self.pressed.emit()
		return

	RunManager.end_card_drag()
	get_viewport().set_input_as_handled()

	# Dropped over the trash zone: hand ourselves back to the owning group.
	if RunManager.point_over_trash(get_global_mouse_position()):
		self.request_trash.emit(self)


## Show this card face-down, remembering its face for a later reveal. Falls back
## to the face when the pack has no back image, so a card is never blank.
func set_face_down(front: Texture2D) -> void:
	front_texture = front
	face_down = true
	texture = back_texture if back_texture != null else front
	_update_badge()


## Show this card face-up straight away, with no animation.
func set_face_up(front: Texture2D) -> void:
	front_texture = front
	face_down = false
	texture = front
	_update_badge()


## Flip a face-down card over. Does nothing to a card that is already face-up,
## so revealing the whole table twice is harmless.
func reveal() -> void:
	if not face_down:
		return

	play_flip(front_texture)


## Hovering grows the card and flipping narrows it, often both at once, so each is
## kept as its own factor and scale is their product. Tweening scale directly let
## a flip finish at full width on a card still grown by hover - stretched until
## the cursor left.
func _tween_hover(to: float) -> void:
	if _hover_tween != null and _hover_tween.is_valid():
		_hover_tween.kill()
	_hover_tween = create_tween()
	_hover_tween.tween_method(_set_hover_scale, _hover_scale, to, HOVER_TIME)


func _set_hover_scale(value: float) -> void:
	_hover_scale = value
	scale = Vector2(_hover_scale * _flip_width, _hover_scale)


func _set_flip_width(value: float) -> void:
	_flip_width = value
	scale = Vector2(_hover_scale * _flip_width, _hover_scale)


## Deal this card face-up with a quick flip (back -> front).
func play_flip(front: Texture2D) -> void:
	front_texture = front
	face_down = false
	_flipping = true
	if back_texture != null:
		texture = back_texture

	var flip := create_tween()
	flip.tween_method(_set_flip_width, 1.0, 0.0, FLIP_TIME * 0.5)
	flip.tween_callback(
		func():
			texture = front
			_update_badge()
	)
	flip.tween_method(_set_flip_width, 0.0, 1.0, FLIP_TIME * 0.5)
	flip.tween_callback(func(): _flipping = false)


## Turn a face-up card back over with the same flip, in reverse. Returns whether
## it turned: a card whose pack has no back image stays face-up, since there is
## nothing to show in place of its face.
func conceal() -> bool:
	if face_down or back_texture == null:
		return false

	face_down = true
	_flipping = true

	var flip := create_tween()
	flip.tween_method(_set_flip_width, 1.0, 0.0, FLIP_TIME * 0.5)
	flip.tween_callback(
		func():
			texture = back_texture
			_update_badge()
	)
	flip.tween_method(_set_flip_width, 0.0, 1.0, FLIP_TIME * 0.5)
	flip.tween_callback(func(): _flipping = false)
	return true


## Moves the mark on one step: unmarked -> met -> missed -> unmarked.
func cycle_result() -> void:
	if is_curse:
		return
	result = ((result + 1) % Result.size()) as Result
	self.result_changed.emit()


## The badge only means something on a challenge you can read. Unmarked, it
## shows only while hovered, so empty circles don't cover the cards' wording.
func _update_badge() -> void:
	if _badge != null:
		_badge.visible = (not is_curse and not face_down and (hovering or result != Result.NONE))


## Start dragging this card programmatically (used when a card is drawn out of a
## pile by dragging — it should immediately follow the cursor).
func begin_drag_from_pile() -> void:
	Motion.settle(self)
	_pressed = true
	_dragging = true
	_press_global_position = get_global_mouse_position()
	_grab_offset = -size * 0.5
	bring_to_front()
	RunManager.begin_card_drag()


func _resize() -> void:
	var screen_size = get_viewport().size as Vector2
	var scale_mult = screen_size.x / 1280.0

	if screen_size.y / 720.0 < scale_mult:
		scale_mult = screen_size.y / 720.0

	var card_size = RunManager.get_card_size()
	custom_minimum_size = Vector2(card_size.x * scale_mult, card_size.y * scale_mult)
	size = custom_minimum_size
	pivot_offset = Vector2(size.x / 2, size.y / 2)

	if _tilt_material != null:
		_tilt_material.set_shader_parameter("card_size", size)

	var badge_side := size.x * BADGE_SHARE
	var inset := size.x * BADGE_INSET
	_badge.size = Vector2(badge_side, badge_side)
	_badge.position = size - _badge.size - Vector2(inset, inset)
