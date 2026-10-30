class_name ResultBadge extends Control

## The corner badge on a table card that records how its challenge went. Clicking
## it cycles unmarked -> met -> missed -> unmarked, so a wrong mark is undone by
## clicking it round. Drawn rather than imported so it stays crisp at any size.

signal clicked

const MET_COLOR: Color = Color("2fbf71")
const MISSED_COLOR: Color = Color("e5484d")
const UNMARKED_COLOR: Color = Color(0.1, 0.1, 0.12, 0.55)
const RING_COLOR: Color = Color.WHITE

var result: ChallengeCard.Result = ChallengeCard.Result.NONE:
	set(value):
		result = value
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tooltip_text = "Mark this challenge met or missed"


func _gui_input(event: InputEvent) -> void:
	if (
		event is InputEventMouseButton
		and event.button_index == MOUSE_BUTTON_LEFT
		and event.pressed
		and not RunManager.popup_open
	):
		accept_event()
		self.clicked.emit()


func _draw() -> void:
	var s := minf(size.x, size.y)
	var c := size / 2
	var r := s * 0.5
	var line := maxf(s * 0.12, 1.5)

	match result:
		ChallengeCard.Result.MET:
			draw_circle(c, r, MET_COLOR)
			draw_polyline(
				PackedVector2Array(
					[
						c + Vector2(-r * 0.45, 0),
						c + Vector2(-r * 0.1, r * 0.35),
						c + Vector2(r * 0.5, -r * 0.35),
					]
				),
				Color.WHITE,
				line,
				true
			)
		ChallengeCard.Result.MISSED:
			draw_circle(c, r, MISSED_COLOR)
			var d := r * 0.38
			draw_line(c + Vector2(-d, -d), c + Vector2(d, d), Color.WHITE, line, true)
			draw_line(c + Vector2(d, -d), c + Vector2(-d, d), Color.WHITE, line, true)
		_:
			draw_circle(c, r, UNMARKED_COLOR)
	draw_arc(c, r - line * 0.25, 0, TAU, 32, RING_COLOR, line * 0.5, true)
