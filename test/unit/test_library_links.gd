extends GutTest

# Tests the Library's description and store/press-kit links (#36): shown when a
# pack's record has them, and only ever as buttons for web addresses.

const LIBRARY: PackedScene = preload("res://source/menus/library.tscn")

var _saved_all_packs: Array[PackData]


func _pack(title: String, metadata: Dictionary) -> PackData:
	var pack := PackData.new()
	pack.title = title
	pack.folder_path = "user://__test_library_links_%s" % title
	var back := ImageTexture.create_from_image(Image.create(4, 4, false, Image.FORMAT_RGBA8))
	pack.backs.append(back)
	pack.primaries.append(back)
	pack.metadata = metadata
	return pack


func before_each() -> void:
	_saved_all_packs = PacksManager.all_packs
	var packs: Array[PackData] = [
		_pack(
			"a to z",
			{
				"description": "  Name a word for every letter. ",
				"store_url": "https://store.steampowered.com/app/1",
				"presskit_url": "javascript:alert(1)",
			}
		),
		_pack("hollow knight", {}),
	]
	PacksManager.all_packs = packs


func after_each() -> void:
	PacksManager.all_packs = _saved_all_packs


func _make() -> Library:
	var library := LIBRARY.instantiate() as Library
	add_child_autofree(library)
	await get_tree().process_frame
	return library


func test_a_description_and_links_are_shown_when_recorded() -> void:
	var library := await _make()

	library._show_details(PacksManager.all_packs[0])

	assert_true(library._description_box.visible, "description shown")
	assert_eq(library._description.text, "Name a word for every letter.", "trimmed")
	assert_true(library._about_row.visible, "the about row shows")
	assert_true(library._store_link.visible, "a web link gets a button")
	assert_false(library._presskit_link.visible, "anything else doesn't")


func test_nothing_extra_is_shown_without_a_description_or_links() -> void:
	var library := await _make()

	library._show_details(PacksManager.all_packs[1])

	assert_false(library._description_box.visible, "no description")
	assert_false(library._about_row.visible, "no about row")


func test_only_steam_pages_get_the_store_button() -> void:
	assert_true(Library.is_steam_link("https://store.steampowered.com/app/250900/"))
	assert_true(Library.is_steam_link("https://s.team/a/250900"))
	assert_true(Library.is_steam_link("http://steamcommunity.com/app/250900"))
	assert_false(Library.is_steam_link("https://store.epicgames.com/p/hades"), "another store")
	assert_false(
		Library.is_steam_link("https://store.steampowered.com.evil.example/"), "a lookalike"
	)
	assert_false(Library.is_steam_link(""), "no link")

	var library := await _make()
	var pack: PackData = PacksManager.all_packs[0]
	pack.metadata["store_url"] = "https://itch.io/some-game"
	pack.metadata["presskit_url"] = "https://example.com/presskit"
	library._show_details(pack)
	assert_false(library._store_link.visible, "an itch.io page gets no Steam button")
	assert_true(library._about_links.visible, "the press kit still shows")
