class_name PackSelect extends Control

var _sort_ascending: bool = true
var _favorites_only: bool = false

@onready var _background: TextureRect = %Background
@onready var _back_button: TextureButton = %Back
@onready var _pause_menu: PauseMenu = %PauseMenu
@onready var _pause_button: TextureButton = %Pause
@onready var _pack_select_packs: PackSelectPacks = %PackSelectPacks
@onready var _pack_select_selected_packs: PackSelectSelectedPacks = %PackSelectSelectedPacks
@onready var _previous: Button = %Previous
@onready var _next: Button = %Next
@onready var _done: Button = %Done
@onready var _sort_button: Button = %SortButton
@onready var _filter_button: Button = %FilterButton
@onready var _search_bar: LineEdit = %SearchBar
@onready var _tag_filter_button: Button = %TagFilterButton
@onready var _filter_panel: PackFilterPanel = %PackFilterPanel


func _ready() -> void:
	_back_button.pressed.connect(_back)
	_pause_button.pressed.connect(_pause)
	_next.pressed.connect(_next_page)
	_previous.pressed.connect(_prev_page)
	_done.pressed.connect(_selection_complete)
	_sort_button.pressed.connect(_toggle_sort)
	_filter_button.pressed.connect(_toggle_filter)
	_search_bar.text_changed.connect(_on_search_changed)
	_tag_filter_button.pressed.connect(_toggle_filter_panel)
	_filter_panel.filters_changed.connect(_on_tag_filters_changed)
	PacksManager.packs_loaded.connect(_filter_panel.rebuild)
	_pack_select_packs.pack_added.connect(RunManager.add_pack)
	_pack_select_selected_packs.pack_pressed.connect(RunManager.remove_pack)

	_update_filter_labels()
	_set_background()
	UserSettingsManager.background_set.connect(_set_background)


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


func _on_search_changed(query: String) -> void:
	_pack_select_packs.set_search_query(query)


func _toggle_filter_panel() -> void:
	if _pause_menu.visible:
		return

	_filter_panel.toggle()


func _on_tag_filters_changed(tags: Array[String], match_all: bool) -> void:
	_pack_select_packs.set_tag_filters(tags, match_all)


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
