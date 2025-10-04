class_name Credits extends Control

const SCROLL_SPEED = 50.0

var skip_credits_label_visible: bool = false

@onready var _skip_label: Label = %SkipCreditsLabel
@onready var _scrolling_container: VBoxContainer = %ScrollingContainer


func _ready() -> void:
	_skip_label.modulate.a = 0.0
	_scrolling_container.position.y = get_viewport().size.y


func _physics_process(delta: float) -> void:
	_scrolling_container.position.y -= SCROLL_SPEED * delta

	if Input.is_anything_pressed():
		if skip_credits_label_visible and Input.is_action_just_pressed("Escape"):
			_end_credits()

		elif not skip_credits_label_visible:
			var alpha_tween = create_tween()
			alpha_tween.tween_property(_skip_label, "modulate:a", 1.0, 1.0)
			alpha_tween.play()
			skip_credits_label_visible = true

	if _scrolling_container.position.y * -1 >= _scrolling_container.size.y:
		_end_credits()


func _end_credits() -> void:
	var alpha_tween = create_tween()
	alpha_tween.tween_property(_scrolling_container, "modulate:a", 0.0, 1.0)
	alpha_tween.finished.connect(_on_credits_finished)
	alpha_tween.play()


func _on_credits_finished():
	get_tree().change_scene_to_packed(load("res://source/menus/main_menu.tscn"))
