class_name MainMenu extends Control

var _settings_were_open: bool = false

@onready var _background: TextureRect = %Background
@onready var _title: Label = %Title
@onready var _start_label: Label = %StartLabel
@onready var _pause_menu: PauseMenu = %PauseMenu
@onready var _settings_button: TextureButton = %Settings
@onready var _exit_button: TextureButton = %Exit


func _ready() -> void:
	_setup_ui()
	_settings_button.pressed.connect(_toggle_settings)
	_exit_button.pressed.connect(_close_game)

	_set_background()
	UserSettingsManager.background_set.connect(_set_background)


func _set_background() -> void:
	if BackgroundManager.backgrounds.has(UserSettingsManager.background):
		_background.texture = BackgroundManager.backgrounds[UserSettingsManager.background]


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed == true:
		await get_tree().create_timer(0.2).timeout
		if _pause_menu.visible:
			return

		if _settings_were_open:
			_settings_were_open = false
			return

		_transition_scene()


func _setup_ui() -> void:
	var og_title_pos = _title.position
	_title.scale = Vector2.ZERO
	_title.position = Vector2.ZERO

	var title_tween = create_tween()
	title_tween.tween_property(_title, "scale", Vector2.ONE, 0.7)
	var title_pos_tween = create_tween()
	title_pos_tween.tween_property(_title, "position", og_title_pos, 0.7)
	title_tween.finished.connect(_show_label)

	var title_rot_tween = create_tween()
	title_rot_tween.tween_property(_title, "rotation_degrees", -5, 0.7)


func _show_label() -> void:
	var label_tween = create_tween()
	label_tween.tween_property(_start_label, "modulate:a", 1.0, 1.0)
	label_tween.finished.connect(_hide_label)


func _hide_label() -> void:
	await get_tree().create_timer(0.3).timeout
	var label_tween = create_tween()
	label_tween.tween_property(_start_label, "modulate:a", 0.0, 1.0)
	label_tween.finished.connect(_show_label)


func _toggle_settings() -> void:
	if _pause_menu.visible:
		return

	_pause_menu.show()
	_settings_were_open = true


func _transition_scene() -> void:
	get_tree().change_scene_to_packed(load("res://source/updater/updater.tscn"))


func _close_game() -> void:
	get_tree().quit()
