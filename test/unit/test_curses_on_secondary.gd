extends GutTest

# Tests curses moving to the secondary pile (#43): primary draws come up clean,
# curses surface from the secondary pile, packs with no secondaries keep their
# curses on the primary pile, and saves from before the move are migrated.

const PACK_DIR: String = "user://test_pack_curses"
const CARD_GROUP_SCENE: PackedScene = preload("res://source/game/card_group.tscn")


func _texture() -> ImageTexture:
	var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	return ImageTexture.create_from_image(img)


func _textures(count: int) -> Array[ImageTexture]:
	var out: Array[ImageTexture] = []
	for i in range(count):
		out.append(_texture())
	return out


func _pack(primaries: int, secondaries: int, curses: int) -> PackData:
	var pack := PackData.new()
	pack.title = "Test"
	pack.folder_path = "user://test_pack_curses"
	var backs: Array[ImageTexture] = [_texture()]
	pack.backs = backs
	pack.primaries = _textures(primaries)
	pack.secondaries = _textures(secondaries)
	pack.curses = _textures(curses)
	return pack


func _group(pack: PackData) -> CardGroup:
	RunManager.num_games = 1
	var group := CARD_GROUP_SCENE.instantiate() as CardGroup
	add_child_autofree(group)
	await get_tree().process_frame
	group.pack = pack
	await get_tree().process_frame
	return group


func _count_curses(deck: CardDeck) -> int:
	var total := 0
	for entry in deck.to_array():
		if CardDeck.is_curse(entry):
			total += 1
	return total


## Curses still in the pile plus any already dealt onto the table. The opening
## deal can pull a curse out of a pile, so counting the pile alone would depend
## on shuffle luck.
func _curses_accounted_for(group: CardGroup, deck: CardDeck) -> int:
	var total := _count_curses(deck)
	for card in group._table_cards:
		if is_instance_valid(card) and card.is_curse:
			total += 1
	return total


# --- Where curses live ---


func test_curses_go_to_the_secondary_pile() -> void:
	var group := await _group(_pack(4, 3, 2))

	assert_eq(_count_curses(group._primary_deck), 0, "the primary pile is clean")
	assert_eq(
		_curses_accounted_for(group, group._secondary_deck),
		2,
		"both curses ride the secondary pile"
	)


func test_a_pack_without_secondaries_keeps_curses_on_the_primary_pile() -> void:
	# Four real packs ship curses and no secondaries; they must not lose them.
	var group := await _group(_pack(4, 0, 2))

	assert_eq(
		_curses_accounted_for(group, group._primary_deck),
		2,
		"with no secondary pile to ride, curses stay with the primaries"
	)


func test_a_pack_with_no_curses_is_unaffected() -> void:
	var group := await _group(_pack(4, 3, 0))

	assert_eq(_curses_accounted_for(group, group._primary_deck), 0, "no curses anywhere")
	assert_eq(_curses_accounted_for(group, group._secondary_deck), 0, "no curses anywhere")


# --- Drawing ---


func test_drawing_a_primary_never_surfaces_a_curse() -> void:
	var group := await _group(_pack(4, 3, 2))

	for _draw in range(4):
		var result := group._primary_deck.draw_primary()
		if result.is_empty():
			break
		assert_false(result.has("curse"), "a primary draw is clean")


func test_drawing_a_secondary_can_surface_a_curse() -> void:
	var group := await _group(_pack(4, 3, 2))

	# Stack the pile so the card under the top is a curse.
	group._secondary_deck.cards = [
		CardDeck.encode_primary(0), CardDeck.encode_curse(0), CardDeck.encode_primary(1)
	]

	var result := group._secondary_deck.draw_secondary()

	assert_true(result.has("secondary"), "a secondary came off the pile")
	assert_true(result.has("curse"), "and the curse under it surfaced")


func test_secondary_draw_leaves_a_drawable_card_on_top() -> void:
	var deck := CardDeck.new()
	deck.cards = [
		CardDeck.encode_primary(0),
		CardDeck.encode_curse(0),
		CardDeck.encode_curse(1),
		CardDeck.encode_primary(1),
	]

	deck.draw_secondary()

	assert_false(CardDeck.is_curse(deck.peek()), "two curses never surface back to back")


func test_drawing_a_secondary_card_puts_a_curse_on_the_table() -> void:
	var group := await _group(_pack(4, 3, 2))
	group._secondary_deck.cards = [
		CardDeck.encode_primary(0), CardDeck.encode_curse(0), CardDeck.encode_primary(1)
	]

	group._draw_secondary_card(false, false)
	await get_tree().process_frame

	assert_not_null(group._curse_card, "the curse flew to the curse slot")


# --- Deck helpers ---


func test_extract_curses_takes_only_curses() -> void:
	var deck := CardDeck.new()
	deck.cards = [
		CardDeck.encode_primary(0),
		CardDeck.encode_curse(0),
		CardDeck.encode_primary(1),
		CardDeck.encode_curse(1),
	]

	var curses := deck.extract_curses()

	assert_eq(curses.size(), 2, "both curses came out")
	assert_eq(deck.size(), 2, "the ordinary cards stayed")
	assert_eq(_count_curses(deck), 0, "and no curse was left behind")


func test_add_shuffled_keeps_a_drawable_card_on_top() -> void:
	var deck := CardDeck.new()
	deck.cards = [CardDeck.encode_primary(0), CardDeck.encode_primary(1)]

	deck.add_shuffled([CardDeck.encode_curse(0), CardDeck.encode_curse(1)] as Array[int])

	assert_eq(deck.size(), 4, "everything was added")
	assert_false(CardDeck.is_curse(deck.peek()), "the top is still drawable")


func test_add_shuffled_with_nothing_is_a_no_op() -> void:
	var deck := CardDeck.new()
	deck.cards = [CardDeck.encode_primary(0)]

	deck.add_shuffled([] as Array[int])

	assert_eq(deck.size(), 1, "nothing changed")


# --- Migrating older saves ---


func _write_pack_to_disk(secondaries: Array) -> void:
	DirAccess.make_dir_recursive_absolute(PACK_DIR)
	var stems := ["b1", "p1", "p2", "p3", "c1"]
	stems.append_array(secondaries)
	for stem in stems:
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


func _legacy_save() -> CardGroupData:
	# How a save looked when curses rode the primary deck.
	var data := CardGroupData.new()
	data.pack_path = PACK_DIR
	data.primary_deck = [
		CardDeck.encode_primary(0), CardDeck.encode_curse(0), CardDeck.encode_primary(1)
	]
	data.secondary_deck = [CardDeck.encode_primary(0)]
	data.table_cards = [{"entry": CardDeck.encode_primary(2), "secondary": false, "curse": false}]
	return data


func test_a_legacy_save_moves_its_curses_to_the_secondary_pile() -> void:
	_write_pack_to_disk(["s1", "s2"])
	RunManager.num_games = 1

	var group := CARD_GROUP_SCENE.instantiate() as CardGroup
	add_child_autofree(group)
	await get_tree().process_frame
	group.load_from_card_group_data(_legacy_save())
	await get_tree().process_frame

	assert_eq(_count_curses(group._primary_deck), 0, "the curse left the primary pile")
	assert_eq(_count_curses(group._secondary_deck), 1, "and joined the secondary pile")

	_remove_pack_from_disk()


func test_a_legacy_save_for_a_pack_without_secondaries_is_left_alone() -> void:
	_write_pack_to_disk([])
	RunManager.num_games = 1

	var group := CARD_GROUP_SCENE.instantiate() as CardGroup
	add_child_autofree(group)
	await get_tree().process_frame
	group.load_from_card_group_data(_legacy_save())
	await get_tree().process_frame

	assert_eq(
		_count_curses(group._primary_deck),
		1,
		"with nowhere to move it, the curse stays on the primary pile"
	)

	_remove_pack_from_disk()
