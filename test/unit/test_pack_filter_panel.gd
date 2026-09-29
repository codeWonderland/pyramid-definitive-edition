extends GutTest

# Tests the draft screen's tag filter drawer: it builds a checkbox per declared
# tag, announces selection changes, searches its own list, and slides open/shut.

const FILTER_PANEL: PackedScene = preload("res://source/menus/menu_widgets/pack_filter_panel.tscn")

var _saved_all_packs: Array[PackData]


func _pack(title: String, tags: Array[String]) -> PackData:
	var pack := PackData.new()
	pack.title = title
	pack.folder_path = "user://__test_panel_%s" % title
	pack.tags = tags
	return pack


func before_each() -> void:
	_saved_all_packs = PacksManager.all_packs
	var packs: Array[PackData] = [
		_pack("A", ["Roguelike", "Deckbuilder"] as Array[String]),
		_pack("B", ["Metroidvania"] as Array[String]),
	]
	PacksManager.all_packs = packs


func after_each() -> void:
	PacksManager.all_packs = _saved_all_packs


func _make_panel() -> PackFilterPanel:
	var panel := FILTER_PANEL.instantiate() as PackFilterPanel
	add_child_autofree(panel)
	await get_tree().process_frame
	return panel


func _box_for(panel: PackFilterPanel, tag: String) -> CheckBox:
	for box in panel._checkboxes:
		if box.text == tag:
			return box
	return null


func test_builds_a_checkbox_per_tag_sorted() -> void:
	var panel := await _make_panel()

	var labels: Array = []
	for box in panel._checkboxes:
		labels.append(box.text)

	assert_eq(labels, ["Deckbuilder", "Metroidvania", "Roguelike"], "one sorted checkbox per tag")


func test_shows_empty_notice_when_no_pack_declares_tags() -> void:
	PacksManager.all_packs = [_pack("A", [] as Array[String])] as Array[PackData]

	var panel := await _make_panel()

	assert_eq(panel._checkboxes.size(), 0, "no checkboxes without tags")
	assert_true(panel._empty_label.visible, "the empty notice is shown instead")


func test_ticking_a_tag_emits_selection() -> void:
	var panel := await _make_panel()
	watch_signals(panel)

	_box_for(panel, "Roguelike").button_pressed = true

	assert_signal_emitted(panel, "filters_changed")
	assert_eq(panel.selected_tags(), ["Roguelike"], "the ticked tag is reported")


func test_mode_button_toggles_any_all() -> void:
	var panel := await _make_panel()

	assert_eq(panel._mode_button.text, "Match: Any", "starts in Any mode")

	panel._mode_button.pressed.emit()
	assert_eq(panel._mode_button.text, "Match: All", "switches to All")

	panel._mode_button.pressed.emit()
	assert_eq(panel._mode_button.text, "Match: Any", "switches back to Any")


func test_mode_change_reports_match_all() -> void:
	var panel := await _make_panel()
	var seen_match_all := [false]
	panel.filters_changed.connect(func(_tags, match_all): seen_match_all[0] = match_all)

	panel._mode_button.pressed.emit()

	assert_true(seen_match_all[0], "switching to All reports match_all = true")


func test_in_panel_search_hides_non_matching_tags() -> void:
	var panel := await _make_panel()

	panel._search.text_changed.emit("deck")

	assert_true(_box_for(panel, "Deckbuilder").visible, "matching tag stays visible")
	assert_false(_box_for(panel, "Metroidvania").visible, "non-matching tag is hidden")


func test_in_panel_search_keeps_ticked_tags_visible() -> void:
	var panel := await _make_panel()

	_box_for(panel, "Metroidvania").button_pressed = true
	panel._search.text_changed.emit("deck")

	assert_true(
		_box_for(panel, "Metroidvania").visible,
		"a ticked tag stays visible so it can always be un-ticked"
	)


func test_clear_filters_unticks_everything() -> void:
	var panel := await _make_panel()

	_box_for(panel, "Roguelike").button_pressed = true
	_box_for(panel, "Deckbuilder").button_pressed = true
	assert_eq(panel.selected_tags().size(), 2, "two tags ticked")

	panel.clear_filters()

	assert_eq(panel.selected_tags(), [], "clear unticks every tag")


func test_starts_closed_and_toggles_open() -> void:
	var panel := await _make_panel()

	assert_false(panel.is_open(), "the drawer starts closed")

	panel.open()
	await get_tree().create_timer(PackFilterPanel.SLIDE_TIME + 0.1).timeout
	assert_true(panel.is_open(), "opening slides it into view")

	panel.close()
	await get_tree().create_timer(PackFilterPanel.SLIDE_TIME + 0.1).timeout
	assert_false(panel.is_open(), "closing slides it back out")


func test_rebuild_keeps_existing_selection() -> void:
	var panel := await _make_panel()

	_box_for(panel, "Roguelike").button_pressed = true
	panel.rebuild()

	assert_eq(panel.selected_tags(), ["Roguelike"], "a ticked tag survives a rebuild")


# --- Closed means gone, and it can always be closed ---


func _click_at(position: Vector2) -> InputEventMouseButton:
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = position
	return click


func _opened() -> PackFilterPanel:
	var panel := await _make_panel()
	panel.open()
	await get_tree().create_timer(PackFilterPanel.SLIDE_TIME + 0.1).timeout
	return panel


func test_a_closed_drawer_is_hidden() -> void:
	var panel := await _make_panel()
	assert_false(panel.visible, "nothing of a closed drawer can show at the screen edge")


func test_closing_hides_the_drawer_once_it_has_slid_away() -> void:
	var panel := await _opened()
	assert_true(panel.visible, "visible while open")

	panel.close()
	await get_tree().create_timer(PackFilterPanel.SLIDE_TIME + 0.1).timeout

	assert_false(panel.visible, "hidden again once closed")


func test_drawer_is_never_narrower_than_its_contents() -> void:
	# Narrower than its contents, the drawer grew past its own edge and poked
	# into the screen while closed.
	# (It still never exceeds the window, so on a tiny screen it is the screen.)
	var panel := await _make_panel()
	var screen_width := panel.get_viewport().get_visible_rect().size.x

	assert_gte(
		panel._panel_width(),
		minf(panel._backing.get_combined_minimum_size().x, screen_width),
		"the drawer is sized to fit what is in it"
	)


func test_close_button_closes_the_drawer() -> void:
	var panel := await _opened()

	panel._close_button.pressed.emit()
	await get_tree().create_timer(PackFilterPanel.SLIDE_TIME + 0.1).timeout

	assert_false(panel.is_open(), "the X closes it")


func test_escape_closes_the_drawer() -> void:
	var panel := await _opened()

	var escape := InputEventAction.new()
	escape.action = "Escape"
	escape.pressed = true
	panel._input(escape)
	await get_tree().create_timer(PackFilterPanel.SLIDE_TIME + 0.1).timeout

	assert_false(panel.is_open(), "Escape closes it")


func test_clicking_outside_closes_the_drawer() -> void:
	var panel := await _opened()

	# Left of the drawer's own rect, which is all that matters to the check.
	panel._input(_click_at(panel.get_global_rect().position - Vector2(20, 0)))
	await get_tree().create_timer(PackFilterPanel.SLIDE_TIME + 0.1).timeout

	assert_false(panel.is_open(), "a click beside the drawer closes it")


func test_clicking_inside_keeps_the_drawer_open() -> void:
	var panel := await _opened()

	panel._input(_click_at(panel.get_global_rect().get_center()))
	await get_tree().create_timer(PackFilterPanel.SLIDE_TIME + 0.1).timeout

	assert_true(panel.is_open(), "clicks within the drawer are for its controls")
