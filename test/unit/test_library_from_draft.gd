extends GutTest

# Tests opening a game's Library entry from the draft screen with L, and the
# Library returning to the draft afterwards. Also: the Library only says a game is
# free, never that it's paid.

const PACK_SELECT: PackedScene = preload("res://source/menus/pack_select.tscn")
const LIBRARY: PackedScene = preload("res://source/menus/library.tscn")

var _saved_all_packs: Array[PackData]


func _pack(title: String) -> PackData:
	var pack := PackData.new()
	pack.title = title
	pack.folder_path = "user://__test_lfd_%s" % title
	var texture := ImageTexture.create_from_image(Image.create(4, 4, false, Image.FORMAT_RGBA8))
	pack.backs.append(texture)
	pack.primaries.append(texture)
	return pack


func before_each() -> void:
	_saved_all_packs = PacksManager.all_packs
	PacksManager.all_packs = [_pack("Alpha"), _pack("Bravo")] as Array[PackData]


func after_each() -> void:
	PacksManager.all_packs = _saved_all_packs
	RunManager.library_return_scene = ""
	RunManager.library_focus_path = ""


func test_the_game_under_the_cursor_is_found() -> void:
	var screen := PACK_SELECT.instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame
	await get_tree().process_frame

	var card: PackSelectCard = screen._pack_select_packs.get_child(1)
	var found: PackData = screen.pack_under(card.get_global_rect().get_center())

	assert_eq(found, card.pack_data, "the card's own game")
	assert_null(screen.pack_under(Vector2(-500, -500)), "and nothing off the cards")


func test_the_library_opens_the_requested_game_and_returns() -> void:
	RunManager.library_return_scene = "res://source/menus/pack_select.tscn"
	RunManager.library_focus_path = PacksManager.all_packs[1].folder_path

	var library := LIBRARY.instantiate() as Library
	add_child_autofree(library)
	await get_tree().process_frame

	assert_true(library._details.visible, "opened straight to a game")
	assert_eq(library._selected, PacksManager.all_packs[1], "the one asked for")
	assert_eq(RunManager.library_focus_path, "", "asked once")
	assert_eq(
		RunManager.library_return_scene,
		"res://source/menus/pack_select.tscn",
		"and remembers to go back to the draft"
	)


func test_the_library_only_mentions_free() -> void:
	var free := _pack("Free")
	free.metadata = {"is_free": true}
	var paid := _pack("Paid")
	paid.metadata = {"is_free": false}

	var library := LIBRARY.instantiate() as Library
	add_child_autofree(library)
	await get_tree().process_frame

	library._show_details(free)
	assert_true(library._free_pill.visible, "free is called out")
	library._show_details(paid)
	assert_false(library._free_pill.visible, "paid is the norm, left unsaid")
