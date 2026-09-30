extends GutTest

# Tests flipping one card at a time: F turns over just the card under the cursor,
# while the Flip All button turns the whole table.

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


func _make_table() -> Game:
	RunManager.clear()
	RunManager.num_games = 3
	var packs: Array[PackData] = [_make_pack(), _make_pack(), _make_pack()]
	RunManager.selected_packs = packs

	var game := GAME_SCENE.instantiate() as Game
	add_child_autofree(game)
	await get_tree().process_frame
	await get_tree().process_frame
	return game


func _all_table_cards(game: Game) -> Array:
	var cards: Array = []
	for group in game._card_group_collection._card_groups:
		if group.pack != null:
			cards.append_array(group._table_cards)
	return cards


func test_f_flips_only_the_card_under_the_cursor() -> void:
	var game := await _make_table()
	var cards := _all_table_cards(game)
	var target: ChallengeCard = cards[0]

	assert_true(game.flip_card_at(target.get_global_rect().get_center()), "a card was flipped")
	await get_tree().create_timer(ChallengeCard.FLIP_TIME + 0.1).timeout

	assert_false(target.face_down, "the card under the cursor turned over")
	var still_hidden := 0
	for card in cards:
		if card.face_down:
			still_hidden += 1
	assert_eq(still_hidden, cards.size() - 1, "and only that one")


func test_f_away_from_every_card_flips_nothing() -> void:
	var game := await _make_table()

	assert_false(game.flip_card_at(Vector2(-5000, -5000)), "nothing under the cursor")
	for card in _all_table_cards(game):
		assert_true(card.face_down, "the table stays hidden")


func test_f_on_a_face_up_card_turns_it_back_down() -> void:
	var game := await _make_table()
	var target: ChallengeCard = _all_table_cards(game)[0]
	var point := target.get_global_rect().get_center()
	game.flip_card_at(point)
	await get_tree().create_timer(ChallengeCard.FLIP_TIME + 0.1).timeout
	assert_false(target.face_down, "first press reveals it")

	assert_true(game.flip_card_at(point), "a second press turns it")
	await get_tree().create_timer(ChallengeCard.FLIP_TIME + 0.1).timeout

	assert_true(target.face_down, "back face-down")
	assert_eq(target.texture, target.back_texture, "showing its back again")


func test_turning_a_card_down_brings_flip_all_back() -> void:
	var game := await _make_table()
	game._flip_all_cards()
	await get_tree().create_timer(ChallengeCard.FLIP_TIME + 0.1).timeout
	assert_false(game._flip_cards_button.visible, "nothing hidden, no button")

	var target: ChallengeCard = _all_table_cards(game)[0]
	game.flip_card_at(target.get_global_rect().get_center())

	assert_true(game._flip_cards_button.visible, "a hidden card means Flip All is useful again")


func test_a_card_with_no_back_image_stays_face_up() -> void:
	var game := await _make_table()
	var target: ChallengeCard = _all_table_cards(game)[0]
	target.reveal()
	await get_tree().create_timer(ChallengeCard.FLIP_TIME + 0.1).timeout
	target.back_texture = null

	assert_false(target.conceal(), "nothing to show in place of its face")
	assert_false(target.face_down, "so it stays face-up")


func test_the_f_key_goes_through_the_cursor_path() -> void:
	# Pressed away from every card, F must not fall back to flipping them all.
	var game := await _make_table()
	var event := InputEventAction.new()
	event.action = "FlipCards"
	event.pressed = true

	game._unhandled_input(event)
	await get_tree().create_timer(ChallengeCard.FLIP_TIME + 0.1).timeout

	var hidden := 0
	for card in _all_table_cards(game):
		if card.face_down:
			hidden += 1
	assert_gt(hidden, 0, "F no longer turns the whole table over")


func test_card_at_picks_the_card_on_top() -> void:
	var game := await _make_table()
	var cards := _all_table_cards(game)
	var under: ChallengeCard = cards[0]
	var over: ChallengeCard = cards[1]
	over.global_position = under.global_position
	over.z_index = under.z_index + 10

	var point := under.get_global_rect().get_center()
	assert_eq(game._card_group_collection.card_at(point), over, "the higher card wins")


func test_flipping_the_last_hidden_card_by_hand_hides_the_button() -> void:
	var game := await _make_table()
	# The headless test window is tiny, so dealt cards pile up; spread them out
	# so each one can be pointed at on its own, as on a real table.
	var cards := _all_table_cards(game)
	for i in cards.size():
		cards[i].global_position = Vector2(i * 1000, 0)
	for card in cards:
		game.flip_card_at(card.get_global_rect().get_center())
	await get_tree().create_timer(ChallengeCard.FLIP_TIME + 0.1).timeout

	assert_false(game._flip_cards_button.visible, "nothing left for Flip All to do")
