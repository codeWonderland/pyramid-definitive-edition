extends GutTest

# Smoke test: building the draft screen runs the in-code layout restructuring
# (toolbar, side arrows, scrollable selection) without errors.

const PACK_SELECT: PackedScene = preload("res://source/menus/pack_select.tscn")


func test_draft_screen_builds_and_restructures() -> void:
	var screen := PACK_SELECT.instantiate() as PackSelect
	add_child_autofree(screen)
	await get_tree().process_frame

	assert_true(is_instance_valid(screen), "draft screen built without error")
	assert_true(is_instance_valid(screen._previous), "prev button resolved")
	assert_true(is_instance_valid(screen._next), "next button resolved")
	assert_true(is_instance_valid(screen._sort_button), "sort button resolved")
	assert_true(is_instance_valid(screen._filter_button), "filter button resolved")
	assert_true(
		screen._pack_select_selected_packs.get_parent() is ScrollContainer,
		"selected-packs strip lives in a scroll view"
	)


# --- Search + filter panel wiring (#38) ---


func test_search_bar_and_filter_controls_resolve() -> void:
	var screen := PACK_SELECT.instantiate() as PackSelect
	add_child_autofree(screen)
	await get_tree().process_frame

	assert_true(is_instance_valid(screen._search_bar), "search bar resolved")
	assert_true(is_instance_valid(screen._tag_filter_button), "filters button resolved")
	assert_true(is_instance_valid(screen._filter_panel), "filter panel resolved")
	assert_false(screen._filter_panel.is_open(), "the filter drawer starts closed")


func test_typing_in_the_search_bar_filters_the_grid() -> void:
	var screen := PACK_SELECT.instantiate() as PackSelect
	add_child_autofree(screen)
	await get_tree().process_frame

	screen._search_bar.text_changed.emit("zzzzz-no-such-pack")

	assert_eq(screen._pack_select_packs._ordered_packs(), [], "an unmatched query empties the grid")


func test_filters_button_opens_the_drawer() -> void:
	var screen := PACK_SELECT.instantiate() as PackSelect
	add_child_autofree(screen)
	await get_tree().process_frame

	screen._tag_filter_button.pressed.emit()
	await get_tree().create_timer(PackFilterPanel.SLIDE_TIME + 0.1).timeout

	assert_true(screen._filter_panel.is_open(), "the Filters button slides the drawer open")
