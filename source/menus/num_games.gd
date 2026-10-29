class_name NumGames extends Control

const BLANK_CARD: Texture2D = preload("res://assets/sprites/ui/buttons/blank-card.png")

@onready var _background: TextureRect = %Background
@onready var _back_button: TextureButton = %Back
@onready var _pause_button: TextureButton = %Pause
@onready var _one_button: GameCountChoice = %One
@onready var _three_button: GameCountChoice = %Three
@onready var _five_button: GameCountChoice = %Five
@onready var _pause_menu: PauseMenu = %PauseMenu
@onready var _layout: MarginContainer = %MarginContainer


func _ready() -> void:
	_back_button.pressed.connect(_back_to_pack_select)
	_pause_button.pressed.connect(_pause)
	_one_button.pressed.connect(_select_num_games.bind(1))
	_three_button.pressed.connect(_select_num_games.bind(3))
	_five_button.pressed.connect(_select_num_games.bind(5))

	var backs := _drafted_backs()
	for choice in [_one_button, _three_button, _five_button]:
		choice.set_backs(backs)
	_three_button.grab_focus.call_deferred()

	_set_background()
	UserSettingsManager.background_set.connect(_set_background)
	get_tree().get_root().size_changed.connect(_resize)
	_resize()


## The card backs of the games the player drafted, so each choice shows their own
## games. (A loaded save may not have them; the choices then show plain cards.)
func _drafted_backs() -> Array[Texture2D]:
	var backs: Array[Texture2D] = []
	for pack in RunManager.selected_packs:
		if pack != null and not pack.backs.is_empty():
			backs.append(pack.backs[0])
	if backs.is_empty():
		backs.append(BLANK_CARD)
	return backs


## The screen is laid out for 1920x1080 and scales with the window from there, so
## it fits the 1280x720 default instead of running off its edges. The layout is
## scaled whole - a container resets its children's scale - and sized so that,
## scaled, it still fills the window.
func _resize() -> void:
	var screen_size := get_viewport().get_visible_rect().size
	var scale_mult := minf(screen_size.x / 1920.0, screen_size.y / 1080.0)
	_layout.scale = Vector2(scale_mult, scale_mult)
	_layout.position = Vector2.ZERO
	_layout.size = screen_size / scale_mult


func _set_background() -> void:
	if BackgroundManager.backgrounds.has(UserSettingsManager.background):
		_background.texture = BackgroundManager.backgrounds[UserSettingsManager.background]


func _back_to_pack_select() -> void:
	if _pause_menu.visible:
		return

	# if we loaded from a save and we don't have packs
	# we go to the updater instead of pack select
	if PacksManager.all_packs.size() == 0:
		SceneTransition.change_scene_to_packed(load("res://source/updater/updater.tscn"))
	else:
		SceneTransition.change_scene_to_packed(load("res://source/menus/pack_select.tscn"))


func _pause() -> void:
	if _pause_menu.visible:
		return

	_pause_menu.show()


func _select_num_games(num_games: int) -> void:
	if _pause_menu.visible:
		return

	RunManager.num_games = num_games

	SceneTransition.change_scene_to_packed(load("res://source/game/game.tscn"))
