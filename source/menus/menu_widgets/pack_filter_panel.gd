class_name PackFilterPanel extends Control

## Filter drawer for the draft screen. Slides in from the right edge with the
## player's visibility options, a three-way filter per player mark, a checkbox per
## tag declared by the loaded packs, an any/all mode toggle, and a search box for
## when the list grows long.

signal filters_changed(tags: Array[String], match_all: bool)

## A mark filter's three states, cycled by clicking it. Marks like "Avoid on
## stream" are mostly wanted the other way round - leave those games out - so a
## mark can narrow the draft to its games or hide them.
enum MarkFilter { OFF, ONLY, HIDE }

## Panel width at the 1920x1080 reference size; scaled to fit smaller screens.
const REFERENCE_WIDTH: float = 420.0
const SLIDE_TIME: float = 0.25

const MARK_FILTER_PREFIX: Dictionary = {
	MarkFilter.OFF: "",
	MarkFilter.ONLY: "Only: ",
	MarkFilter.HIDE: "Hide: ",
}
const MARK_FILTER_COLOR: Dictionary = {
	MarkFilter.OFF: Color(1, 1, 1, 1),
	MarkFilter.ONLY: Color(0.55, 0.85, 1, 1),
	MarkFilter.HIDE: Color(1, 0.55, 0.5, 1),
}

var _match_all: bool = false
var _tag_search: String = ""
# Ticked tags, keyed by their lowercased form so the set survives packs that
# spell the same tag differently.
var _selected: Dictionary = {}
var _checkboxes: Array[CheckBox] = []
var _mark_buttons: Array[Button] = []
var _slide_tween: Tween = null

@onready var _backing: PanelContainer = %Backing
@onready var _close_button: TextureButton = %Close
@onready var _mode_button: Button = %ModeButton
@onready var _search: LineEdit = %TagSearch
@onready var _tag_list: VBoxContainer = %TagList
@onready var _mark_list: VBoxContainer = %MarkList
@onready var _show_never_draft: CheckBox = %ShowNeverDraft
@onready var _hide_unowned: CheckBox = %HideUnowned
@onready var _clear_button: Button = %ClearButton
@onready var _empty_label: Label = %EmptyLabel


func _ready() -> void:
	_resize()
	get_tree().get_root().size_changed.connect(_resize)

	_mode_button.pressed.connect(_toggle_mode)
	_search.text_changed.connect(_on_tag_search_changed)
	_clear_button.pressed.connect(clear_filters)
	_close_button.pressed.connect(close)

	_show_never_draft.set_pressed_no_signal(UserSettingsManager.draft_show_never_draft)
	_hide_unowned.set_pressed_no_signal(UserSettingsManager.draft_hide_unowned)
	_show_never_draft.toggled.connect(_on_visibility_toggled)
	_hide_unowned.toggled.connect(_on_visibility_toggled)

	_build_mark_boxes()

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


## Unticks every tag and mark. The visibility options are left alone: they are
## standing preferences, not part of narrowing down this draft.
func clear_filters() -> void:
	_selected.clear()
	for box in _checkboxes:
		box.set_pressed_no_signal(false)
	for button in _mark_buttons:
		_set_mark_filter(button, MarkFilter.OFF)
	_emit_change()


## Marks whose games the draft is narrowed to.
func selected_marks() -> Array[String]:
	return _marks_set_to(MarkFilter.ONLY)


## Marks whose games the draft leaves out.
func hidden_marks() -> Array[String]:
	return _marks_set_to(MarkFilter.HIDE)


## Moves a mark's filter on to its next state: off, only, hide, off again.
func cycle_mark_filter(mark: String) -> void:
	for button in _mark_buttons:
		if button.get_meta("mark") == mark:
			var next: int = (int(button.get_meta("state")) + 1) % MarkFilter.size()
			_set_mark_filter(button, next)
	_emit_change()


func _marks_set_to(state: int) -> Array[String]:
	var marks: Array[String] = []
	for button in _mark_buttons:
		if int(button.get_meta("state")) == state:
			marks.append(button.get_meta("mark"))
	return marks


func show_never_draft() -> bool:
	return _show_never_draft.button_pressed


func hide_unowned() -> bool:
	return _hide_unowned.button_pressed


func _build_mark_boxes() -> void:
	for mark in PlayerMarksManager.FILTERABLE_MARKS:
		var button := Button.new()
		button.theme_type_variation = &"MarkFilterButton"
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.tooltip_text = "Click to cycle: off, only these games, hide these games"
		button.set_meta("mark", mark)
		button.pressed.connect(cycle_mark_filter.bind(mark))
		_mark_list.add_child(button)
		_mark_buttons.append(button)
		_set_mark_filter(button, MarkFilter.OFF)


func _set_mark_filter(button: Button, state: int) -> void:
	button.set_meta("state", state)
	var label := PlayerMarksManager.label_for(button.get_meta("mark"))
	button.text = MARK_FILTER_PREFIX[state] + label
	# The state's colour is per button and changes as it's clicked - not
	# something a static theme can say.
	for slot in [&"font_color", &"font_hover_color", &"font_focus_color", &"font_pressed_color"]:
		button.add_theme_color_override(slot, MARK_FILTER_COLOR[state])


func _on_visibility_toggled(_on: bool) -> void:
	UserSettingsManager.update_draft_visibility(show_never_draft(), hide_unowned())
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
		box.theme_type_variation = &"SmallCheckBox"
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
	for box in _checkboxes + _mark_buttons:
		box.visible = box.button_pressed or FuzzyMatch.matches(_tag_search, box.text)


func _emit_change() -> void:
	self.filters_changed.emit(selected_tags(), _match_all)
