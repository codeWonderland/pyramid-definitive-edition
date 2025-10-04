class_name LoadingAnimation extends Control

const ANIMATION_RATE: float = 1.0
const SMALLEST_SCALE: float = 0.75

var _animation_progress: float = 0.0
var _growing: bool = true

@onready var _circles: Array[TextureRect] = [
	%TextureRect,
	%TextureRect2,
	%TextureRect3,
	%TextureRect4,
	%TextureRect5,
	%TextureRect6,
	%TextureRect7,
	%TextureRect8,
	%TextureRect9,
	%TextureRect10,
	%TextureRect11,
	%TextureRect12,
]


func _physics_process(delta: float) -> void:
	if _growing:
		_animation_progress += ANIMATION_RATE * delta
		if _animation_progress >= 1.0:
			_animation_progress = 1.0
	else:
		_animation_progress -= ANIMATION_RATE * delta
		if _animation_progress <= 0.0:
			_animation_progress = 0.0

	var current_scale: float = 1.0 - (1.0 - SMALLEST_SCALE) * _animation_progress

	for i in range(_circles.size()):
		var pos_degrees: float

		if _growing:
			pos_degrees = i as float / _circles.size() as float * 360.0 * _animation_progress - 90.0
		else:
			var starting_pos = i as float / _circles.size() as float * 360.0
			var offset_from_target = 360.0 - starting_pos
			pos_degrees = starting_pos + offset_from_target * (1 - _animation_progress) - 90.0

		_circles[i].position = (
			_get_position_on_circle(pos_degrees)
			- Vector2(_circles[0].size.x / 2, _circles[0].size.y / 2)
		)

		_circles[i].scale = Vector2(current_scale, current_scale)

	if _growing and _animation_progress == 1.0:
		_growing = false
	elif not _growing and _animation_progress == 0.0:
		_growing = true


func _get_position_on_circle(degrees: float) -> Vector2:
	var current_angle = deg_to_rad(degrees)
	var radius = size.x / 2
	var center_pos = Vector2(radius, radius)
	return Vector2(
		center_pos.x + radius * cos(current_angle), center_pos.y + radius * sin(current_angle)
	)
