extends GutTest

# Tests the run name the table rolls on load. WordBankLoader is warn-and-continue
# by design, so a missing or malformed word_bank.json legitimately leaves it with
# no words; rolling a name from that used to error with "Can't take value from
# empty array" on every load and reroll.

const GAME_SCENE: PackedScene = preload("res://source/game/game.tscn")

var _saved_adjectives: Array = []
var _saved_nouns: Array = []


func _texture() -> ImageTexture:
	var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	return ImageTexture.create_from_image(img)


func _make_pack() -> PackData:
	var pack := PackData.new()
	pack.title = "Test"
	pack.folder_path = "user://test_pack_run_name"
	var backs: Array[ImageTexture] = [_texture()]
	var primaries: Array[ImageTexture] = [_texture(), _texture()]
	pack.backs = backs
	pack.primaries = primaries
	return pack


func before_each() -> void:
	_saved_adjectives = WordBankLoader.adjectives
	_saved_nouns = WordBankLoader.nouns


func after_each() -> void:
	WordBankLoader.adjectives = _saved_adjectives
	WordBankLoader.nouns = _saved_nouns
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


func test_empty_word_bank_falls_back_instead_of_erroring() -> void:
	WordBankLoader.adjectives = []
	WordBankLoader.nouns = []

	var game := await _make_table()

	assert_eq(game._title.text, Game.FALLBACK_TITLE, "an empty word bank yields the plain name")


func test_missing_nouns_falls_back() -> void:
	WordBankLoader.adjectives = ["Mighty"]
	WordBankLoader.nouns = []

	var game := await _make_table()

	assert_eq(game._title.text, Game.FALLBACK_TITLE, "half a word bank is not half a name")


func test_missing_adjectives_falls_back() -> void:
	WordBankLoader.adjectives = []
	WordBankLoader.nouns = ["Doom"]

	var game := await _make_table()

	assert_eq(game._title.text, Game.FALLBACK_TITLE, "the other half is no better")


func test_a_populated_word_bank_still_rolls_a_name() -> void:
	WordBankLoader.adjectives = ["Mighty"]
	WordBankLoader.nouns = ["Doom"]

	var game := await _make_table()

	assert_eq(
		game._title.text, "The Mighty Pyramid of Doom", "a usable word bank rolls a real name"
	)


func test_rerolling_with_an_empty_word_bank_is_safe() -> void:
	WordBankLoader.adjectives = []
	WordBankLoader.nouns = []
	var game := await _make_table()

	game._reroll_packs()
	await get_tree().process_frame

	assert_eq(game._title.text, Game.FALLBACK_TITLE, "rerolling does not error either")
