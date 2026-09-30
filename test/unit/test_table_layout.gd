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


func test_cards_are_fifteen_percent_larger() -> void:
	var original := {1: Vector2(210, 300), 3: Vector2(157.5, 225), 5: Vector2(105, 150)}
	for games in original:
		RunManager.num_games = games
		assert_eq(
			RunManager.get_card_size(), original[games] * 1.15, "%d-game cards scaled up" % games
		)


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
