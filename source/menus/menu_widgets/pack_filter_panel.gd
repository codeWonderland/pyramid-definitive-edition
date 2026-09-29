class_name PackFilterPanel extends Control

## Tag filter drawer for the draft screen. Slides in from the right edge with a
## checkbox per tag declared by the loaded packs, an any/all mode toggle, and a
## search box for when the tag list grows long.

signal filters_changed(tags: Array[String], match_all: bool)

## Panel width at the 1920x1080 reference size; scaled to fit smaller screens.
const REFERENCE_WIDTH: float = 420.0
const SLIDE_TIME: float = 0.25

var _match_all: bool = false
var _tag_search: String = ""
# Ticked tags, keyed by their lowercased form so the set survives packs that
# spell the same tag differently.
var _selected: Dictionary = {}
var _checkboxes: Array[CheckBox] = []
var _slide_tween: Tween = null

@onready var _backing: PanelContainer = %Backing
@onready var _close_button: TextureButton = %Close
@onready var _mode_button: Button = %ModeButton
@onready var _search: LineEdit = %TagSearch
@onready var _tag_list: VBoxContainer = %TagList
@onready var _clear_button: Button = %ClearButton
@onready var _empty_label: Label = %EmptyLabel


func _ready() -> void:
	_resize()
	get_tree().get_root().size_changed.connect(_resize)

	_mode_button.pressed.connect(_toggle_mode)
	_search.text_changed.connect(_on_tag_search_changed)
	_clear_button.pressed.connect(clear_filters)
	_close_button.pressed.connect(close)

	_update_mode_label()
	rebuild()
	_snap_closed()


## True while the drawer is showing.
func is_open() -> bool:
	return offset_left < 0.0


func toggle() -> void:
	if is_open():
		close()
	else:
		open()


func open() -> void:
	show()
	_slide_to(-_panel_width())


func close() -> void:
	_slide_to(0.0)


## While open, Escape or a click anywhere outside the drawer puts it away. The
## outside click is consumed, so dismissing the drawer never also picks a pack.
func _input(event: InputEvent) -> void:
	if not is_open():
		return

	if event.is_action_pressed("Escape"):
		close()
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseButton and event.pressed:
		if not get_global_rect().has_point(event.position):
			close()
			get_viewport().set_input_as_handled()


func clear_filters() -> void:
	_selected.clear()
	for box in _checkboxes:
		box.set_pressed_no_signal(false)
	_emit_change()


## Rebuilds the checkbox list from the loaded packs. Safe to call again after
## packs reload; ticked tags that still exist stay ticked.
func rebuild() -> void:
	for child in _tag_list.get_children():
		child.queue_free()
	_checkboxes = []

	var tags := PacksManager.all_tags()
	_empty_label.visible = tags.is_empty()

	for tag in tags:
		var box := CheckBox.new()
		box.text = tag
		box.tooltip_text = PacksManager.category_description(tag)
		box.set_pressed_no_signal(_selected.has(tag.to_lower()))
		box.toggled.connect(_on_tag_toggled.bind(tag))
		_tag_list.add_child(box)
		_checkboxes.append(box)

	_apply_tag_search()


func selected_tags() -> Array[String]:
	var tags: Array[String] = []
	for box in _checkboxes:
		if box.button_pressed:
			tags.append(box.text)
	return tags


## The reference width scaled to the window, but never narrower than the
## drawer's contents need: a drawer squeezed below that grows past its own edge,
## which pokes into the screen while it is meant to be closed.
func _panel_width() -> float:
	var viewport_width := get_viewport().get_visible_rect().size.x
	var wanted := maxf(
		REFERENCE_WIDTH * (viewport_width / 1920.0), _backing.get_combined_minimum_size().x
	)
	return minf(wanted, viewport_width)


## Re-anchors the drawer for the new viewport width, keeping it on whichever
## side it was already on. Any in-flight slide is dropped: its targets were
## computed against the old width.
func _resize() -> void:
	var width := _panel_width()
	var was_open := is_open()

	if _slide_tween != null and _slide_tween.is_valid():
		_slide_tween.kill()

	offset_left = -width if was_open else 0.0
	offset_right = 0.0 if was_open else width


func _snap_closed() -> void:
	var width := _panel_width()
	offset_left = 0.0
	offset_right = width
	hide()


func _slide_to(target_left: float) -> void:
	var width := _panel_width()

	if _slide_tween != null and _slide_tween.is_valid():
		_slide_tween.kill()

	_slide_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_slide_tween.parallel().tween_property(self, "offset_left", target_left, SLIDE_TIME)
	_slide_tween.parallel().tween_property(self, "offset_right", target_left + width, SLIDE_TIME)
	# Fully off-screen isn't enough - hide once closed so nothing can show or
	# catch clicks at the edge.
	if target_left == 0.0:
		_slide_tween.chain().tween_callback(hide)


func _toggle_mode() -> void:
	_match_all = not _match_all
	_update_mode_label()
	_emit_change()


func _update_mode_label() -> void:
	_mode_button.text = "Match: All" if _match_all else "Match: Any"


func _on_tag_toggled(pressed: bool, tag: String) -> void:
	if pressed:
		_selected[tag.to_lower()] = true
	else:
		_selected.erase(tag.to_lower())
	_emit_change()


func _on_tag_search_changed(query: String) -> void:
	_tag_search = query
	_apply_tag_search()


## Hides checkboxes that don't match the in-panel search. A ticked tag stays
## visible so the player can always see and undo what is filtering the grid.
func _apply_tag_search() -> void:
	for box in _checkboxes:
		box.visible = box.button_pressed or FuzzyMatch.matches(_tag_search, box.text)


func _emit_change() -> void:
	self.filters_changed.emit(selected_tags(), _match_all)
