class_name PackSelect extends Control

@onready var _background: TextureRect = %Background
@onready var _back_button: TextureButton = %Back
@onready var _pause_menu: PauseMenu = %PauseMenu
@onready var _pause_button: TextureButton = %Pause
@onready var _pack_select_packs: PackSelectPacks = %PackSelectPacks
@onready var _pack_select_selected_packs: PackSelectSelectedPacks = %PackSelectSelectedPacks
@onready var _previous: TextureButton = %Previous
@onready var _next: TextureButton = %Next
@onready var _done: TextureButton = %Done


func _ready() -> void:
	_back_button.pressed.connect(_back)
	_pause_button.pressed.connect(_pause)
	_next.pressed.connect(_next_page)
	_previous.pressed.connect(_prev_page)
	_done.pressed.connect(_selection_complete)
	_pack_select_packs.pack_added.connect(RunManager.add_pack)
	_pack_select_packs.pack_removed.connect(RunManager.remove_pack)
	_pack_select_selected_packs.pack_pressed.connect(RunManager.remove_pack)

	_set_background()
	UserSettingsManager.background_set.connect(_set_background)


func _set_background() -> void:
	if BackgroundManager.backgrounds.has(UserSettingsManager.background):
		_background.texture = BackgroundManager.backgrounds[UserSettingsManager.background]


func _back() -> void:
	if _pause_menu.visible:
		return

	get_tree().change_scene_to_packed(load("res://source/menus/main_menu.tscn"))


func _pause() -> void:
	if _pause_menu.visible:
		return

	_pause_menu.show()


func _next_page() -> void:
	if _pause_menu.visible:
		return

	_pack_select_packs.next_page()


func _prev_page() -> void:
	if _pause_menu.visible:
		return

	_pack_select_packs.prev_page()


func _selection_complete() -> void:
	if RunManager.selected_packs.size() == 0:
		return

	get_tree().change_scene_to_packed(load("res://source/menus/num_games.tscn"))
