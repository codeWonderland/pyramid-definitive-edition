extends GutTest

# Tests for source/mod-manager PackDataLoader (submodule code).


func test_sort_packs_orders_by_title() -> void:
	var a := PackData.new()
	a.title = "Apples"
	var b := PackData.new()
	b.title = "Bananas"

	assert_true(PackDataLoader.sort_packs(a, b), "Apples sorts before Bananas")
	assert_false(PackDataLoader.sort_packs(b, a), "Bananas does not sort before Apples")


func test_missing_pack_path_returns_null() -> void:
	var pack = PackDataLoader.load_pack_from_path("user://definitely_missing_%d" % randi())

	assert_null(pack, "a pack folder with no card backs loads as null, not a crash")
