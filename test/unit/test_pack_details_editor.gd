extends GutTest

# Tests the pack editor's Details section: it shows a pack's record, writes edits
# back into it, leaves an untouched record exactly as it was, and saving fills in
# what comes from the cards.

const PACK_EDITOR: PackedScene = preload("res://source/mod-manager/popups/pack_editor.tscn")
const MOD_MANAGER: PackedScene = preload("res://source/mod-manager/mod_manager.tscn")

var _root: String


func before_each() -> void:
	_root = "user://test_details_%d" % randi()
	DirAccess.make_dir_recursive_absolute(_root)


func after_each() -> void:
	ModsSync.clear(_root)


func _record() -> Dictionary:
	return {
		"id": "temp-zero",
		"name": "Temp Zero",
		"is_free": false,
		"estimated_time": null,
		"objectives":
		{
			"primary_count": 10,
			"secondary_count": 10,
			"has_curse": true,
			"curse_count": 1,
			"versus_tertiary": "Highest score",
			"co_op_rules": "",
		},
		"special_challenges":
		{
			"creator_available": false,
			"developer_available": true,
			"entries":
			[
				{
					"id": "temp-zero-challenge-1",
					"text": "Every dash evades something.",
					"type": "secondary",
					"contributor": {"handle": "@dev", "role": "Lead Dev"},
				}
			]
		},
		"tags": ["Action"],
	}


func _pack(record: Dictionary) -> PackData:
	var pack := PackData.new()
	pack.title = "temp zero"
	pack.metadata = record
	pack.tags.assign(record.get("tags", []))
	return pack


func _editor(pack: PackData) -> PackEditor:
	var editor := PACK_EDITOR.instantiate() as PackEditor
	add_child_autofree(editor)
	await get_tree().process_frame
	editor.pack_data = pack
	editor.open()
	await get_tree().process_frame
	return editor


func _rows(editor: PackEditor) -> Array:
	return editor._challenge_list.get_children().filter(
		func(row: Node) -> bool: return not row.is_queued_for_deletion()
	)


func test_the_record_is_shown() -> void:
	var editor := await _editor(_pack(_record()))

	assert_eq(editor._display_name_line_edit.text, "Temp Zero")
	assert_eq(editor._price_option.selected, 2, "paid")
	assert_eq(editor._estimated_time_line_edit.text, "", "no time recorded")
	assert_eq(editor._versus_text_edit.text, "Highest score")
	var rows := _rows(editor)
	assert_eq(rows.size(), 1, "one challenge")
	assert_eq(rows[0]._text.text, "Every dash evades something.")
	assert_eq(rows[0]._handle.text, "@dev")
	assert_eq(rows[0]._role.text, "Lead Dev")
	assert_eq(rows[0]._type.selected, 1, "secondary")


func test_an_untouched_record_is_written_back_exactly() -> void:
	var pack := _pack(_record())
	var editor := await _editor(pack)

	editor._write_details(pack.metadata)

	assert_eq(JSON.stringify(pack.metadata, "", true), JSON.stringify(_record(), "", true))


func test_edits_are_written_back() -> void:
	var pack := _pack(_record())
	var editor := await _editor(pack)

	editor._display_name_line_edit.text = "Temp Zero Deluxe"
	editor._price_option.select(1)
	editor._estimated_time_line_edit.text = "30m"
	editor._coop_text_edit.text = "Share one run"
	editor._description_text_edit.text = "A frozen roguelite."
	editor._store_url_line_edit.text = "https://store.steampowered.com/app/2"
	_rows(editor)[0]._role.text = "Creator"
	editor._add_challenge_row({})
	await get_tree().process_frame
	var added: ChallengeRow = _rows(editor)[1]
	added._text.text = "Never stop moving"
	added._handle.text = "@streamer"
	added._type.select(0)
	editor._add_challenge_row({})
	editor._write_details(pack.metadata)

	var record := pack.metadata
	assert_eq(record["name"], "Temp Zero Deluxe")
	assert_eq(record["is_free"], true)
	assert_eq(record["estimated_time"], "30m")
	assert_eq(record["objectives"]["co_op_rules"], "Share one run")
	assert_eq(record["description"], "A frozen roguelite.")
	assert_eq(record["store_url"], "https://store.steampowered.com/app/2")
	assert_false(record.has("presskit_url"), "an empty field adds nothing")
	var entries: Array = record["special_challenges"]["entries"]
	assert_eq(entries.size(), 2, "the blank row is dropped")
	assert_eq(entries[0]["id"], "temp-zero-challenge-1", "the existing id kept")
	assert_eq(entries[0]["contributor"]["role"], "Creator")
	assert_eq(
		entries[1],
		{"text": "Never stop moving", "type": "primary", "contributor": {"handle": "@streamer"}}
	)


func test_a_removed_challenge_is_gone() -> void:
	var pack := _pack(_record())
	var editor := await _editor(pack)

	_rows(editor)[0].remove_requested.emit()
	editor._write_details(pack.metadata)

	assert_eq(pack.metadata["special_challenges"]["entries"], [])


func test_a_new_pack_left_blank_gets_no_record() -> void:
	var editor := await _editor(null)

	editor._write_details(editor.pack_data.metadata)

	assert_eq(editor.pack_data.metadata, {}, "nothing typed, nothing recorded")


func test_saving_fills_in_counts_and_challenge_kinds() -> void:
	var folder := _root.path_join("temp zero")
	DirAccess.make_dir_recursive_absolute(folder)
	for stem in ["b1", "p1", "p2", "s1"]:
		Image.create(4, 4, false, Image.FORMAT_RGBA8).save_png("%s/%s.png" % [folder, stem])
	var tags: Array[String] = ["Action"]
	PackDataLoader.save_metadata(folder, _record(), tags)
	var manager := MOD_MANAGER.instantiate() as ModManager
	manager.mods_path = _root + "/"
	add_child_autofree(manager)
	await get_tree().process_frame
	var pack := PackDataLoader.load_pack_from_path(folder)

	manager._on_pack_saved(pack)

	var saved := PackDataLoader.load_metadata(folder)
	assert_eq(saved["objectives"]["primary_count"], 2, "counted from the cards")
	assert_eq(saved["objectives"]["secondary_count"], 1)
	assert_eq(saved["objectives"]["has_curse"], false)
	assert_eq(saved["objectives"]["curse_count"], 0)
	assert_eq(saved["objectives"]["versus_tertiary"], "Highest score", "the rule kept")
	assert_true(saved["special_challenges"]["developer_available"])
