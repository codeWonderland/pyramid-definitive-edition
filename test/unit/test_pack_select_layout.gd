extends GutTest

# Smoke test: building the draft screen runs the in-code layout restructuring
# (toolbar, side arrows, scrollable selection) without errors.

const PACK_SELECT: PackedScene = preload("res://source/menus/pack_select.tscn")


func test_draft_screen_builds_and_restructures() -> void:
	var screen := PACK_SELECT.instantiate() as PackSelect
	add_child_autofree(screen)
	await get_tree().process_frame

	assert_true(is_instance_valid(screen), "draft screen built without error")
	assert_true(is_instance_valid(screen._prev_button), "prev caret button created")
	assert_true(is_instance_valid(screen._next_button), "next caret button created")
	assert_same(screen._prev_button.get_parent(), screen, "prev caret floated to the screen root")
	assert_true(is_instance_valid(screen._sort_button), "sort button created")
	assert_true(is_instance_valid(screen._filter_button), "filter button created")
	assert_true(
		screen._pack_select_selected_packs.get_parent() is ScrollContainer,
		"selected-packs strip wrapped in a scroll view"
	)
