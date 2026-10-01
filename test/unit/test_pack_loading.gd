extends GutTest

# Tests how source/mod-manager's PackDataLoader (submodule code) reads a pack's
# cards: in numeric order, remembering the file each came from so saving can keep
# untouched cards as-is, and leaving the fronts for later when only the backs are
# wanted. Mirrors the submodule's own test/test_pack_loading.gd.

var _root: String


func before_each() -> void:
	_root = "user://test_packload_%d" % randi()
	DirAccess.make_dir_recursive_absolute(_root)


func after_each() -> void:
	var dir = DirAccess.open(_root)
	if dir:
		Helpers.delete_recursive(dir)


func _card(name: String, shade: float) -> void:
	var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color(shade, shade, shade))
	img.save_png(_root.path_join(name))


func test_cards_load_in_numeric_order() -> void:
	_card("b1.png", 0.5)
	for i in [1, 2, 10, 11, 3]:
		_card("p%d.png" % i, i / 20.0)

	var pack := PackDataLoader.load_pack_from_path(_root)

	var names: Array = []
	for card in pack.primaries:
		names.append(str(card.get_meta(PackDataLoader.SOURCE_META)).get_file())
	assert_eq(names, ["p1.png", "p2.png", "p3.png", "p10.png", "p11.png"], "p10 after p3, not p1")


func test_each_card_remembers_its_file() -> void:
	_card("b1.png", 0.5)
	_card("p1.png", 0.2)

	var pack := PackDataLoader.load_pack_from_path(_root)

	assert_eq(
		pack.backs[0].get_meta(PackDataLoader.SOURCE_META), _root + "/b1.png", "the back's file"
	)
	assert_eq(
		pack.primaries[0].get_meta(PackDataLoader.SOURCE_META), _root + "/p1.png", "the card's file"
	)


func test_a_pack_can_load_with_only_its_backs() -> void:
	_card("b1.png", 0.5)
	for i in [1, 10, 2]:
		_card("p%d.png" % i, i / 20.0)
	_card("s1.png", 0.3)
	_card("c1.png", 0.4)

	var pack := PackDataLoader.load_pack_from_path(_root, false)

	assert_eq(pack.backs.size(), 1, "backs are loaded")
	assert_true(pack.primaries.is_empty() and pack.secondaries.is_empty(), "fronts aren't")
	assert_true(pack.curses.is_empty(), "curses aren't either")
	var names: Array = []
	for path in pack.unloaded_faces:
		names.append(path.get_file())
	assert_eq(
		names, ["c1.png", "p1.png", "p2.png", "p10.png", "s1.png"], "fronts waiting, in order"
	)
	assert_true(PackDataLoader.has_primaries(pack), "it still counts as having primaries")


func test_loading_faces_later_gives_the_same_cards() -> void:
	_card("b1.png", 0.5)
	for i in [1, 10, 2]:
		_card("p%d.png" % i, i / 20.0)
	_card("s1.png", 0.3)
	_card("c1.png", 0.4)
	var eager := PackDataLoader.load_pack_from_path(_root)

	var lazy := PackDataLoader.load_pack_from_path(_root, false)
	PackDataLoader.load_faces(lazy)
	PackDataLoader.load_faces(lazy)

	for group in ["backs", "primaries", "secondaries", "curses"]:
		var want: Array = []
		var got: Array = []
		for card in eager.get(group):
			want.append(card.get_meta(PackDataLoader.SOURCE_META))
		for card in lazy.get(group):
			got.append(card.get_meta(PackDataLoader.SOURCE_META))
		assert_eq(got, want, "%s match an eager load, loaded once" % group)
	assert_true(lazy.unloaded_faces.is_empty(), "nothing left waiting")


func test_listing_a_folder_loads_only_backs_and_skips_packs_without_primaries() -> void:
	var listed := _root.path_join("listed")
	var no_primaries := _root.path_join("no primaries")
	for folder in [listed, no_primaries]:
		DirAccess.make_dir_recursive_absolute(folder)
		Image.create(4, 4, false, Image.FORMAT_RGBA8).save_png(folder.path_join("b1.png"))
		Image.create(4, 4, false, Image.FORMAT_RGBA8).save_png(folder.path_join("s1.png"))
	Image.create(4, 4, false, Image.FORMAT_RGBA8).save_png(listed.path_join("p1.png"))

	var packs := await PackDataLoader.load_packs_from_folder(_root + "/", get_tree())

	assert_eq(packs.size(), 1, "the pack with no primary is skipped")
	assert_eq(packs[0].title, "listed")
	assert_eq(packs[0].backs.size(), 1, "its back is loaded")
	assert_true(packs[0].primaries.is_empty(), "its fronts wait for load_faces")
