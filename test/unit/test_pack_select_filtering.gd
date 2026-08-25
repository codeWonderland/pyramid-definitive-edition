extends GutTest

# Tests the draft grid's search box and tag filters (#38), and that they compose
# with the existing sort / favorites ordering rather than replacing it.

const PACK_SELECT_PACKS: PackedScene = preload(
	"res://source/menus/menu_widgets/pack_select_packs.tscn"
)

var _saved_all_packs: Array[PackData]


func _texture() -> ImageTexture:
	var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	return ImageTexture.create_from_image(img)


func _path(title: String) -> String:
	return "user://__test_filter_%s" % title


func _pack(title: String, tags: Array[String]) -> PackData:
	var pack := PackData.new()
	pack.title = title
	pack.folder_path = _path(title)
	var backs: Array[ImageTexture] = [_texture()]
	pack.backs = backs
	pack.tags = tags
	return pack


func before_each() -> void:
	_saved_all_packs = PacksManager.all_packs
	var packs: Array[PackData] = [
		_pack("The Binding of Isaac", ["Roguelike", "Twin-stick"] as Array[String]),
		_pack("Hollow Knight", ["Metroidvania"] as Array[String]),
		_pack("Slay the Spire", ["Roguelike", "Deckbuilder"] as Array[String]),
		_pack("Untagged Game", [] as Array[String]),
	]
	PacksManager.all_packs = packs


func after_each() -> void:
	# Clear favorites while the test packs are still installed: restoring
	# all_packs first would leave a test favorite set for the next test.
	for pack in PacksManager.all_packs:
		if FavoritesManager.is_favorite(pack.folder_path):
			FavoritesManager.toggle(pack.folder_path)

	PacksManager.all_packs = _saved_all_packs


func _titles(packs: Array) -> Array:
	var out: Array = []
	for pack in packs:
		out.append(pack.title)
	return out


func _make_grid() -> PackSelectPacks:
	var grid := PACK_SELECT_PACKS.instantiate() as PackSelectPacks
	add_child_autofree(grid)
	await get_tree().process_frame
	return grid


# --- Search ---


func test_empty_search_shows_everything() -> void:
	var grid := await _make_grid()

	grid.set_search_query("")
	assert_eq(grid._ordered_packs().size(), 4, "an empty query filters nothing")


func test_search_matches_substring() -> void:
	var grid := await _make_grid()

	grid.set_search_query("isaac")
	assert_eq(_titles(grid._ordered_packs()), ["The Binding of Isaac"], "substring search")


func test_search_matches_initials_subsequence() -> void:
	var grid := await _make_grid()

	grid.set_search_query("tboi")
	assert_eq(_titles(grid._ordered_packs()), ["The Binding of Isaac"], "fuzzy initials search")


func test_search_with_no_matches_is_empty() -> void:
	var grid := await _make_grid()

	grid.set_search_query("zzzzz")
	assert_eq(grid._ordered_packs(), [], "no matches yields an empty grid, not a crash")


func test_search_keeps_favorites_first() -> void:
	FavoritesManager.toggle(_path("Slay the Spire"))
	var grid := await _make_grid()

	# "s" matches all four titles as a subsequence; the favorite still leads.
	grid.set_search_query("s")
	assert_eq(
		_titles(grid._ordered_packs())[0], "Slay the Spire", "search preserves favorites-first"
	)


# --- Tag filters ---


func test_no_tag_filter_shows_everything() -> void:
	var grid := await _make_grid()

	grid.set_tag_filters([] as Array[String], false)
	assert_eq(grid._ordered_packs().size(), 4, "no ticked tags filters nothing")


func test_single_tag_filter() -> void:
	var grid := await _make_grid()

	grid.set_tag_filters(["Metroidvania"] as Array[String], false)
	assert_eq(_titles(grid._ordered_packs()), ["Hollow Knight"], "one tag narrows to one pack")


func test_tag_filter_is_case_insensitive() -> void:
	var grid := await _make_grid()

	grid.set_tag_filters(["metroidvania"] as Array[String], false)
	assert_eq(
		_titles(grid._ordered_packs()), ["Hollow Knight"], "tag matching ignores capitalisation"
	)


func test_or_mode_matches_any_ticked_tag() -> void:
	var grid := await _make_grid()

	grid.set_tag_filters(["Deckbuilder", "Metroidvania"] as Array[String], false)
	assert_eq(
		_titles(grid._ordered_packs()),
		["Hollow Knight", "Slay the Spire"],
		"OR mode returns packs carrying either tag"
	)


func test_and_mode_requires_every_ticked_tag() -> void:
	var grid := await _make_grid()

	grid.set_tag_filters(["Roguelike", "Deckbuilder"] as Array[String], true)
	assert_eq(
		_titles(grid._ordered_packs()),
		["Slay the Spire"],
		"AND mode keeps only the pack carrying both tags"
	)


func test_and_mode_with_no_pack_matching_all_is_empty() -> void:
	var grid := await _make_grid()

	grid.set_tag_filters(["Metroidvania", "Deckbuilder"] as Array[String], true)
	assert_eq(grid._ordered_packs(), [], "no pack carries both tags")


func test_untagged_packs_are_excluded_by_any_tag_filter() -> void:
	var grid := await _make_grid()

	grid.set_tag_filters(["Roguelike"] as Array[String], false)
	assert_false(
		_titles(grid._ordered_packs()).has("Untagged Game"), "a pack with no tags cannot match"
	)


# --- Search and tags together ---


func test_search_and_tag_filter_compose() -> void:
	var grid := await _make_grid()

	grid.set_tag_filters(["Roguelike"] as Array[String], false)
	grid.set_search_query("slay")
	assert_eq(
		_titles(grid._ordered_packs()), ["Slay the Spire"], "search narrows within the tag filter"
	)


func test_search_and_tag_filter_can_intersect_to_nothing() -> void:
	var grid := await _make_grid()

	grid.set_tag_filters(["Metroidvania"] as Array[String], false)
	grid.set_search_query("isaac")
	assert_eq(grid._ordered_packs(), [], "contradictory search and tag filter yields nothing")
