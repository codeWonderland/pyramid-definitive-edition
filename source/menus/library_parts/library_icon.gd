@tool
class_name LibraryIcon extends Control

## Small line icons for the library's detail panel, drawn rather than imported so
## they stay crisp at any size and pick up the theme's text colour. Stand-ins
## until there's final icon art: swap a node's script for a TextureRect then.

enum Kind { CLOCK, CONTROLLER, VERSUS, COOP, OPEN, CHEVRON }

const LINE: float = 3.0

@export var kind: Kind = Kind.CLOCK:
	set(value):
		kind = value
		queue_redraw()
@export var color: Color = Color.WHITE:
	set(value):
		color = value
		queue_redraw()


func _draw() -> void:
	var s := minf(size.x, size.y)
	var c := size / 2
	match kind:
		Kind.CLOCK:
			draw_arc(c, s * 0.42, 0, TAU, 32, color, LINE, true)
			draw_line(c, c + Vector2(0, -s * 0.28), color, LINE, true)
			draw_line(c, c + Vector2(s * 0.2, 0), color, LINE, true)
		Kind.CONTROLLER:
			var body := Rect2(c - Vector2(s * 0.45, s * 0.22), Vector2(s * 0.9, s * 0.44))
			draw_rect(body, color, false, LINE)
			draw_line(c + Vector2(-s * 0.3, 0), c + Vector2(-s * 0.12, 0), color, LINE)
			draw_line(
				c + Vector2(-s * 0.21, -s * 0.09), c + Vector2(-s * 0.21, s * 0.09), color, LINE
			)
			draw_circle(c + Vector2(s * 0.18, -s * 0.05), s * 0.05, color)
			draw_circle(c + Vector2(s * 0.29, s * 0.06), s * 0.05, color)
		Kind.VERSUS:
			var r := s * 0.4
			draw_line(c + Vector2(-r, -r), c + Vector2(r, r), color, LINE + 1, true)
			draw_line(c + Vector2(r, -r), c + Vector2(-r, r), color, LINE + 1, true)
			draw_line(
				c + Vector2(-r * 0.75, r * 0.35), c + Vector2(-r * 0.35, r * 0.75), color, LINE
			)
			draw_line(c + Vector2(r * 0.75, r * 0.35), c + Vector2(r * 0.35, r * 0.75), color, LINE)
		Kind.COOP:
			for dx in [-s * 0.2, s * 0.2]:
				draw_circle(c + Vector2(dx, -s * 0.16), s * 0.12, color)
				draw_arc(c + Vector2(dx, s * 0.32), s * 0.2, PI, TAU, 16, color, LINE, true)
		Kind.CHEVRON:
			# Points right; turn it to point down for "open".
			var r := s * 0.28
			draw_polyline(
				PackedVector2Array(
					[c + Vector2(-r * 0.5, -r), c + Vector2(r * 0.5, 0), c + Vector2(-r * 0.5, r)]
				),
				color,
				LINE + 1,
				true
			)
		Kind.OPEN:
			var box := Rect2(c - Vector2(s * 0.4, s * 0.3), Vector2(s * 0.7, s * 0.7))
			draw_polyline(
				PackedVector2Array(
					[
						Vector2(box.position.x + s * 0.35, box.position.y),
						box.position,
						box.end - Vector2(box.size.x, 0),
						box.end,
						Vector2(box.end.x, box.position.y + s * 0.35),
					]
				),
				color,
				LINE
			)
			var tip := c + Vector2(s * 0.42, -s * 0.42)
			draw_line(c, tip, color, LINE, true)
			draw_line(tip, tip + Vector2(-s * 0.22, 0), color, LINE)
			draw_line(tip, tip + Vector2(0, s * 0.22), color, LINE)
