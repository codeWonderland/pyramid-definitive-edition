extends GutTest

# Tests the card inspect overlay (#39): right-clicking a card on the table opens
# it large and centred, and clicking or Escape puts it away. A face-down card
# inspects as its back, so the overlay is never a way to peek.

const GAME_SCENE: PackedScene = preload("res://source/game/game.tscn")
const CHALLENGE_CARD: PackedScene = preload("res://source/game/challenge_card.tscn")
const INSPECTOR: PackedScene = preload("res://source/game/card_inspector.tscn")


func _texture(fill: Color = Color.WHITE) -> ImageTexture:
	var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(fill)
	return ImageTexture.create_from_image(img)


func _make_pack() -> PackData:
	var pack := PackData.new()
	pack.title = "Test"
	pack.folder_path = "user://test_pack_inspect"
	var backs: Array[ImageTexture] = [_texture(Color.BLACK)]
	var primaries: Array[ImageTexture] = [_texture(Color.RED), _texture(Color.GREEN)]
	pack.backs = backs
	pack.primaries = primaries
	return pack


func after_each() -> void:
	RunManager.popup_open = false


func _make_table() -> Game:
	RunManager.clear()
	RunManager.num_games = 1
	var packs: Array[PackData] = [_make_pack()]
	RunManager.selected_packs = packs

	var game := GAME_SCENE.instantiate() as Game
	add_child_autofree(game)
	await get_tree().process_frame
	await get_tree().process_frame
	return game


func _right_click() -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_RIGHT
	event.pressed = true
	return event


func _first_card(game: Game) -> ChallengeCard:
	for group in game._card_group_collection._card_groups:
		if group.pack != null and group._table_cards.size() > 0:
			return group._table_cards[0]
	return null


# --- Requesting ---


func test_right_clicking_a_card_asks_for_an_inspect() -> void:
	var card := CHALLENGE_CARD.instantiate() as ChallengeCard
	add_child_autofree(card)
	await get_tree().process_frame
	card.set_face_up(_texture(Color.RED))

	watch_signals(RunManager)
	card._on_gui_input(_right_click())

	assert_signal_emitted(RunManager, "card_inspect_requested")


func test_right_click_is_ignored_while_a_popup_is_open() -> void:
	var card := CHALLENGE_CARD.instantiate() as ChallengeCard
	add_child_autofree(card)
	await get_tree().process_frame
	card.set_face_up(_texture(Color.RED))
	RunManager.popup_open = true

	watch_signals(RunManager)
	card._on_gui_input(_right_click())

	assert_signal_not_emitted(RunManager, "card_inspect_requested")


func test_right_click_is_ignored_mid_drag() -> void:
	var card := CHALLENGE_CARD.instantiate() as ChallengeCard
	add_child_autofree(card)
	await get_tree().process_frame
	card.set_face_up(_texture(Color.RED))
	card._dragging = true

	watch_signals(RunManager)
	card._on_gui_input(_right_click())

	assert_signal_not_emitted(RunManager, "card_inspect_requested")


func test_a_face_down_card_inspects_as_its_back() -> void:
	var card := CHALLENGE_CARD.instantiate() as ChallengeCard
	add_child_autofree(card)
	await get_tree().process_frame
	var back := _texture(Color.BLACK)
	card.back_texture = back
	card.set_face_down(_texture(Color.RED))

	var seen: Array = []
	RunManager.card_inspect_requested.connect(func(tex): seen.append(tex))
	card._on_gui_input(_right_click())

	assert_eq(seen.size(), 1, "the request went out")
	assert_eq(seen[0], back, "it carries the back, so the overlay is no way to peek")


# --- The overlay ---


func test_show_card_displays_that_texture() -> void:
	var inspector := INSPECTOR.instantiate() as CardInspector
	add_child_autofree(inspector)
	await get_tree().process_frame
	var front := _texture(Color.RED)

	inspector.show_card(front)

	assert_true(inspector.visible, "the overlay is showing")
	assert_eq(inspector._card_image.texture, front, "showing the card it was handed")


func test_clicking_the_overlay_dismisses_it() -> void:
	var inspector := INSPECTOR.instantiate() as CardInspector
	add_child_autofree(inspector)
	await get_tree().process_frame
	inspector.show_card(_texture(Color.RED))

	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	inspector._on_clicked(click)

	assert_false(inspector.visible, "clicking puts the card away")


func test_dismissing_emits_closing() -> void:
	var inspector := INSPECTOR.instantiate() as CardInspector
	add_child_autofree(inspector)
	await get_tree().process_frame
	inspector.show_card(_texture(Color.RED))

	watch_signals(inspector)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	inspector._on_clicked(click)

	assert_signal_emitted(inspector, "closing")


# --- Wired into the table ---


func test_table_opens_the_inspector_on_request() -> void:
	var game := await _make_table()
	var front := _texture(Color.RED)

	RunManager.request_card_inspect(front)
	await get_tree().process_frame

	assert_true(game._card_inspector.visible, "the table opened the overlay")
	assert_eq(game._card_inspector._card_image.texture, front, "with the requested card")
	assert_true(RunManager.popup_open, "and marked a popup open so cards stop responding")


func test_closing_the_inspector_releases_the_popup_flag() -> void:
	var game := await _make_table()
	RunManager.request_card_inspect(_texture(Color.RED))
	await get_tree().process_frame

	game._card_inspector._close()
	await get_tree().process_frame

	assert_false(game._card_inspector.visible, "overlay hidden")
	assert_false(RunManager.popup_open, "and the table is interactive again")


func test_right_clicking_a_table_card_opens_the_overlay() -> void:
	var game := await _make_table()
	var card := _first_card(game)
	assert_not_null(card, "the table dealt a card to right-click")

	card._on_gui_input(_right_click())
	await get_tree().process_frame

	assert_true(game._card_inspector.visible, "right-clicking a dealt card opens the overlay")
