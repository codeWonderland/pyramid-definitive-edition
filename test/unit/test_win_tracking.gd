extends GutTest

# Tests marking a run's challenges met or missed: the corner badge cycles the mark
# (a second click undoes a mistake), the table totals the score, and marks are
# saved with the table - while saves from before marks still load unmarked.

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
	pack.folder_path = "user://test_pack_win_tracking"
	var backs: Array[ImageTexture] = [_texture(Color.BLACK)]
	var primaries: Array[ImageTexture] = [_texture(), _texture(), _texture()]
	var secondaries: Array[ImageTexture] = [_texture(), _texture()]
	var curses: Array[ImageTexture] = [_texture()]
	pack.backs = backs
	pack.primaries = primaries
	pack.secondaries = secondaries
	pack.curses = curses
	return pack


func _make_table(games: int = 1) -> Game:
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
	game._card_group_collection.set_physics_process(false)
	return game


func _group(game: Game, index: int = 0) -> CardGroup:
	return game._card_group_collection._card_groups[index]


## The first face-up challenge (not curse) on a table, turned over if need be.
func _challenge(group: CardGroup, secondary: bool = false) -> ChallengeCard:
	for card in group.table_cards():
		if not card.is_curse and card.deck_is_secondary == secondary:
			card.set_face_up(card.front_texture)
			return card
	return null


func test_clicking_the_badge_cycles_the_mark_round() -> void:
	var game := await _make_table()
	var card := _challenge(_group(game))
	watch_signals(card)

	assert_eq(card.result, ChallengeCard.Result.NONE, "starts unmarked")
	card._badge.clicked.emit()
	assert_eq(card.result, ChallengeCard.Result.MET, "met")
	card._badge.clicked.emit()
	assert_eq(card.result, ChallengeCard.Result.MISSED, "missed")
	card._badge.clicked.emit()
	assert_eq(card.result, ChallengeCard.Result.NONE, "a mistake is undone by going round")
	assert_signal_emit_count(card, "result_changed", 3)


func test_the_badge_shows_only_on_a_readable_challenge() -> void:
	var game := await _make_table()
	var card := _challenge(_group(game))
	assert_false(card._badge.visible, "unmarked, it stays out of the way")
	card.set_hovered(true)
	assert_true(card._badge.visible, "until the card is hovered")
	card.set_hovered(false)
	card.cycle_result()
	assert_true(card._badge.visible, "a mark always shows")

	card.set_face_down(card.front_texture)
	assert_false(card._badge.visible, "hidden while face-down")

	var curse := CardGroup.CHALLENGE_CARD.instantiate() as ChallengeCard
	curse.is_curse = true
	add_child_autofree(curse)
	curse.set_face_up(_texture())
	curse.set_hovered(true)
	assert_false(curse._badge.visible, "a curse has nothing to mark")
	curse.cycle_result()
	assert_eq(curse.result, ChallengeCard.Result.NONE, "and can't be marked")


func test_the_score_totals_marks_across_tables() -> void:
	var game := await _make_table(3)
	assert_false(game._score.visible, "nothing marked, no score")

	_challenge(_group(game, 0)).cycle_result()
	_challenge(_group(game, 1)).cycle_result()
	var missed := _challenge(_group(game, 2), true)
	missed.cycle_result()
	missed.cycle_result()

	assert_eq(game._card_group_collection.tally(), {"met": 2, "missed": 1})
	assert_true(game._score.visible, "shown once something is marked")
	assert_string_starts_with(game._score.text, "Score: 2", "a point per met challenge")
	assert_string_contains(game._score.text, "1 missed")


func test_trashing_a_marked_card_takes_its_point_away() -> void:
	var game := await _make_table()
	var card := _challenge(_group(game))
	card.cycle_result()
	assert_eq(game._score.text, "Score: 1")

	_group(game)._on_card_trashed(card)

	assert_eq(game._card_group_collection.tally(), {"met": 0, "missed": 0})
	assert_false(game._score.visible, "back to nothing marked")


func test_marks_are_saved_with_the_table() -> void:
	var game := await _make_table()
	var group := _group(game)
	_challenge(group).cycle_result()
	var missed := _challenge(group, true)
	missed.cycle_result()
	missed.cycle_result()

	var saved := group.generate_card_group_data().table_cards
	var results := {}
	for entry in saved:
		if not entry["curse"]:
			results[entry["secondary"]] = entry["result"]

	assert_eq(results[false], ChallengeCard.Result.MET, "primary saved met")
	assert_eq(results[true], ChallengeCard.Result.MISSED, "secondary saved missed")


func test_restoring_brings_marks_back_and_old_saves_load_unmarked() -> void:
	var game := await _make_table()
	var group := _group(game)
	var before := group.table_cards().size()

	group._restore_card({"entry": 0, "secondary": false, "result": ChallengeCard.Result.MISSED})
	group._restore_card({"entry": 1, "secondary": false})
	group._restore_card({"entry": 0, "secondary": true, "result": 99})

	var restored := group.table_cards().slice(before)
	assert_eq(restored[0].result, ChallengeCard.Result.MISSED, "mark restored")
	assert_eq(restored[1].result, ChallengeCard.Result.NONE, "no mark in an old save")
	assert_eq(restored[2].result, ChallengeCard.Result.NONE, "a nonsense mark is ignored")
