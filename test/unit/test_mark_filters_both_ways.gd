extends GutTest

# Tests mark filters that work both ways: each cycles off, "only these games",
# "hide these games" - so a mark like Avoid on stream can leave its games out of
# the draft instead of being the only ones shown.

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
	pack.folder_path = "user://__test_markhide_%s" % title
	var backs: Array[ImageTexture] = [_texture()]
	pack.backs = backs
	pack.tags = tags
	return pack


func _path(title: String) -> String:
	return "user://__test_markhide_%s" % title


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


func _panel() -> PackFilterPanel:
	var panel := FILTER_PANEL.instantiate() as PackFilterPanel
	add_child_autofree(panel)
	await get_tree().process_frame
	return panel


func test_a_hidden_mark_leaves_its_games_out() -> void:
	PlayerMarksManager.set_mark(_path("Bravo"), "avoid_on_stream", true)
	var grid := await _grid()

	grid.set_mark_filters([] as Array[String], ["avoid_on_stream"] as Array[String])

	assert_eq(
		_titles(grid._ordered_packs()), ["Alpha", "Charlie"], "the stream-unfriendly game is gone"
	)


func test_a_hidden_mark_applies_under_any_too() -> void:
	PlayerMarksManager.set_mark(_path("Alpha"), "avoid_on_stream", true)
	var grid := await _grid()

	grid.set_mark_filters([] as Array[String], ["avoid_on_stream"] as Array[String])
	grid.set_tag_filters(["Roguelike"] as Array[String], false)

	assert_false(_titles(grid._ordered_packs()).has("Alpha"), "hiding wins over matching a tag")


func test_a_mark_filter_cycles_off_only_hide() -> void:
	var panel := await _panel()
	var button: Button = panel._mark_buttons[0]

	button.pressed.emit()
	assert_eq(button.text, "Only: Owned")
	assert_eq(panel.selected_marks(), ["owned"], "narrowing to owned games")
	assert_eq(panel.hidden_marks(), [])

	button.pressed.emit()
	assert_eq(button.text, "Hide: Owned")
	assert_eq(panel.selected_marks(), [])
	assert_eq(panel.hidden_marks(), ["owned"], "hiding owned games")

	button.pressed.emit()
	assert_eq(button.text, "Owned", "and back off")
	assert_eq(panel.hidden_marks(), [])
