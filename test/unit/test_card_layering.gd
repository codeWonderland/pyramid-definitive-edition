extends GutTest

# Tests which card counts as "on top" on the table: the one drawn over the others.
# F, hover and clicks must all agree, or F flips a card hidden underneath (as it
# did when a curse or a neighbouring card overlapped another at the same layer).

const GAME_SCENE: PackedScene = preload("res://source/game/game.tscn")


func after_each() -> void:
	RunManager.popup_open = false


func _texture(fill: Color = Color.WHITE) -> ImageTexture:
	var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(fill)
	return ImageTexture.create_from_image(img)


func _make_pack() -> PackData:
	var pack := PackData.new()
	pack.title = "Test"
	pack.folder_path = "user://test_pack_flipping"

	var backs: Array[ImageTexture] = [_texture(Color.BLACK)]
	var primaries: Array[ImageTexture] = [_texture(), _texture(), _texture()]
	var secondaries: Array[ImageTexture] = [_texture(), _texture()]
	var curses: Array[ImageTexture] = [_texture()]
	pack.backs = backs
	pack.primaries = primaries
	pack.secondaries = secondaries
	pack.curses = curses
	return pack


func _make_table(games: int = 3) -> Game:
	RunManager.clear()
	RunManager.num_games = games
	var packs: Array[PackData] = []
	for i in range(games):
		packs.append(_make_pack())
	RunManager.selected_packs = packs

	var game := GAME_SCENE.instantiate() as Game
	add_child_autofree(game)
	await get_tree().process_frame
	await get_tree().process_frame
	# Let the opening hands finish dropping onto the table, as a player would.
	var cards := _all_table_cards(game)
	var deal_time := (
		CardGroupCollection.DEAL_DELAY + Motion.TIME + Motion.STAGGER * cards.size() + 0.1
	)
	await get_tree().create_timer(deal_time).timeout
	# These tests aim at points, not the cursor: stop the table hovering whatever
	# card the idle cursor happens to rest on, which in a tiny headless window
	# overlaps everything.
	game._card_group_collection.set_physics_process(false)
	for card in _all_table_cards(game):
		card.set_hovered(false)
	return game


func _all_table_cards(game: Game) -> Array:
	var cards: Array = []
	for group in game._card_group_collection._card_groups:
		if group.pack != null:
			cards.append_array(group._table_cards)
	return cards


func _stack(game: Game) -> Array:
	# The first group's opening cards, piled on one spot at the same layer.
	var group: CardGroup = game._card_group_collection._card_groups[0]
	var cards: Array = group.table_cards()
	for card in cards:
		card.position = cards[0].position
		card.z_index = CardGroup.CARD_BASE_Z
	return cards


func test_a_tie_goes_to_the_card_drawn_on_top() -> void:
	var game := await _make_table()
	var cards := _stack(game)
	assert_gt(cards.size(), 1, "two cards to stack")

	var point: Vector2 = cards[0].get_global_rect().get_center()
	var group: CardGroup = game._card_group_collection._card_groups[0]

	assert_eq(group.card_at(point), cards[-1], "the later card is drawn over the earlier one")
	assert_true(cards[-1].is_drawn_above(cards[0]))
	assert_false(cards[0].is_drawn_above(cards[-1]))


func test_f_flips_the_card_you_can_see() -> void:
	var game := await _make_table(1)
	var cards := _stack(game)
	var point: Vector2 = cards[0].get_global_rect().get_center()

	game.flip_card_at(point)
	await get_tree().create_timer(ChallengeCard.FLIP_TIME + 0.1).timeout

	assert_false(cards[-1].face_down, "the visible card turned over")
	assert_true(cards[0].face_down, "not the one hidden under it")


func test_a_higher_layer_beats_tree_order() -> void:
	var game := await _make_table()
	var cards := _stack(game)
	cards[0].bring_to_front()

	var point: Vector2 = cards[0].get_global_rect().get_center()

	assert_eq(game._card_group_collection.card_at(point), cards[0], "a card lifted by a drag wins")


func test_only_one_card_hovers_and_it_rises_then_settles() -> void:
	var game := await _make_table()
	var cards := _stack(game)
	var below: ChallengeCard = cards[0]
	var above: ChallengeCard = cards[-1]

	above.set_hovered(true)
	below.set_hovered(false)

	assert_true(above.hovering)
	assert_false(below.hovering, "the card underneath stays put")
	assert_eq(above.z_index, ChallengeCard.HOVER_Z, "lifted over every other card")

	above.set_hovered(false)
	assert_eq(above.z_index, CardGroup.CARD_BASE_Z, "and back to its own layer after")


func test_grabbing_a_hovered_card_keeps_it_on_top() -> void:
	var game := await _make_table()
	var cards := _stack(game)
	var card: ChallengeCard = cards[0]

	card.set_hovered(true)
	card.bring_to_front()

	assert_false(card.hovering, "no longer hovered once grabbed")
	assert_lt(card.z_index, ChallengeCard.HOVER_Z, "on the drag layer, not the hover one")
	assert_gt(card.z_index, CardGroup.CARD_BASE_Z, "but above the table")
	card.set_hovered(false)
	assert_gt(card.z_index, CardGroup.CARD_BASE_Z, "and un-hovering doesn't drop it back")
