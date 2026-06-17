class_name CaretButton extends BaseButton

## A pagination arrow drawn in code: a grey rounded background with a white
## outline and a white chevron (caret) pointing left or right.

const BG_COLOR: Color = Color(0.27, 0.27, 0.30, 0.85)
const BG_HOVER_COLOR: Color = Color(0.40, 0.40, 0.44, 0.95)
const OUTLINE_COLOR: Color = Color(1.0, 1.0, 1.0, 0.95)
const CARET_COLOR: Color = Color(1.0, 1.0, 1.0)

@export var points_left: bool = false

var _stylebox: StyleBoxFlat = null


func _ready() -> void:
	_stylebox = StyleBoxFlat.new()
	_stylebox.set_corner_radius_all(8)
	_stylebox.set_border_width_all(2)
	_stylebox.border_color = OUTLINE_COLOR

	# Redraw on state changes so the hover tint updates.
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	button_down.connect(queue_redraw)
	button_up.connect(queue_redraw)


func _draw() -> void:
	if _stylebox == null or size.x <= 0.0 or size.y <= 0.0:
		return

	_stylebox.bg_color = BG_HOVER_COLOR if is_hovered() else BG_COLOR
	draw_style_box(_stylebox, Rect2(Vector2.ZERO, size))

	var width := maxf(2.0, size.x * 0.08)
	var caret := PackedVector2Array()
	if points_left:
		caret.append(Vector2(size.x * 0.62, size.y * 0.28))
		caret.append(Vector2(size.x * 0.40, size.y * 0.50))
		caret.append(Vector2(size.x * 0.62, size.y * 0.72))
	else:
		caret.append(Vector2(size.x * 0.38, size.y * 0.28))
		caret.append(Vector2(size.x * 0.60, size.y * 0.50))
		caret.append(Vector2(size.x * 0.38, size.y * 0.72))

	draw_polyline(caret, CARET_COLOR, width, true)
