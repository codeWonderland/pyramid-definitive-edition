class_name FavoriteHeart extends Control

## A small heart drawn in code (no art asset) shown in a card's corner when the
## pack is favorited.

const FILL_COLOR: Color = Color(0.93, 0.26, 0.32)
const OUTLINE_COLOR: Color = Color(1.0, 1.0, 1.0, 0.9)
const SEGMENTS: int = 28


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return

	var points := PackedVector2Array()
	for i in range(SEGMENTS + 1):
		var t := TAU * float(i) / float(SEGMENTS)
		# Classic parametric heart, normalized into this control's rect.
		var hx := pow(sin(t), 3.0)
		var hy := (13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t)) / 16.0
		var px := size.x * 0.5 + hx * size.x * 0.46
		var py := size.y * 0.46 - hy * size.y * 0.46
		points.append(Vector2(px, py))

	draw_colored_polygon(points, FILL_COLOR)
	draw_polyline(points, OUTLINE_COLOR, 1.5, true)
