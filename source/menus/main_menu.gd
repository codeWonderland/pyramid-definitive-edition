class_name MainMenu extends Control

# Idle logo animation (after the intro): a gentle pulse and slow back-and-forth sway.
const LOGO_SWAY_DEGREES: float = 5.0
const LOGO_SWAY_TIME: float = 2.5
const LOGO_PULSE_SCALE: float = 1.06
const LOGO_PULSE_TIME: float = 1.6

@onready var _background: TextureRect = %Background
@onready var _title: Label = %Title
@onready var _start_label: Label = %StartLabel
@onready var _pause_menu: PauseMenu = %PauseMenu
@onready var _load_game_button: TextureButton = %Load
@onready var _load_game_dialog: LoadGameDialog = %LoadGameDialog
@onready var _settings_button: TextureButton = %Settings
@onready var _exit_button: TextureButton = %Exit
@onready var _credits_button: TextureButton = %Credits
@onready var _library_button: TextureButton = %Library
@onready var _github_button: TextureButton = %Github


func _ready() -> void:
	RunManager.clear()
	_setup_ui()
	_settings_button.pressed.connect(_toggle_settings)
	_load_game_button.pressed.connect(_load_game)
	_exit_button.pressed.connect(_close_game)
	_credits_button.pressed.connect(_show_credits)
	_library_button.pressed.connect(_show_library)
	_github_button.pressed.connect(_open_github)

	_set_background()
	UserSettingsManager.background_set.connect(_set_background)


func _set_background() -> void:
	if BackgroundManager.backgrounds.has(UserSettingsManager.background):
		_background.texture = BackgroundManager.backgrounds[UserSettingsManager.background]


## "Press anything to start": a click anywhere that isn't one of the menu's own
## buttons starts a run. Decided at the moment of the press. Buttons act on
## release, so waiting to see whether a button claimed the click raced the
## player's hold - a click held a moment too long on Library or Credits started a
## run instead.
func _input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		return

	if _pause_menu.visible or _load_game_dialog.visible:
		return

	if is_over_menu_button(event.position):
		return

	_transition_scene()


## Whether a screen position lands on one of the menu's buttons.
func is_over_menu_button(position: Vector2) -> bool:
	for button in [
		_load_game_button,
		_settings_button,
		_exit_button,
		_credits_button,
		_library_button,
		_github_button,
	]:
		if button.is_visible_in_tree() and button.get_global_rect().has_point(position):
			return true
	return false


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
	title_rot_tween.tween_property(_title, "rotation_degrees", -LOGO_SWAY_DEGREES, 0.7)

	title_tween.finished.connect(_start_logo_idle)


## Looping idle animation: the logo pulses and sways gently after it settles in.
func _start_logo_idle() -> void:
	var sway := create_tween().set_loops()
	(
		sway
		. tween_property(_title, "rotation_degrees", LOGO_SWAY_DEGREES, LOGO_SWAY_TIME)
		. set_trans(Tween.TRANS_SINE)
		. set_ease(Tween.EASE_IN_OUT)
	)
	(
		sway
		. tween_property(_title, "rotation_degrees", -LOGO_SWAY_DEGREES, LOGO_SWAY_TIME)
		. set_trans(Tween.TRANS_SINE)
		. set_ease(Tween.EASE_IN_OUT)
	)

	var pulse := create_tween().set_loops()
	(
		pulse
		. tween_property(_title, "scale", Vector2.ONE * LOGO_PULSE_SCALE, LOGO_PULSE_TIME)
		. set_trans(Tween.TRANS_SINE)
		. set_ease(Tween.EASE_IN_OUT)
	)
	(
		pulse
		. tween_property(_title, "scale", Vector2.ONE, LOGO_PULSE_TIME)
		. set_trans(Tween.TRANS_SINE)
		. set_ease(Tween.EASE_IN_OUT)
	)


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
	if _pause_menu.visible or _load_game_dialog.visible:
		return

	_pause_menu.show()


func _load_game() -> void:
	if _pause_menu.visible or _load_game_dialog.visible:
		return

	_load_game_dialog.show()


func _transition_scene() -> void:
	get_tree().change_scene_to_packed(load("res://source/updater/updater.tscn"))


func _close_game() -> void:
	if _pause_menu.visible or _load_game_dialog.visible:
		return

	get_tree().quit()


func _open_github() -> void:
	OS.shell_open("https://www.github.com/codeWonderland/pyramid-definitive-edition")


func _show_library() -> void:
	if _pause_menu.visible or _load_game_dialog.visible:
		return

	get_tree().change_scene_to_packed(load("res://source/menus/library.tscn"))


func _show_credits() -> void:
	get_tree().change_scene_to_packed(load("res://source/menus/credits.tscn"))
