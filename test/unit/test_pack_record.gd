extends GutTest

# Tests source/mod-manager's PackRecord (submodule code), the rules the editor
# applies to a pack's pack.json on save: card counts, challenge kinds and ids come
# from the pack, and fields left alone stay exactly as they were. Mirrors the
# submodule's own test/test_pack_record.gd.


func _pack(primaries: int, secondaries: int, curses: int) -> PackData:
	var pack := PackData.new()
	pack.title = "my pack"
	var texture := ImageTexture.new()
	for i in range(primaries):
		pack.primaries.append(texture)
	for i in range(secondaries):
		pack.secondaries.append(texture)
	for i in range(curses):
		pack.curses.append(texture)
	return pack


func test_slugs_read_like_the_official_ids() -> void:
	assert_eq(PackRecord.slug("A to Z Trivia"), "a-to-z-trivia")
	assert_eq(PackRecord.slug("Binding of Isaac: Repentance"), "binding-of-isaac-repentance")
	assert_eq(PackRecord.slug("Slice & Dice"), "slice-and-dice")
	assert_eq(PackRecord.slug("  --Weird!!  name--  "), "weird-name")


func test_untouched_text_leaves_the_record_alone() -> void:
	var record := {"name": "Hades", "estimated_time": null}

	PackRecord.set_text(record, "name", "Hades")
	PackRecord.set_text(record, "estimated_time", "")
	PackRecord.set_text(record, "missing", "")

	assert_eq(record, {"name": "Hades", "estimated_time": null}, "nothing changed")


func test_text_is_set_trimmed_and_can_be_cleared() -> void:
	var record := {"name": "Hades"}

	PackRecord.set_text(record, "name", "  Hades II ")
	assert_eq(record["name"], "Hades II", "trimmed")
	PackRecord.set_text(record, "name", "")
	assert_eq(record["name"], "", "cleared")


func test_counts_come_from_the_cards() -> void:
	var record := {"id": "x", "objectives": {"primary_count": 22, "versus_tertiary": "Fastest"}}

	PackRecord.finalize(record, _pack(11, 7, 1))

	assert_eq(
		record["objectives"],
		{
			"primary_count": 11,
			"secondary_count": 7,
			"has_curse": true,
			"curse_count": 1,
			"versus_tertiary": "Fastest",
		},
		"counted, and the rule kept"
	)


func test_a_new_record_gets_an_id_from_its_name_or_folder() -> void:
	var named := PackRecord.finalize({"name": "Hades II"}, _pack(1, 0, 0))
	var unnamed := PackRecord.finalize({}, _pack(1, 0, 0))
	var kept := PackRecord.finalize({"id": "custom-id", "name": "Hades II"}, _pack(1, 0, 0))

	assert_eq(named["id"], "hades-ii")
	assert_eq(unnamed["id"], "my-pack", "from the folder")
	assert_eq(kept["id"], "custom-id", "an existing id never changes")


func test_challenge_kinds_follow_the_contributors() -> void:
	var record := {
		"id": "x",
		"special_challenges":
		{
			"creator_available": false,
			"developer_available": true,
			"entries":
			[
				{"id": "x-challenge-1", "text": "a", "contributor": {"role": "Creator"}},
			]
		}
	}

	PackRecord.finalize(record, _pack(1, 0, 0))
	assert_true(record["special_challenges"]["creator_available"], "a creator's challenge")
	assert_false(record["special_challenges"]["developer_available"], "no developer's")

	record["special_challenges"]["entries"].append(
		{"text": "b", "contributor": {"role": "Lead Dev"}}
	)
	PackRecord.finalize(record, _pack(1, 0, 0))
	assert_true(record["special_challenges"]["developer_available"], "any other role")


func test_new_challenges_get_unused_ids() -> void:
	var record := {
		"id": "temp-zero",
		"special_challenges":
		{"entries": [{"text": "a"}, {"id": "temp-zero-challenge-1", "text": "b"}, {"text": "c"}]}
	}

	PackRecord.finalize(record, _pack(1, 0, 0))

	var ids: Array = []
	for entry in record["special_challenges"]["entries"]:
		ids.append(entry["id"])
	assert_eq(ids, ["temp-zero-challenge-2", "temp-zero-challenge-1", "temp-zero-challenge-3"])


func test_unknown_fields_survive() -> void:
	var record := {
		"id": "x",
		"store_link": "https://example.com",
		"special_challenges": {"entries": [{"id": "x-1", "text": "a", "source_game_name": "Y"}]},
	}

	PackRecord.finalize(record, _pack(1, 0, 0))

	assert_eq(record["store_link"], "https://example.com")
	assert_eq(record["special_challenges"]["entries"][0]["source_game_name"], "Y")


func test_only_web_links_are_offered() -> void:
	var record := {
		"store_url": " https://store.steampowered.com/app/1 ",
		"presskit_url": "file:///etc/passwd",
		"other": 5,
	}

	assert_eq(PackRecord.web_link(record, "store_url"), "https://store.steampowered.com/app/1")
	assert_eq(PackRecord.web_link(record, "presskit_url"), "", "not a web address")
	assert_eq(PackRecord.web_link(record, "other"), "", "not text")
	assert_eq(PackRecord.web_link(record, "missing"), "")
