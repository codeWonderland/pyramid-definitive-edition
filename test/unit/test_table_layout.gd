extends GutTest

# Tests the card table's layout changes: cards 15% larger, and the trash can moved
# from under the reroll button to above the multiplayer and co-op buttons.

const GAME_SCENE: PackedScene = preload("res://source/game/game.tscn")


func _texture() -> ImageTexture:
	var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	return ImageTexture.create_from_image(img)


func _pack() -> PackData:
	var pack := PackData.new()
	pack.title = "Test"
	pack.folder_path = "user://test_pack_table_layout"
	var backs: Array[ImageTexture] = [_texture()]
	var primaries: Array[ImageTexture] = [_texture(), _texture()]
	pack.backs = backs
	pack.primaries = primaries
	return pack


func after_each() -> void:
	RunManager.clear()


func test_cards_are_as_large_as_the_table_allows() -> void:
	var original := {1: Vector2(210, 300), 3: Vector2(157.5, 225), 5: Vector2(105, 150)}
	for games in [1, 5]:
		RunManager.num_games = games
		assert_eq(
			RunManager.get_card_size(),
			original[games] * RunManager.TABLE_CARD_SCALE,
			"%d-game cards scaled up" % games
		)

	RunManager.num_games = 3
	var three := RunManager.get_card_size()
	assert_almost_eq(
		three.x * 6 + RunManager.TABLE_GAP * 2,
		RunManager.MAX_ROW_WIDTH,
		0.01,
		"three tables grow until their row is full"
	)
	assert_gt(three.x, original[3].x * 1.15, "still larger than before")
	assert_almost_eq(three.x / three.y, 0.7, 0.001, "and keep their proportions")


func test_tables_never_overlap() -> void:
	for games in [3, 5]:
		RunManager.clear()
		RunManager.num_games = games
		var packs: Array[PackData] = []
		for i in range(games):
			packs.append(_pack())
		RunManager.selected_packs = packs
		var game := GAME_SCENE.instantiate() as Game
		add_child_autofree(game)
		await get_tree().process_frame
		await get_tree().process_frame

		var tables: Array[Rect2] = []
		for group in game._card_group_collection._card_groups:
			if group.visible:
				var card: Vector2 = group._scaled_card_size()
				tables.append(Rect2(group.global_position, Vector2(card.x * 2, card.y)))
		assert_eq(tables.size(), games, "%d tables laid out" % games)
		for a in range(tables.size()):
			for b in range(a + 1, tables.size()):
				assert_false(
					tables[a].intersects(tables[b]),
					"%d games: tables %d and %d are apart" % [games, a, b]
				)
		game.queue_free()
		await get_tree().process_frame


func test_trash_can_sits_above_the_rules_buttons() -> void:
	RunManager.clear()
	RunManager.num_games = 1
	RunManager.selected_packs = [_pack()] as Array[PackData]
	var game := GAME_SCENE.instantiate() as Game
	add_child_autofree(game)
	await get_tree().process_frame
	await get_tree().process_frame

	var trash: TrashZone = null
	for child in game.get_children():
		if child is TrashZone:
			trash = child
	assert_not_null(trash, "the table has a trash can")

	RunManager.begin_card_drag()
	var rules := game._bottom_right.get_global_rect()
	var zone := trash.get_global_rect()

	assert_true(trash.visible, "it appears while dragging")
	assert_lte(zone.end.y, rules.position.y, "above the multiplayer and co-op buttons")
	assert_almost_eq(zone.get_center().x, rules.get_center().x, 1.0, "centred over them")
	assert_false(
		zone.intersects(game._reroll_packs_button.get_global_rect()),
		"no longer hidden under reroll games"
	)
	RunManager.end_card_drag()
