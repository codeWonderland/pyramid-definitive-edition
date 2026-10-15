extends GutTest

# Tests the "how many games" screen: each choice shows that many cards - the
# drafted games' backs - with a caption, rather than a bare number.

const NUM_GAMES: PackedScene = preload("res://source/menus/num_games.tscn")


func _pack(color: Color) -> PackData:
	var pack := PackData.new()
	var image := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	image.fill(color)
	pack.backs.append(ImageTexture.create_from_image(image))
	return pack


func _screen(packs: Array[PackData]) -> NumGames:
	RunManager.clear()
	RunManager.selected_packs = packs
	var screen := NUM_GAMES.instantiate() as NumGames
	add_child_autofree(screen)
	await get_tree().process_frame
	return screen


func after_each() -> void:
	RunManager.clear()


func test_each_choice_shows_that_many_cards_with_a_caption() -> void:
	var screen := await _screen([_pack(Color.RED), _pack(Color.BLUE)] as Array[PackData])

	for pair in [
		[screen._one_button, 1, "1 game"],
		[screen._three_button, 3, "3 games"],
		[screen._five_button, 5, "5 games"]
	]:
		var choice: GameCountChoice = pair[0]
		assert_eq(choice.count, pair[1])
		assert_eq(choice._cards.size(), pair[1], "%d cards" % pair[1])
		assert_eq(choice._caption.text, pair[2])


func test_the_cards_are_the_drafted_games_backs() -> void:
	var red := _pack(Color.RED)
	var blue := _pack(Color.BLUE)
	var screen := await _screen([red, blue] as Array[PackData])

	var shown: Array = []
	for card in screen._five_button._cards:
		shown.append(card.texture)
	assert_eq(
		shown,
		[red.backs[0], blue.backs[0], red.backs[0], blue.backs[0], red.backs[0]],
		"dealt round the drafted games"
	)


func test_without_drafted_games_the_cards_are_plain() -> void:
	var screen := await _screen([] as Array[PackData])

	assert_eq(screen._one_button._cards[0].texture, NumGames.BLANK_CARD)


func test_focus_fans_a_choice_out() -> void:
	var screen := await _screen([_pack(Color.RED)] as Array[PackData])
	var choice := screen._five_button
	var resting: float = choice._cards[0].rotation_degrees

	choice.grab_focus()
	await get_tree().create_timer(GameCountChoice.FAN_TIME + 0.1).timeout

	assert_lt(choice._cards[0].rotation_degrees, resting, "the outer card turns further")
	assert_eq(choice._caption.modulate, GameCountChoice.HIGHLIGHT, "and the caption lights up")
