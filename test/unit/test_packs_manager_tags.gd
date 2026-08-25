extends GutTest

# Tests PacksManager.all_tags(), which feeds the draft screen's filter list:
# distinct tags across every loaded pack, case-insensitively de-duplicated and
# sorted for a stable checkbox order.

var _saved_all_packs: Array[PackData]


func _pack(title: String, tags: Array[String]) -> PackData:
	var pack := PackData.new()
	pack.title = title
	pack.folder_path = "user://__test_tags_%s" % title
	pack.tags = tags
	return pack


func before_each() -> void:
	_saved_all_packs = PacksManager.all_packs


func after_each() -> void:
	PacksManager.all_packs = _saved_all_packs


func _set_packs(packs: Array[PackData]) -> void:
	PacksManager.all_packs = packs


func test_no_packs_means_no_tags() -> void:
	_set_packs([] as Array[PackData])

	assert_eq(PacksManager.all_tags(), [], "no packs, no tags")


func test_untagged_packs_contribute_nothing() -> void:
	_set_packs([_pack("A", [] as Array[String])] as Array[PackData])

	assert_eq(PacksManager.all_tags(), [], "a pack with no tags adds nothing")


func test_collects_across_packs_sorted() -> void:
	_set_packs(
		(
			[
				_pack("A", ["Roguelike", "Deckbuilder"] as Array[String]),
				_pack("B", ["Metroidvania"] as Array[String]),
			]
			as Array[PackData]
		)
	)

	assert_eq(
		PacksManager.all_tags(),
		["Deckbuilder", "Metroidvania", "Roguelike"],
		"tags from every pack, sorted"
	)


func test_deduplicates_across_packs_case_insensitively() -> void:
	_set_packs(
		(
			[
				_pack("A", ["Roguelike"] as Array[String]),
				_pack("B", ["roguelike"] as Array[String]),
				_pack("C", ["ROGUELIKE"] as Array[String]),
			]
			as Array[PackData]
		)
	)

	assert_eq(
		PacksManager.all_tags(),
		["Roguelike"],
		"the same tag spelled differently collapses to the first spelling"
	)
