extends GutTest

# Tests which back each deck shows: a pack can have up to three - the default
# (also the primary deck's), the secondary deck's and the curses' - and a deck
# without its own falls back to the default.


func _texture() -> ImageTexture:
	return ImageTexture.create_from_image(Image.create(4, 4, false, Image.FORMAT_RGBA8))


func _pack(back_count: int) -> PackData:
	var pack := PackData.new()
	for i in back_count:
		pack.backs.append(_texture())
	return pack


func test_one_back_serves_every_deck() -> void:
	var pack := _pack(1)

	for deck in [PackData.Deck.PRIMARY, PackData.Deck.SECONDARY, PackData.Deck.CURSE]:
		assert_eq(pack.back_for(deck), pack.backs[0])


func test_a_second_back_is_the_secondary_decks() -> void:
	var pack := _pack(2)

	assert_eq(pack.back_for(PackData.Deck.PRIMARY), pack.backs[0])
	assert_eq(pack.back_for(PackData.Deck.SECONDARY), pack.backs[1])
	assert_eq(pack.back_for(PackData.Deck.CURSE), pack.backs[0], "curses fall back to the default")


func test_a_third_back_is_the_curses() -> void:
	var pack := _pack(3)

	assert_eq(pack.back_for(PackData.Deck.SECONDARY), pack.backs[1])
	assert_eq(pack.back_for(PackData.Deck.CURSE), pack.backs[2])


func test_a_pack_without_backs_has_none() -> void:
	assert_null(_pack(0).back_for(PackData.Deck.PRIMARY))
