extends GutTest

# Tests how source/mod-manager's PackDataLoader (submodule code) reads a pack's
# cards: in numeric order, and remembering the file each came from so saving can
# keep untouched cards as-is.

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
