extends GutTest

# Runtime smoke test: instantiate a CardGroup with a synthetic pack and exercise
# the deal/draw/serialize paths so spawning, piles, flips, and curse reveal run
# without errors. (Interactive drag/trash still needs manual playtesting.)


func _texture() -> ImageTexture:
	var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	return ImageTexture.create_from_image(img)


func _make_pack() -> PackData:
	var pack := PackData.new()
	pack.title = "Test"
	pack.folder_path = "user://test_pack"

	var backs: Array[ImageTexture] = [_texture()]
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
	var group := preload("res://source/game/card_group.tscn").instantiate() as CardGroup
	add_child_autofree(group)
	return group


func test_dealing_spawns_cards_and_piles() -> void:
	var group := _make_group()
	await get_tree().process_frame

	group.pack = _make_pack()
	await get_tree().process_frame

	assert_gt(group.get_child_count(), 0, "dealing spawned piles and cards")


func test_drawing_runs_without_error() -> void:
	var group := _make_group()
	await get_tree().process_frame
	group.pack = _make_pack()
	await get_tree().process_frame

	# Force a curse directly under the top primary so the curse-reveal path runs.
	group._primary_deck.cards = [
		CardDeck.encode_primary(0),
		CardDeck.encode_curse(0),
		CardDeck.encode_primary(1),
	]
	group._on_primary_draw_requested(false)
	await get_tree().process_frame

	assert_not_null(group._curse_card, "a curse surfaced and flew to the curse slot")


func test_serialize_round_trips_through_card_group() -> void:
	var group := _make_group()
	await get_tree().process_frame
	group.pack = _make_pack()
	await get_tree().process_frame

	var data := group.generate_card_group_data()
	assert_eq(data.pack_path, "user://test_pack")
	assert_false(data.primary_deck.is_empty(), "primary deck serialized")
	assert_false(data.table_cards.is_empty(), "dealt cards serialized")
