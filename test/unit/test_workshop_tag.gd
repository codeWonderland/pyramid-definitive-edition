extends GutTest

# Tests that packs from the Steam Workshop are tagged with the Workshop category,
# so the draft can filter by it - once, whatever case a pack already used.


func _pack(tags: Array[String]) -> PackData:
	var pack := PackData.new()
	pack.tags = tags
	return pack


func test_a_workshop_pack_gets_the_workshop_category() -> void:
	var packs: Array[PackData] = [_pack(["Strategy"] as Array[String])]

	PacksManager.tag_as_workshop(packs)

	assert_eq(packs[0].tags, ["Strategy", PacksManager.WORKSHOP_TAG])


func test_a_pack_that_already_lists_it_isnt_tagged_twice() -> void:
	var packs: Array[PackData] = [_pack(["workshop mods"] as Array[String])]

	PacksManager.tag_as_workshop(packs)

	assert_eq(packs[0].tags, ["workshop mods"], "matched without regard to case")


func test_the_tag_matches_the_mods_category() -> void:
	var categories: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string("res://initial_mods/pyramid-mods/categories.json")
	)
	var names: Array = categories["categories"].map(
		func(entry: Dictionary) -> String: return entry["name"]
	)

	assert_has(names, PacksManager.WORKSHOP_TAG, "so the filter can show its description")
