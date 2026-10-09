class_name Motion

## The shared entrance motion, so screens arrive the same way: things appear one
## after another, quickly, rather than all at once.

const TIME: float = 0.22
const STAGGER: float = 0.035
## How far a dropped control falls into place, in pixels.
const DROP_HEIGHT: float = 28.0
## How small a risen control starts.
const RISE_SCALE: Vector2 = Vector2(0.92, 0.92)
## Metadata holding a control's running entrance, so settle() can end it.
const ENTRANCE_META: StringName = &"motion_entrance"


## Fades and grows controls in, one after another. For controls a container lays
## out, which can't be moved but can be scaled about their centre.
static func rise_in(controls: Array, start_delay: float = 0.0) -> void:
	for i in controls.size():
		var control: Control = controls[i]
		control.modulate.a = 0.0
		control.pivot_offset = _size_of(control) / 2
		control.scale = RISE_SCALE

		var delay := start_delay + i * STAGGER
		var tween := control.create_tween().set_parallel()
		tween.tween_property(control, "modulate:a", 1.0, TIME).set_delay(delay)
		(
			tween
			. tween_property(control, "scale", Vector2.ONE, TIME)
			. set_delay(delay)
			. set_trans(Tween.TRANS_BACK)
			. set_ease(Tween.EASE_OUT)
		)


## Fades freely placed controls in as they drop onto where they already are, one
## after another. Leaves scale alone, for controls that use it for something else.
static func drop_in(controls: Array, start_delay: float = 0.0) -> void:
	for i in controls.size():
		var control: Control = controls[i]
		var resting := control.position
		control.modulate.a = 0.0
		control.position = resting - Vector2(0, DROP_HEIGHT)

		var delay := start_delay + i * STAGGER
		var tween := control.create_tween().set_parallel()
		control.set_meta(ENTRANCE_META, tween)
		tween.tween_property(control, "modulate:a", 1.0, TIME).set_delay(delay)
		(
			tween
			. tween_property(control, "position", resting, TIME)
			. set_delay(delay)
			. set_trans(Tween.TRANS_QUAD)
			. set_ease(Tween.EASE_OUT)
		)


## Ends a control's entrance at once, where it is: a card grabbed while it's still
## dropping onto the table belongs to the player, not the animation.
static func settle(control: Control) -> void:
	if not control.has_meta(ENTRANCE_META):
		return
	var tween = control.get_meta(ENTRANCE_META)
	control.remove_meta(ENTRANCE_META)
	if tween is Tween and tween.is_valid():
		tween.kill()
	control.modulate.a = 1.0


## A control's size before its first layout, when size is still zero.
static func _size_of(control: Control) -> Vector2:
	return control.size if control.size != Vector2.ZERO else control.custom_minimum_size
