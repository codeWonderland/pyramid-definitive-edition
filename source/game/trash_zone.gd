class_name TrashZone extends Control

## An "x in a circle" drop target that appears while a card is being dragged.
## Dropping a card over it sends the card to the bottom of its deck (the card
## itself checks RunManager.point_over_trash() on release). Drawn in code so it
## needs no art asset.

const ZONE_SIZE: float = 110.0
const MARGIN_BOTTOM: float = 130.0
const IDLE_COLOR: Color = Color(0.9, 0.35, 0.35, 0.65)
const HOT_COLOR: Color = Color(1.0, 0.4, 0.4, 1.0)

var _hot: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_as_relative = false
	z_index = 1950  # just above cards, below the table UI
	visible = false
	size = Vector2(ZONE_SIZE, ZONE_SIZE)
	pivot_offset = size * 0.5

	RunManager.card_drag_started.connect(_on_drag_started)
	RunManager.card_drag_ended.connect(_on_drag_ended)
	get_tree().get_root().size_changed.connect(_reposition)
	_reposition()


func _process(_delta: float) -> void:
	if not visible:
		return
	# Highlight when the cursor is over the zone so the player knows it's armed.
	var over := RunManager.point_over_trash(get_global_mouse_position())
	if over != _hot:
		_hot = over
		queue_redraw()


func _reposition() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	position = Vector2(viewport_size.x * 0.5 - ZONE_SIZE * 0.5, viewport_size.y - MARGIN_BOTTOM)
	RunManager.set_trash_zone_rect(Rect2(global_position, size))


func _on_drag_started() -> void:
	_reposition()
	_hot = false
	visible = true
	queue_redraw()


func _on_drag_ended() -> void:
	visible = false


func _draw() -> void:
	var center := size * 0.5
	var radius := size.x * 0.42
	var color := HOT_COLOR if _hot else IDLE_COLOR
	var width := 6.0 if _hot else 4.0

	draw_arc(center, radius, 0.0, TAU, 48, color, width, true)
	var d := radius * 0.45
	draw_line(center - Vector2(d, d), center + Vector2(d, d), color, width, true)
	draw_line(center - Vector2(d, -d), center + Vector2(d, -d), color, width, true)
