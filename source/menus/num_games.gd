class_name NumGames extends Control

@onready var _background: TextureRect = %Background
@onready var _back_button: TextureButton = %Back
@onready var _pause_button: TextureButton = %Pause
@onready var _one_button: TextureButton = %One
@onready var _three_button: TextureButton = %Three
@onready var _five_button: TextureButton = %Five
@onready var _pause_menu: PauseMenu = %PauseMenu


func _ready() -> void:
	_back_button.pressed.connect(_back_to_pack_select)
	_pause_button.pressed.connect(_pause)
	_one_button.pressed.connect(_select_num_games.bind(1))
	_three_button.pressed.connect(_select_num_games.bind(3))
	_five_button.pressed.connect(_select_num_games.bind(5))

	_set_background()
	UserSettingsManager.background_set.connect(_set_background)


func _set_background() -> void:
	if BackgroundManager.backgrounds.has(UserSettingsManager.background):
		_background.texture = BackgroundManager.backgrounds[UserSettingsManager.background]


func _back_to_pack_select() -> void:
	if _pause_menu.visible:
		return

	get_tree().change_scene_to_packed(load("res://source/menus/pack_select.tscn"))


func _pause() -> void:
	if _pause_menu.visible:
		return

	_pause_menu.show()


func _select_num_games(num_games: int) -> void:
	if _pause_menu.visible:
		return

	RunManager.num_games = num_games

	get_tree().change_scene_to_packed(load("res://source/game/game.tscn"))
