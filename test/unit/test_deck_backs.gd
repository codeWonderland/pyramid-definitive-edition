extends GutTest

# Tests that the table shows each deck's own back (pack backs b1, b2, b3 for the
# primary, secondary and curse decks, falling back to b1), and that the pack
# editor takes no more than three backs.

const GAME_SCENE: PackedScene = preload("res://source/game/game.tscn")
const PACK_EDITOR: PackedScene = preload("res://source/mod-manager/popups/pack_editor.tscn")
const IMAGE_DIR: String = "user://__test_deck_backs/"


func after_each() -> void:
	RunManager.popup_open = false
	if DirAccess.dir_exists_absolute(IMAGE_DIR):
		for file_name in DirAccess.get_files_at(IMAGE_DIR):
			DirAccess.remove_absolute(IMAGE_DIR + file_name)
		DirAccess.remove_absolute(IMAGE_DIR)


func _texture(fill: Color = Color.WHITE) -> ImageTexture:
	var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(fill)
	return ImageTexture.create_from_image(img)


func _pack(back_count: int) -> PackData:
	var pack := PackData.new()
	pack.title = "Backs"
	pack.folder_path = "user://test_pack_deck_backs"
	for i in back_count:
		pack.backs.append(_texture(Color(0.1 * i, 0, 0)))
	var primaries: Array[ImageTexture] = [_texture(), _texture()]
	var secondaries: Array[ImageTexture] = [_texture(), _texture()]
	var curses: Array[ImageTexture] = [_texture()]
	pack.primaries = primaries
	pack.secondaries = secondaries
	pack.curses = curses
	return pack


func _table(pack: PackData) -> CardGroup:
	RunManager.clear()
	RunManager.num_games = 1
	var packs: Array[PackData] = [pack]
	RunManager.selected_packs = packs
	var game := GAME_SCENE.instantiate() as Game
	add_child_autofree(game)
	await get_tree().process_frame
	await get_tree().process_frame
	game._card_group_collection.set_physics_process(false)
	return game._card_group_collection._card_groups[0]


func _pile_back(pile: CardPile) -> Texture2D:
	return pile._backs[0].texture if not pile._backs.is_empty() else null


func test_each_deck_shows_its_own_back() -> void:
	var pack := _pack(3)
	var group := await _table(pack)

	assert_eq(_pile_back(group._primary_pile), pack.backs[0], "primary pile")
	assert_eq(_pile_back(group._secondary_pile), pack.backs[1], "secondary pile")
	for card in group.table_cards():
		var expected := (
			pack.backs[2] if card.is_curse else pack.backs[1 if card.deck_is_secondary else 0]
		)
		assert_eq(card.back_texture, expected, "dealt card")

	group._restore_card({"entry": -1, "curse": true})
	assert_eq(group.table_cards()[-1].back_texture, pack.backs[2], "a curse shows the curse back")


func test_decks_without_their_own_back_use_the_default() -> void:
	var pack := _pack(1)
	var group := await _table(pack)

	assert_eq(_pile_back(group._secondary_pile), pack.backs[0])
	group._restore_card({"entry": -1, "curse": true})
	assert_eq(group.table_cards()[-1].back_texture, pack.backs[0])


func test_the_editor_takes_at_most_three_backs() -> void:
	DirAccess.make_dir_recursive_absolute(IMAGE_DIR)
	var files := PackedStringArray()
	for i in 4:
		var path := IMAGE_DIR + "b%d.png" % (i + 1)
		Image.create(4, 4, false, Image.FORMAT_RGBA8).save_png(path)
		files.append(ProjectSettings.globalize_path(path))
	var editor := PACK_EDITOR.instantiate() as PackEditor
	add_child_autofree(editor)
	await get_tree().process_frame
	editor.pack_data = null
	editor.open()
	await get_tree().process_frame
	assert_true(editor._add_card_back_button.visible, "room for backs to start with")

	editor._select_new_card(editor._card_backs, editor._add_card_back_button)
	editor._file_dialog.hide()
	editor._file_dialog.files_selected.emit(files)

	assert_eq(editor.pack_data.backs.size(), PackData.MAX_BACKS, "the fourth is left out")
	assert_false(editor._add_card_back_button.visible, "and there's no way to add one")
