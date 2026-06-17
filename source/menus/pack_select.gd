class_name PackSelect extends Control

const NAV_BUTTON_SIZE: Vector2 = Vector2(56, 88)
const EDGE_MARGIN: int = 24

var _sort_ascending: bool = true
var _favorites_only: bool = false
var _sort_button: Button = null
var _filter_button: Button = null
var _prev_button: CaretButton = null
var _next_button: CaretButton = null

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
	_done.pressed.connect(_selection_complete)
	_pack_select_packs.pack_added.connect(RunManager.add_pack)
	_pack_select_selected_packs.pack_pressed.connect(RunManager.remove_pack)

	_build_navigation()
	_build_filters()
	_make_selection_scrollable()

	_set_background()
	UserSettingsManager.background_set.connect(_set_background)


func _build_navigation() -> void:
	# Replace the word-image prev/next buttons with caret buttons floated to the
	# left/right edges, vertically centered and kept beneath the pause menu.
	_previous.queue_free()
	_next.queue_free()

	_prev_button = _make_caret(true, _prev_page)
	_prev_button.set_anchors_and_offsets_preset(
		Control.PRESET_CENTER_LEFT, Control.PRESET_MODE_MINSIZE, EDGE_MARGIN
	)

	_next_button = _make_caret(false, _next_page)
	_next_button.set_anchors_and_offsets_preset(
		Control.PRESET_CENTER_RIGHT, Control.PRESET_MODE_MINSIZE, EDGE_MARGIN
	)


func _make_caret(points_left: bool, on_pressed: Callable) -> CaretButton:
	var caret := CaretButton.new()
	caret.points_left = points_left
	caret.custom_minimum_size = NAV_BUTTON_SIZE
	caret.pressed.connect(on_pressed)
	add_child(caret)
	move_child(caret, _pause_menu.get_index())
	return caret


func _build_filters() -> void:
	# Sort (A-Z / Z-A) and filter (All / Favorites) live in the bottom corners,
	# where the prev/next buttons used to be.
	var bottom := _done.get_parent()

	_sort_button = Button.new()
	_sort_button.pressed.connect(_toggle_sort)
	bottom.add_child(_sort_button)
	_sort_button.set_anchors_and_offsets_preset(
		Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, EDGE_MARGIN
	)

	_filter_button = Button.new()
	_filter_button.pressed.connect(_toggle_filter)
	bottom.add_child(_filter_button)
	_filter_button.set_anchors_and_offsets_preset(
		Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, EDGE_MARGIN
	)

	_update_filter_labels()


func _update_filter_labels() -> void:
	_sort_button.text = "Sort: A-Z" if _sort_ascending else "Sort: Z-A"
	_filter_button.text = "Filter: All" if not _favorites_only else "Filter: Favorites"


func _toggle_sort() -> void:
	if _pause_menu.visible:
		return
	_sort_ascending = not _sort_ascending
	_update_filter_labels()
	_pack_select_packs.set_sort_ascending(_sort_ascending)


func _toggle_filter() -> void:
	if _pause_menu.visible:
		return
	_favorites_only = not _favorites_only
	_update_filter_labels()
	_pack_select_packs.set_favorites_only(_favorites_only)


func _make_selection_scrollable() -> void:
	# Wrap the selected-packs strip in a horizontal scroll view so any number of
	# drafted packs fits.
	var strip := _pack_select_selected_packs
	var container := strip.get_parent()
	var strip_index := strip.get_index()

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size.y = strip.custom_minimum_size.y + 12.0

	container.remove_child(strip)
	container.add_child(scroll)
	container.move_child(scroll, strip_index)
	scroll.add_child(strip)


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
