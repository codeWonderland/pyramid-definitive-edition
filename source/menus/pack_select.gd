class_name PackSelect extends Control

var _sort_ascending: bool = true
var _favorites_only: bool = false
var _sort_button: Button = null
var _filter_button: Button = null

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
	_pack_select_selected_packs.pack_pressed.connect(RunManager.remove_pack)

	_build_toolbar()

	_set_background()
	UserSettingsManager.background_set.connect(_set_background)


func _build_toolbar() -> void:
	# Sort (A-Z / Z-A) and filter (All / Favorites) controls above the grid.
	# Built in code to avoid scene edits; each button toggles its two states.
	var toolbar := HBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 16)

	_sort_button = Button.new()
	_sort_button.pressed.connect(_toggle_sort)
	toolbar.add_child(_sort_button)

	_filter_button = Button.new()
	_filter_button.pressed.connect(_toggle_filter)
	toolbar.add_child(_filter_button)

	var packs_container := _pack_select_packs.get_parent()
	packs_container.add_child(toolbar)
	packs_container.move_child(toolbar, 0)

	_update_toolbar_labels()


func _update_toolbar_labels() -> void:
	_sort_button.text = "Sort: A-Z" if _sort_ascending else "Sort: Z-A"
	_filter_button.text = "Filter: All" if not _favorites_only else "Filter: Favorites"


func _toggle_sort() -> void:
	if _pause_menu.visible:
		return
	_sort_ascending = not _sort_ascending
	_update_toolbar_labels()
	_pack_select_packs.set_sort_ascending(_sort_ascending)


func _toggle_filter() -> void:
	if _pause_menu.visible:
		return
	_favorites_only = not _favorites_only
	_update_toolbar_labels()
	_pack_select_packs.set_favorites_only(_favorites_only)


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
