extends CanvasLayer

## Fades out to the background colour, changes scene, and fades back in, so moving
## between screens reads as one motion instead of a hard cut. Every scene change
## goes through change_scene_to_packed() here rather than the SceneTree's.
##
## While a change is under way the fade swallows input, so a second click can't
## start another change - or press a button on the screen that's leaving.

const FADE_OUT_TIME: float = 0.15
const FADE_IN_TIME: float = 0.25

var _changing: bool = false

@onready var _fade: ColorRect = %Fade


func _ready() -> void:
	_fade.modulate.a = 0.0
	_fade.hide()


func is_changing() -> bool:
	return _changing


func change_scene_to_packed(scene: PackedScene) -> void:
	if _changing or scene == null:
		return
	_changing = true

	_fade.show()
	var fade_out := create_tween()
	fade_out.tween_property(_fade, "modulate:a", 1.0, FADE_OUT_TIME)
	await fade_out.finished

	get_tree().change_scene_to_packed(scene)
	# The new scene is added on the next frame; let it lay itself out (and start
	# its own entrance motion) before it's uncovered.
	await get_tree().process_frame
	await get_tree().process_frame

	var fade_in := create_tween()
	fade_in.tween_property(_fade, "modulate:a", 0.0, FADE_IN_TIME)
	await fade_in.finished

	_fade.hide()
	_changing = false
