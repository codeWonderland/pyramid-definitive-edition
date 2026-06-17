extends GutTest

# Tests for the draw-pile logic in source/game/card_deck.gd, especially the
# "next drawable card is always a primary / only one curse surfaces at a time"
# invariant.


func _count_curses(deck: CardDeck) -> int:
	var n := 0
	for entry in deck.cards:
		if CardDeck.is_curse(entry):
			n += 1
	return n


func test_encoding_round_trips() -> void:
	assert_false(CardDeck.is_curse(CardDeck.encode_primary(0)))
	assert_true(CardDeck.is_curse(CardDeck.encode_curse(0)))
	assert_eq(CardDeck.decode_index(CardDeck.encode_primary(4)), 4)
	assert_eq(CardDeck.decode_index(CardDeck.encode_curse(3)), 3)


func test_build_primary_holds_every_card() -> void:
	var deck := CardDeck.new()
	deck.build_primary(10, 4)

	assert_eq(deck.size(), 14, "all primaries and curses are in the pile")
	assert_eq(_count_curses(deck), 4, "all curses present")


func test_build_primary_top_is_primary() -> void:
	# Many curses, few primaries: the top must still come up a primary.
	for _i in range(50):
		var deck := CardDeck.new()
		deck.build_primary(2, 20)
		assert_false(CardDeck.is_curse(deck.peek()), "top of a fresh pile is never a curse")


func test_deal_initial_primary_returns_primary_and_keeps_top_primary() -> void:
	var deck := CardDeck.new()
	deck.build_primary(5, 5)

	var active := deck.deal_initial_primary()
	assert_false(CardDeck.is_curse(active), "dealt card is a primary")
	if deck.has_primary():
		assert_false(CardDeck.is_curse(deck.peek()), "next drawable stays a primary")


func test_draw_primary_surfaces_at_most_one_curse() -> void:
	# Force a known order: primary, curse, curse, curse, primary.
	var deck := CardDeck.new()
	deck.cards = [
		CardDeck.encode_primary(0),
		CardDeck.encode_curse(0),
		CardDeck.encode_curse(1),
		CardDeck.encode_curse(2),
		CardDeck.encode_primary(1),
	]

	var result := deck.draw_primary()

	assert_eq(result.get("primary"), CardDeck.encode_primary(0), "drew the top primary")
	assert_true(result.has("curse"), "the immediate next curse surfaces")
	assert_true(CardDeck.is_curse(result["curse"]))
	assert_false(CardDeck.is_curse(deck.peek()), "the extra curses were recycled; top is a primary")
	assert_eq(_count_curses(deck), 2, "the two un-surfaced curses are still in the pile")


func test_draw_primary_without_curse_underneath() -> void:
	var deck := CardDeck.new()
	deck.cards = [CardDeck.encode_primary(0), CardDeck.encode_primary(1)]

	var result := deck.draw_primary()

	assert_eq(result.get("primary"), CardDeck.encode_primary(0))
	assert_false(result.has("curse"), "no curse revealed when the next card is a primary")


func test_draw_primary_when_only_curses_remain() -> void:
	var deck := CardDeck.new()
	deck.cards = [CardDeck.encode_curse(0), CardDeck.encode_curse(1)]

	assert_eq(deck.draw_primary(), {}, "cannot draw a primary when none remain")


func test_trash_to_bottom() -> void:
	var deck := CardDeck.new()
	deck.cards = [CardDeck.encode_primary(0), CardDeck.encode_primary(1)]

	deck.trash_to_bottom(CardDeck.encode_primary(7))

	assert_eq(deck.cards.back(), CardDeck.encode_primary(7), "trashed card lands on the bottom")
	assert_eq(deck.size(), 3)


func test_serialize_round_trip() -> void:
	var deck := CardDeck.new()
	deck.build_primary(6, 3)
	var snapshot := deck.to_array()

	var restored := CardDeck.new()
	restored.from_array(snapshot)

	assert_eq(restored.cards, snapshot, "restored pile matches the saved order")
