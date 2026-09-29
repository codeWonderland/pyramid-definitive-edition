extends GutTest

# Tests player marks acting on the draft screen (#36): never draft hides a game,
# don't own can hide one unless it is marked want to include anyway, and marks
# work as filters alongside the category tags.

const PACK_SELECT_PACKS: PackedScene = preload(
	"res://source/menus/menu_widgets/pack_select_packs.tscn"
)
const FILTER_PANEL: PackedScene = preload("res://source/menus/menu_widgets/pack_filter_panel.tscn")

var _saved_all_packs: Array[PackData]
var _saved_show: bool
var _saved_hide: bool


func _texture() -> ImageTexture:
	var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	return ImageTexture.create_from_image(img)


func _pack(title: String, tags: Array[String] = []) -> PackData:
	var pack := PackData.new()
	pack.title = title
	pack.folder_path = "user://__test_draftmarks_%s" % title
	var backs: Array[ImageTexture] = [_texture()]
	pack.backs = backs
	pack.tags = tags
	return pack


func _path(title: String) -> String:
	return "user://__test_draftmarks_%s" % title


func before_each() -> void:
	_saved_all_packs = PacksManager.all_packs
	_saved_show = UserSettingsManager.draft_show_never_draft
	_saved_hide = UserSettingsManager.draft_hide_unowned
	UserSettingsManager.update_draft_visibility(false, false)
	var packs: Array[PackData] = [
		_pack("Alpha", ["Roguelike"] as Array[String]),
		_pack("Bravo", ["Puzzle"] as Array[String]),
		_pack("Charlie", ["Roguelike"] as Array[String]),
	]
	PacksManager.all_packs = packs


func after_each() -> void:
	for pack in PacksManager.all_packs:
		for mark in PlayerMarksManager.MARKS:
			PlayerMarksManager.set_mark(pack.folder_path, mark["id"], false)
	PacksManager.all_packs = _saved_all_packs
	UserSettingsManager.update_draft_visibility(_saved_show, _saved_hide)


func _titles(packs: Array) -> Array:
	var out: Array = []
	for pack in packs:
		out.append(pack.title)
	return out


func _grid() -> PackSelectPacks:
	var grid := PACK_SELECT_PACKS.instantiate() as PackSelectPacks
	add_child_autofree(grid)
	await get_tree().process_frame
	return grid


# --- The visibility rule ---


func test_never_draft_hides_a_game() -> void:
	PlayerMarksManager.set_mark(_path("Bravo"), "never_draft", true)

	assert_true(PlayerMarksManager.hidden_from_draft(_path("Bravo")), "hidden")
	assert_false(PlayerMarksManager.hidden_from_draft(_path("Alpha")), "others are not")


func test_never_draft_games_can_be_shown_on_request() -> void:
	PlayerMarksManager.set_mark(_path("Bravo"), "never_draft", true)

	assert_false(PlayerMarksManager.hidden_from_draft(_path("Bravo"), true), "shown when asked for")


func test_dont_own_is_only_hidden_when_asked() -> void:
	PlayerMarksManager.set_mark(_path("Bravo"), "dont_own", true)

	assert_false(PlayerMarksManager.hidden_from_draft(_path("Bravo")), "visible by default")
	assert_true(
		PlayerMarksManager.hidden_from_draft(_path("Bravo"), false, true),
		"hidden with hide-unowned on"
	)


func test_include_anyway_overrides_hiding_unowned_games() -> void:
	PlayerMarksManager.set_mark(_path("Bravo"), "dont_own", true)
	PlayerMarksManager.set_mark(_path("Bravo"), "include_anyway", true)

	assert_false(
		PlayerMarksManager.hidden_from_draft(_path("Bravo"), false, true),
		"want to include anyway keeps an unowned game in the draft"
	)


func test_never_draft_and_include_anyway_exclude_each_other() -> void:
	PlayerMarksManager.set_mark(_path("Bravo"), "never_draft", true)
	PlayerMarksManager.set_mark(_path("Bravo"), "include_anyway", true)

	assert_false(PlayerMarksManager.has_mark(_path("Bravo"), "never_draft"), "cleared")

	PlayerMarksManager.set_mark(_path("Bravo"), "never_draft", true)
	assert_false(PlayerMarksManager.has_mark(_path("Bravo"), "include_anyway"), "both ways")


# --- On the draft grid ---


func test_grid_leaves_out_never_draft_games() -> void:
	PlayerMarksManager.set_mark(_path("Bravo"), "never_draft", true)
	var grid := await _grid()

	assert_eq(_titles(grid._ordered_packs()), ["Alpha", "Charlie"], "Bravo is gone")


func test_grid_brings_them_back_when_asked() -> void:
	PlayerMarksManager.set_mark(_path("Bravo"), "never_draft", true)
	var grid := await _grid()

	grid.set_draft_visibility(true, false)

	assert_eq(_titles(grid._ordered_packs()), ["Alpha", "Bravo", "Charlie"], "all three again")


func test_grid_updates_when_a_mark_changes_elsewhere() -> void:
	var grid := await _grid()
	assert_eq(grid._ordered_packs().size(), 3, "all shown first")

	PlayerMarksManager.set_mark(_path("Alpha"), "never_draft", true)

	assert_eq(_titles(grid._ordered_packs()), ["Bravo", "Charlie"], "hidden straight away")


func test_grid_hides_unowned_games_when_asked() -> void:
	PlayerMarksManager.set_mark(_path("Alpha"), "dont_own", true)
	PlayerMarksManager.set_mark(_path("Charlie"), "dont_own", true)
	PlayerMarksManager.set_mark(_path("Charlie"), "include_anyway", true)
	var grid := await _grid()

	grid.set_draft_visibility(false, true)

	assert_eq(
		_titles(grid._ordered_packs()),
		["Bravo", "Charlie"],
		"unowned Alpha hidden; unowned-but-included Charlie kept"
	)


func test_the_grid_starts_from_the_saved_visibility() -> void:
	PlayerMarksManager.set_mark(_path("Bravo"), "never_draft", true)
	UserSettingsManager.update_draft_visibility(true, false)

	var grid := await _grid()

	assert_eq(grid._ordered_packs().size(), 3, "the saved show-never-draft choice applies")


# --- Marks as filters ---


func test_a_mark_filter_narrows_the_grid() -> void:
	PlayerMarksManager.set_mark(_path("Charlie"), "controller_friendly", true)
	var grid := await _grid()

	grid.set_mark_filters(["controller_friendly"] as Array[String])

	assert_eq(_titles(grid._ordered_packs()), ["Charlie"], "only the marked game")


func test_marks_and_tags_combine_under_all() -> void:
	PlayerMarksManager.set_mark(_path("Alpha"), "owned", true)
	PlayerMarksManager.set_mark(_path("Bravo"), "owned", true)
	var grid := await _grid()

	grid.set_mark_filters(["owned"] as Array[String])
	grid.set_tag_filters(["Roguelike"] as Array[String], true)

	assert_eq(_titles(grid._ordered_packs()), ["Alpha"], "owned AND roguelike")


func test_marks_and_tags_combine_under_any() -> void:
	PlayerMarksManager.set_mark(_path("Bravo"), "owned", true)
	var grid := await _grid()

	grid.set_mark_filters(["owned"] as Array[String])
	grid.set_tag_filters(["Roguelike"] as Array[String], false)

	assert_eq(_titles(grid._ordered_packs()), ["Alpha", "Bravo", "Charlie"], "owned OR roguelike")


# --- The drawer ---


func _panel() -> PackFilterPanel:
	var panel := FILTER_PANEL.instantiate() as PackFilterPanel
	add_child_autofree(panel)
	await get_tree().process_frame
	return panel


func test_drawer_offers_the_filterable_marks() -> void:
	var panel := await _panel()

	assert_eq(panel._mark_boxes.size(), PlayerMarksManager.FILTERABLE_MARKS.size(), "one box each")
	assert_eq(panel._mark_boxes[0].text, "Owned", "labelled as in the library")


func test_ticking_a_mark_is_reported() -> void:
	var panel := await _panel()

	panel._mark_boxes[0].button_pressed = true

	assert_eq(panel.selected_marks(), ["owned"], "the drawer reports it")


func test_clear_unticks_marks_but_keeps_visibility() -> void:
	var panel := await _panel()
	panel._mark_boxes[0].button_pressed = true
	panel._show_never_draft.button_pressed = true

	panel.clear_filters()

	assert_eq(panel.selected_marks(), [], "marks cleared")
	assert_true(panel.show_never_draft(), "visibility is a standing preference, left alone")


func test_visibility_options_are_remembered() -> void:
	var panel := await _panel()

	panel._hide_unowned.button_pressed = true

	assert_true(UserSettingsManager.draft_hide_unowned, "saved")
	var again := await _panel()
	assert_true(again.hide_unowned(), "and a new drawer starts from it")


func test_draft_screen_wires_the_drawer_to_the_grid() -> void:
	PlayerMarksManager.set_mark(_path("Bravo"), "never_draft", true)
	PlayerMarksManager.set_mark(_path("Charlie"), "too_long", true)
	var screen := (load("res://source/menus/pack_select.tscn") as PackedScene).instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame
	var grid: PackSelectPacks = screen._pack_select_packs
	assert_eq(grid._ordered_packs().size(), 2, "never-draft Bravo hidden on arrival")

	screen._filter_panel._show_never_draft.button_pressed = true
	assert_eq(grid._ordered_packs().size(), 3, "the drawer's show option reaches the grid")

	screen._filter_panel._mark_boxes[3].button_pressed = true  # Too long
	assert_eq(_titles(grid._ordered_packs()), ["Charlie"], "and so does a mark filter")
