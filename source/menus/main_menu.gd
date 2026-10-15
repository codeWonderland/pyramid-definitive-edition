class_name MainMenu extends Control

# Idle logo animation (after the intro): a gentle pulse and slow back-and-forth sway.
const LOGO_SWAY_DEGREES: float = 5.0
const LOGO_SWAY_TIME: float = 2.5
const LOGO_PULSE_SCALE: float = 1.06
const LOGO_PULSE_TIME: float = 1.6

@onready var _background: TextureRect = %Background
@onready var _title: Label = %Title
@onready var _pause_menu: PauseMenu = %PauseMenu
@onready var _load_game_dialog: LoadGameDialog = %LoadGameDialog
@onready var _menu: VBoxContainer = %Menu
@onready var _start_button: Button = %StartRun
@onready var _load_game_button: Button = %LoadRun
@onready var _library_button: Button = %Library
@onready var _settings_button: Button = %Settings
@onready var _exit_button: Button = %Exit
@onready var _credits_button: TextureButton = %Credits
@onready var _github_button: TextureButton = %Github


func _ready() -> void:
	RunManager.clear()
	_setup_ui()
	_start_button.pressed.connect(_start_run)
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


func _setup_ui() -> void:
	var og_title_pos = _title.position
	_title.scale = Vector2.ZERO
	_title.position = Vector2.ZERO

	var title_tween = create_tween()
	title_tween.tween_property(_title, "scale", Vector2.ONE, 0.7)
	var title_pos_tween = create_tween()
	title_pos_tween.tween_property(_title, "position", og_title_pos, 0.7)
	title_tween.finished.connect(_show_menu)

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


## The menu rises in once the logo has landed, with Start a run focused so the
## keyboard (arrows, Enter) works from the start.
func _show_menu() -> void:
	_menu.show()
	Motion.rise_in(_menu.get_children().filter(func(child: Node) -> bool: return child is Button))
	_start_button.grab_focus()


func _toggle_settings() -> void:
	if _pause_menu.visible or _load_game_dialog.visible:
		return

	_pause_menu.show()


func _load_game() -> void:
	if _pause_menu.visible or _load_game_dialog.visible:
		return

	_load_game_dialog.show()


func _start_run() -> void:
	if _pause_menu.visible or _load_game_dialog.visible:
		return

	SceneTransition.change_scene_to_packed(load("res://source/updater/updater.tscn"))


func _close_game() -> void:
	if _pause_menu.visible or _load_game_dialog.visible:
		return

	get_tree().quit()


func _open_github() -> void:
	OS.shell_open("https://www.github.com/codeWonderland/pyramid-definitive-edition")


func _show_library() -> void:
	if _pause_menu.visible or _load_game_dialog.visible:
		return

	SceneTransition.change_scene_to_packed(load("res://source/menus/library.tscn"))


func _show_credits() -> void:
	SceneTransition.change_scene_to_packed(load("res://source/menus/credits.tscn"))
