extends GutTest

# Tests the Library screen (#36): a searchable grid of packs, and a detail panel
# showing a game's record, its real card counts, its cards, and the player's marks.

const LIBRARY: PackedScene = preload("res://source/menus/library.tscn")
const MAIN_MENU: PackedScene = preload("res://source/menus/main_menu.tscn")

var _saved_all_packs: Array[PackData]


func _texture() -> ImageTexture:
	var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	return ImageTexture.create_from_image(img)


func _textures(count: int) -> Array[ImageTexture]:
	var out: Array[ImageTexture] = []
	for i in range(count):
		out.append(_texture())
	return out


func _pack(title: String, metadata: Dictionary = {}) -> PackData:
	var pack := PackData.new()
	pack.title = title
	pack.folder_path = "user://__test_library_%s" % title
	pack.backs = _textures(1)
	pack.primaries = _textures(3)
	pack.secondaries = _textures(2)
	pack.curses = _textures(1)
	pack.metadata = metadata
	pack.tags = PackDataLoader.tags_from_metadata(metadata)
	return pack


func before_each() -> void:
	_saved_all_packs = PacksManager.all_packs
	var packs: Array[PackData] = [
		_pack(
			"a to z",
			{
				"name": "A to Z Trivia",
				"tags": ["Puzzle", "Miscellaneous"],
				"is_free": true,
				"estimated_time": "15m",
				"objectives": {"versus_tertiary": "Fewest matches", "co_op_rules": "Share a list"},
				"special_challenges":
				{
					"entries":
					[
						{
							"text": "Win with one hand",
							"contributor": {"handle": "@dev", "role": "Lead Dev"}
						}
					]
				},
			}
		),
		_pack("hollow knight"),
	]
	PacksManager.all_packs = packs


func after_each() -> void:
	for pack in PacksManager.all_packs:
		for mark in PlayerMarksManager.MARKS:
			PlayerMarksManager.set_mark(pack.folder_path, mark["id"], false)
	PacksManager.all_packs = _saved_all_packs


func _make() -> Library:
	var library := LIBRARY.instantiate() as Library
	add_child_autofree(library)
	await get_tree().process_frame
	return library


# --- Grid ---


func test_grid_shows_every_pack() -> void:
	var library := await _make()
	assert_eq(library._grid.get_child_count(), 2, "one card per pack")


func test_search_narrows_the_grid() -> void:
	var library := await _make()

	library._search.text = "hollow"
	library._search.text_changed.emit("hollow")
	await get_tree().process_frame

	assert_eq(library.visible_packs().size(), 1, "only the match")
	assert_eq(library.visible_packs()[0].title, "hollow knight", "and it is the right one")


func test_favorites_toggle_narrows_the_grid() -> void:
	var library := await _make()
	FavoritesManager.toggle(PacksManager.all_packs[1].folder_path)

	library._favorites_button.pressed.emit()

	assert_eq(library.visible_packs().size(), 1, "only the favourite")
	assert_eq(library._favorites_button.text, "Showing: Favorites", "and the toggle says so")


func test_no_matches_shows_the_empty_notice() -> void:
	var library := await _make()

	library._search.text = "zzzzz"
	library._search.text_changed.emit("zzzzz")
	await get_tree().process_frame

	assert_true(library._empty_grid_label.visible, "empty notice shown")


# --- Details ---


func test_nothing_selected_shows_the_placeholder() -> void:
	var library := await _make()

	assert_true(library._placeholder.visible, "placeholder first")
	assert_false(library._details.visible, "no details yet")


func test_clicking_a_card_shows_its_details() -> void:
	var library := await _make()

	library._grid.get_child(0).pressed.emit(PacksManager.all_packs[0])

	assert_true(library._details.visible, "details shown")
	assert_eq(library._pack_name.text, "A to Z Trivia", "the spreadsheet's name, not the folder")
	assert_eq(library._tags.text, "Puzzle, Miscellaneous", "its categories")


func test_a_pack_without_a_record_uses_its_folder_name() -> void:
	var library := await _make()

	library._show_details(PacksManager.all_packs[1])

	assert_eq(library._pack_name.text, "hollow knight", "falls back to the folder")
	assert_eq(library._tags.text, "No categories recorded", "and says so")


func test_facts_use_the_real_card_counts() -> void:
	var facts := Library.describe_facts(PacksManager.all_packs[0])

	assert_string_contains(facts, "Free", "price")
	assert_string_contains(facts, "About 15m per run", "play time")
	assert_string_contains(facts, "3 primary · 2 secondary · 1 curse", "counted from the images")


func test_rules_are_described() -> void:
	var rules := Library.describe_rules(PacksManager.all_packs[0].metadata)

	assert_string_contains(rules, "Versus: Fewest matches", "versus rule")
	assert_string_contains(rules, "Co-op: Share a list", "co-op rule")
	assert_eq(
		Library.describe_rules({}), "No versus or co-op rules recorded", "or the lack of them"
	)


func test_challenges_credit_their_author() -> void:
	var challenges := Library.describe_challenges(PacksManager.all_packs[0].metadata)

	assert_string_contains(challenges, "Win with one hand (@dev, Lead Dev)", "credited")
	assert_eq(Library.describe_challenges({}), "", "nothing when there are none")


func test_malformed_records_do_not_break_the_panel() -> void:
	var junk := {"objectives": "nope", "special_challenges": {"entries": [7, {"text": 3}]}}

	assert_eq(Library.describe_rules(junk), "No versus or co-op rules recorded", "bad rules")
	assert_eq(Library.describe_challenges(junk), "", "bad challenges")


func test_cards_are_shown_grouped_by_type() -> void:
	var library := await _make()

	library._show_details(PacksManager.all_packs[0])

	# heading + row for each of primary, secondary, curse
	assert_eq(library._cards.get_child_count(), 6, "three groups of heading and cards")


func test_clicking_a_thumbnail_opens_the_inspector() -> void:
	var library := await _make()
	library._show_details(PacksManager.all_packs[0])

	var row: HFlowContainer = library._cards.get_child(1)
	row.get_child(0).pressed.emit()

	assert_true(library._card_inspector.visible, "the card opens large")


# --- Marks ---


func test_marks_panel_offers_every_mark() -> void:
	var library := await _make()

	library._show_details(PacksManager.all_packs[0])

	assert_eq(library._marks.get_child_count(), PlayerMarksManager.MARKS.size(), "one box each")


func test_ticking_a_mark_stores_it() -> void:
	var library := await _make()
	var pack := PacksManager.all_packs[0]
	library._show_details(pack)

	var never_draft: CheckBox = library._marks.get_child(3)
	never_draft.button_pressed = true

	assert_true(PlayerMarksManager.has_mark(pack.folder_path, "never_draft"), "stored")


func test_exclusive_marks_update_the_other_box() -> void:
	var library := await _make()
	var pack := PacksManager.all_packs[0]
	library._show_details(pack)

	(library._marks.get_child(0) as CheckBox).button_pressed = true  # Owned
	await get_tree().process_frame
	(library._marks.get_child(1) as CheckBox).button_pressed = true  # Don't own
	await get_tree().process_frame

	assert_false(
		(library._marks.get_child(0) as CheckBox).button_pressed,
		"ticking don't own visibly unticks owned"
	)


# --- Entry point ---


func test_main_menu_offers_the_library() -> void:
	var menu := MAIN_MENU.instantiate()
	add_child_autofree(menu)
	await get_tree().process_frame

	assert_true(is_instance_valid(menu._library_button), "Library button resolved")
	assert_eq(menu._library_button.pressed.get_connections().size(), 1, "and wired up")


func test_a_pack_listed_with_only_its_backs_shows_its_cards() -> void:
	var folder := "user://__test_library_lazy"
	DirAccess.make_dir_recursive_absolute(folder)
	for stem in ["b1", "p1", "p2", "s1"]:
		Image.create(4, 4, false, Image.FORMAT_RGBA8).save_png("%s/%s.png" % [folder, stem])
	var listed := PackDataLoader.load_pack_from_path(folder, false)
	var library := await _make()

	library._show_details(listed)

	assert_string_contains(library._facts.text, "2 primary · 1 secondary", "counted once loaded")
	var thumbs := 0
	for row in library._cards.get_children():
		if row is HFlowContainer:
			thumbs += row.get_child_count()
	assert_eq(thumbs, 3, "every card shown")
	Helpers.delete_recursive(DirAccess.open(folder))
