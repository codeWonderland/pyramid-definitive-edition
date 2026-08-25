extends GutTest

# Tests face-down dealing and the flip-all-at-once reveal (#40): the opening hand
# is dealt face-down, one control turns the whole table over, and the face-down
# state survives a save/load.

const PACK_DIR: String = "user://test_pack_flipping"
const CARD_GROUP_SCENE: PackedScene = preload("res://source/game/card_group.tscn")
const CHALLENGE_CARD: PackedScene = preload("res://source/game/challenge_card.tscn")
const GAME_SCENE: PackedScene = preload("res://source/game/game.tscn")

var _saved_adjectives: Array = []
var _saved_nouns: Array = []


func after_each() -> void:
	if not _saved_adjectives.is_empty() or not _saved_nouns.is_empty():
		WordBankLoader.adjectives = _saved_adjectives
		WordBankLoader.nouns = _saved_nouns
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


func _make_group() -> CardGroup:
	RunManager.num_games = 1
	var group := CARD_GROUP_SCENE.instantiate() as CardGroup
	add_child_autofree(group)
	await get_tree().process_frame
	group.pack = _make_pack()
	await get_tree().process_frame
	return group


func _make_card() -> ChallengeCard:
	var card := CHALLENGE_CARD.instantiate() as ChallengeCard
	add_child_autofree(card)
	await get_tree().process_frame
	return card


# --- ChallengeCard ---


func test_set_face_down_shows_the_back_and_remembers_the_face() -> void:
	var card := await _make_card()
	var back := _texture(Color.BLACK)
	var front := _texture(Color.RED)
	card.back_texture = back

	card.set_face_down(front)

	assert_true(card.face_down, "the card reports itself face-down")
	assert_eq(card.texture, back, "it is showing its back")
	assert_eq(card.front_texture, front, "and remembers its face for later")


func test_set_face_down_without_a_back_falls_back_to_the_face() -> void:
	var card := await _make_card()
	var front := _texture(Color.RED)
	card.back_texture = null

	card.set_face_down(front)

	assert_eq(card.texture, front, "a pack with no back image never leaves a blank card")


func test_set_face_up_shows_the_face() -> void:
	var card := await _make_card()
	var front := _texture(Color.RED)

	card.set_face_up(front)

	assert_false(card.face_down, "the card is face-up")
	assert_eq(card.texture, front, "showing its face")


func test_reveal_flips_a_face_down_card() -> void:
	var card := await _make_card()
	card.back_texture = _texture(Color.BLACK)
	var front := _texture(Color.RED)
	card.set_face_down(front)

	card.reveal()
	await get_tree().create_timer(ChallengeCard.FLIP_TIME + 0.1).timeout

	assert_false(card.face_down, "the card is now face-up")
	assert_eq(card.texture, front, "and shows its face once the flip finishes")


func test_reveal_is_a_no_op_on_a_face_up_card() -> void:
	var card := await _make_card()
	var front := _texture(Color.RED)
	card.set_face_up(front)

	card.reveal()

	assert_false(card.face_down, "still face-up")
	assert_eq(card.texture, front, "and its texture was left alone")


# --- Dealing ---


func test_opening_hand_is_dealt_face_down() -> void:
	var group := await _make_group()

	assert_gt(group._table_cards.size(), 0, "the opening hand was dealt")
	for card in group._table_cards:
		assert_true(card.face_down, "every dealt card starts face-down")


func test_a_curse_in_the_opening_hand_is_also_hidden() -> void:
	RunManager.num_games = 1
	var group := CARD_GROUP_SCENE.instantiate() as CardGroup
	add_child_autofree(group)
	await get_tree().process_frame

	var pack := _make_pack()
	group.pack = pack
	await get_tree().process_frame

	# Deal again with a curse sitting directly under the top primary.
	group._clear_table()
	group._primary_deck.cards = [
		CardDeck.encode_primary(0), CardDeck.encode_curse(0), CardDeck.encode_primary(1)
	]
	group._build_piles()
	group._draw_primary_card(false, false, true)
	await get_tree().process_frame

	assert_not_null(group._curse_card, "a curse surfaced")
	assert_true(group._curse_card.face_down, "and it stays hidden with the rest of the hand")


func test_drawing_from_a_pile_during_play_deals_face_up() -> void:
	var group := await _make_group()
	group.reveal_all()
	await get_tree().create_timer(ChallengeCard.FLIP_TIME + 0.1).timeout

	group._on_primary_draw_requested(false)
	await get_tree().process_frame

	var newest: ChallengeCard = group._table_cards[group._table_cards.size() - 1]
	assert_false(newest.face_down, "a card the player chose to draw arrives face-up")


# --- Revealing ---


func test_reveal_all_turns_the_table_over() -> void:
	var group := await _make_group()
	var dealt := group._table_cards.size()

	var revealed := group.reveal_all()
	await get_tree().create_timer(ChallengeCard.FLIP_TIME + 0.1).timeout

	assert_eq(revealed, dealt, "every dealt card was flipped")
	for card in group._table_cards:
		assert_false(card.face_down, "nothing is left face-down")


func test_reveal_all_again_flips_nothing() -> void:
	var group := await _make_group()
	group.reveal_all()
	await get_tree().create_timer(ChallengeCard.FLIP_TIME + 0.1).timeout

	assert_eq(group.reveal_all(), 0, "a second reveal has nothing to do")


func test_has_face_down_cards_tracks_the_table() -> void:
	var group := await _make_group()
	assert_true(group.has_face_down_cards(), "the fresh hand is hidden")

	group.reveal_all()
	await get_tree().create_timer(ChallengeCard.FLIP_TIME + 0.1).timeout

	assert_false(group.has_face_down_cards(), "nothing hidden once turned over")


# --- Persistence ---


func _write_pack_to_disk() -> void:
	DirAccess.make_dir_recursive_absolute(PACK_DIR)
	for stem in ["b1", "p1", "p2", "p3", "s1", "s2", "c1"]:
		var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
		img.fill(Color.WHITE)
		img.save_png("%s/%s.png" % [PACK_DIR, stem])


func _remove_pack_from_disk() -> void:
	var dir := DirAccess.open(PACK_DIR)
	if dir == null:
		return
	for file_name in dir.get_files():
		dir.remove(file_name)
	DirAccess.remove_absolute(PACK_DIR)


func _reload(data: CardGroupData) -> CardGroup:
	var restored := CARD_GROUP_SCENE.instantiate() as CardGroup
	add_child_autofree(restored)
	await get_tree().process_frame
	restored.load_from_card_group_data(data)
	await get_tree().process_frame
	return restored


func test_face_down_survives_save_and_load() -> void:
	_write_pack_to_disk()
	RunManager.num_games = 1

	var group := CARD_GROUP_SCENE.instantiate() as CardGroup
	add_child_autofree(group)
	await get_tree().process_frame
	group.pack = PackDataLoader.load_pack_from_path(PACK_DIR)
	await get_tree().process_frame

	var data := group.generate_card_group_data()
	for saved in data.table_cards:
		assert_true(saved["face_down"], "the saved table records the cards as hidden")

	var restored := await _reload(data)
	for card in restored._table_cards:
		assert_true(card.face_down, "a saved-then-loaded hand is still hidden")

	_remove_pack_from_disk()


func test_revealed_table_saves_and_loads_face_up() -> void:
	_write_pack_to_disk()
	RunManager.num_games = 1

	var group := CARD_GROUP_SCENE.instantiate() as CardGroup
	add_child_autofree(group)
	await get_tree().process_frame
	group.pack = PackDataLoader.load_pack_from_path(PACK_DIR)
	await get_tree().process_frame
	group.reveal_all()
	await get_tree().create_timer(ChallengeCard.FLIP_TIME + 0.1).timeout

	var restored := await _reload(group.generate_card_group_data())
	for card in restored._table_cards:
		assert_false(card.face_down, "a table turned over before saving loads face-up")

	_remove_pack_from_disk()


func test_saves_predating_face_down_load_face_up() -> void:
	_write_pack_to_disk()
	RunManager.num_games = 1

	var group := CARD_GROUP_SCENE.instantiate() as CardGroup
	add_child_autofree(group)
	await get_tree().process_frame
	group.pack = PackDataLoader.load_pack_from_path(PACK_DIR)
	await get_tree().process_frame

	# Strip the flag the way an older save would have stored the table.
	var data := group.generate_card_group_data()
	var legacy: Array[Dictionary] = []
	for saved in data.table_cards:
		var entry := saved.duplicate()
		entry.erase("face_down")
		legacy.append(entry)
	data.table_cards = legacy

	var restored := await _reload(data)

	assert_gt(restored._table_cards.size(), 0, "the legacy table restored")
	for card in restored._table_cards:
		assert_false(card.face_down, "cards from a save with no flag come back face-up")

	_remove_pack_from_disk()


# --- Across the whole table ---


func _make_table() -> Game:
	# The table rolls a run name on load, and WordBankLoader is empty here
	# because no mod data was loaded, so stand in for it.
	_saved_adjectives = WordBankLoader.adjectives
	_saved_nouns = WordBankLoader.nouns
	WordBankLoader.adjectives = ["Test"]
	WordBankLoader.nouns = ["Testing"]

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


func test_the_whole_table_is_dealt_face_down() -> void:
	var game := await _make_table()

	var cards := _all_table_cards(game)
	assert_gt(cards.size(), 0, "the table dealt cards")
	for card in cards:
		assert_true(card.face_down, "every group's cards start hidden")


func test_flip_button_turns_over_every_group() -> void:
	var game := await _make_table()

	game._flip_all_cards()
	await get_tree().create_timer(ChallengeCard.FLIP_TIME + 0.1).timeout

	for card in _all_table_cards(game):
		assert_false(card.face_down, "one press reveals every group at once")


func test_flip_button_hides_once_nothing_is_left_to_flip() -> void:
	var game := await _make_table()
	assert_true(game._flip_cards_button.visible, "the control is offered while cards are hidden")

	game._flip_all_cards()
	await get_tree().create_timer(ChallengeCard.FLIP_TIME + 0.1).timeout

	assert_false(game._flip_cards_button.visible, "and goes away once the table is face-up")


func test_hotkey_reveals_the_table() -> void:
	var game := await _make_table()

	var event := InputEventAction.new()
	event.action = "FlipCards"
	event.pressed = true
	game._unhandled_input(event)
	await get_tree().create_timer(ChallengeCard.FLIP_TIME + 0.1).timeout

	for card in _all_table_cards(game):
		assert_false(card.face_down, "the FlipCards action reveals the table too")


func test_flip_is_ignored_while_a_popup_is_open() -> void:
	var game := await _make_table()
	RunManager.popup_open = true

	game._flip_all_cards()
	await get_tree().process_frame

	for card in _all_table_cards(game):
		assert_true(card.face_down, "the table stays hidden behind an open popup")

	RunManager.popup_open = false
