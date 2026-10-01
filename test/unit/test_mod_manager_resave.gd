extends GutTest

# Tests that saving a pack from the editor keeps the card files it didn't change.
# Saving used to re-encode every card as a fresh PNG, so editing one card - or
# nothing at all - marked every image in the pack as changed in a pull request,
# and quietly turned JPEG cards into PNGs.

const MOD_MANAGER: PackedScene = preload("res://source/mod-manager/mod_manager.tscn")

var _root: String


func before_each() -> void:
	_root = ProjectSettings.globalize_path("user://test_resave_%d/" % randi())
	DirAccess.make_dir_recursive_absolute(_root)


func after_each() -> void:
	OS.execute("rm", ["-rf", _root])


## A card image unique to `seed`, so every file's bytes can be told apart.
func _image(seed: int) -> Image:
	var img := Image.create(8, 12, false, Image.FORMAT_RGBA8)
	img.fill(Color(fmod(seed * 0.137, 1.0), fmod(seed * 0.311, 1.0), 0.5))
	img.set_pixel(seed % 8, seed % 12, Color.BLACK)
	return img


## Writes a pack to disk: one back, three primaries (p3 as a JPEG), one curse.
func _write_pack(title: String) -> String:
	var folder := _root.path_join(title)
	DirAccess.make_dir_recursive_absolute(folder)
	_image(1).save_png(folder.path_join("b1.png"))
	_image(2).save_png(folder.path_join("p1.png"))
	_image(3).save_png(folder.path_join("p2.png"))
	_image(4).save_jpg(folder.path_join("p3.jpg"))
	_image(5).save_png(folder.path_join("c1.png"))
	return folder


func _bytes(folder: String) -> Dictionary:
	var files := {}
	for name in DirAccess.get_files_at(folder):
		files[name] = FileAccess.get_file_as_bytes(folder.path_join(name))
	return files


func _manager() -> ModManager:
	var manager := MOD_MANAGER.instantiate() as ModManager
	manager.mods_path = _root
	manager.scene_to_return_to = null
	add_child_autofree(manager)
	await get_tree().process_frame
	return manager


func _loaded(folder: String) -> PackData:
	return PackDataLoader.load_pack_from_path(folder.trim_suffix("/"))


func test_loading_remembers_each_cards_file() -> void:
	var folder := _write_pack("Alpha")
	var pack := _loaded(folder)

	assert_eq(
		pack.primaries[0].get_meta(PackDataLoader.SOURCE_META),
		folder.path_join("p1.png"),
		"the card knows the file it came from"
	)


func test_saving_an_unchanged_pack_leaves_every_file_identical() -> void:
	var folder := _write_pack("Alpha")
	var before := _bytes(folder)
	var manager := await _manager()

	manager._save_mod(_loaded(folder))

	assert_eq(_bytes(folder), before, "same files, same bytes")


func test_a_jpeg_card_stays_a_jpeg() -> void:
	var folder := _write_pack("Alpha")
	var jpeg := FileAccess.get_file_as_bytes(folder.path_join("p3.jpg"))
	var manager := await _manager()

	manager._save_mod(_loaded(folder))

	assert_true(FileAccess.file_exists(folder.path_join("p3.jpg")), "still p3.jpg")
	assert_false(FileAccess.file_exists(folder.path_join("p3.png")), "no PNG copy")
	assert_eq(FileAccess.get_file_as_bytes(folder.path_join("p3.jpg")), jpeg, "same bytes")


func test_editing_one_card_leaves_the_others_alone() -> void:
	var folder := _write_pack("Alpha")
	var before := _bytes(folder)
	var pack := _loaded(folder)
	var manager := await _manager()

	pack.curses.append(ImageTexture.create_from_image(_image(9)))
	manager._save_mod(pack)

	var after := _bytes(folder)
	for name in before:
		assert_eq(after[name], before[name], "%s untouched" % name)
	assert_true(after.has("c2.png"), "and the new card was written")


func test_removing_a_middle_card_just_removes_its_file() -> void:
	var folder := _write_pack("Alpha")
	var before := _bytes(folder)
	var pack := _loaded(folder)
	var manager := await _manager()

	# Loaded in numeric order: p1, p2, p3.jpg. Drop p2.
	pack.primaries.remove_at(1)
	manager._save_mod(pack)

	var after := _bytes(folder)
	assert_false(after.has("p2.png"), "its file is gone")
	assert_eq(after["p1.png"], before["p1.png"], "p1 untouched")
	assert_eq(after["p3.jpg"], before["p3.jpg"], "p3 keeps its name, leaving a gap")


func test_removing_card_one_moves_the_last_card_into_its_place() -> void:
	# The mods repo requires p1 (and b1), so slot 1 is refilled - by moving one
	# card, not by renumbering them all.
	var folder := _write_pack("Alpha")
	var before := _bytes(folder)
	var pack := _loaded(folder)
	var manager := await _manager()

	pack.primaries.remove_at(0)
	manager._save_mod(pack)

	var after := _bytes(folder)
	assert_eq(after["p1.jpg"], before["p3.jpg"], "the highest card moved into slot 1")
	assert_eq(after["p2.png"], before["p2.png"], "and p2 didn't change at all")
	assert_false(after.has("p3.jpg"), "nothing left at its old number")
	assert_false(after.has("p1.png"), "no stale p1")


func test_a_new_card_fills_the_lowest_gap() -> void:
	var folder := _write_pack("Alpha")
	DirAccess.remove_absolute(folder.path_join("p2.png"))
	var pack := _loaded(folder)
	var manager := await _manager()

	pack.primaries.append(ImageTexture.create_from_image(_image(9)))
	manager._save_mod(pack)

	var after := _bytes(folder)
	assert_true(after.has("p2.png"), "the new card took the free number")
	assert_false(after.has("p4.png"), "rather than a new one at the end")


func test_a_card_picked_from_disk_keeps_its_original_bytes() -> void:
	var folder := _write_pack("Alpha")
	var picked := _root.path_join("my card.jpeg")
	_image(7).save_jpg(picked)
	var pack := _loaded(folder)
	var manager := await _manager()

	var texture := ImageTexture.create_from_image(Image.load_from_file(picked))
	texture.set_meta(PackDataLoader.SOURCE_META, picked)
	pack.secondaries.append(texture)
	manager._save_mod(pack)

	assert_eq(
		FileAccess.get_file_as_bytes(folder.path_join("s1.jpeg")),
		FileAccess.get_file_as_bytes(picked),
		"copied as chosen, not re-encoded"
	)


func test_renaming_a_pack_moves_its_files_unchanged() -> void:
	var folder := _write_pack("Alpha")
	var before := _bytes(folder)
	var pack := _loaded(folder)
	var manager := await _manager()

	pack.title = "Beta"
	manager._on_pack_saved(pack)

	assert_false(DirAccess.dir_exists_absolute(folder), "the old folder is gone")
	assert_eq(_bytes(_root.path_join("Beta")), before, "every card arrived byte for byte")


func test_other_files_in_the_folder_are_left_alone() -> void:
	var folder := _write_pack("Alpha")
	var note := FileAccess.open(folder.path_join("notes.txt"), FileAccess.WRITE)
	note.store_string("keep me")
	note.close()
	var manager := await _manager()

	manager._save_mod(_loaded(folder))

	assert_true(FileAccess.file_exists(folder.path_join("notes.txt")), "non-card files survive")


func test_saving_an_unchanged_pack_shows_no_changes_to_git() -> void:
	# The point of all this: a contributor who opens a pack and saves it without
	# changing anything has nothing to submit.
	var folder := _write_pack("Alpha")
	var git := func(args: Array) -> String:
		var out: Array = []
		OS.execute("git", PackedStringArray(["-C", _root] + args), out, true)
		return "".join(out).strip_edges()
	git.call(["init", "--quiet"])
	git.call(["add", "--all"])
	git.call(
		["-c", "user.name=T", "-c", "user.email=t@example.com", "commit", "--quiet", "-m", "x"]
	)
	var manager := await _manager()

	manager._save_mod(_loaded(folder))

	assert_eq(git.call(["status", "--porcelain"]), "", "git sees nothing to submit")


func test_a_pack_with_ten_or_more_cards_saves_unchanged() -> void:
	# Files list alphabetically - p1, p10, p11, p2 ... - and saving numbers cards
	# in loaded order, so loading has to put them back in numeric order or p10's
	# image would be saved as p2.
	var folder := _root.path_join("Big")
	DirAccess.make_dir_recursive_absolute(folder)
	_image(1).save_png(folder.path_join("b1.png"))
	for i in range(1, 13):
		_image(20 + i).save_png(folder.path_join("p%d.png" % i))
	var before := _bytes(folder)
	var manager := await _manager()

	manager._save_mod(_loaded(folder))

	assert_eq(_bytes(folder), before, "p1..p12 all keep their own images")


func test_an_untouched_record_is_not_rewritten() -> void:
	var folder := _write_pack("Alpha")
	# Already consistent with the pack's three primaries and one curse, so saving
	# has nothing to fill in.
	var record := (
		'{\n\t"id": "alpha",\n\t"is_free": true,\n\t"objectives": {\n'
		+ '\t\t"curse_count": 1,\n\t\t"has_curse": true,\n'
		+ '\t\t"primary_count": 3,\n\t\t"secondary_count": 0\n\t},\n'
		+ '\t"tags": [\n\t\t"Puzzle"\n\t]\n}\n'
	)
	var file := FileAccess.open(folder.path_join("pack.json"), FileAccess.WRITE)
	file.store_string(record)
	file.close()
	var manager := await _manager()

	manager._save_mod(_loaded(folder))

	assert_eq(
		FileAccess.get_file_as_string(folder.path_join("pack.json")), record, "left as written"
	)


func test_a_changed_record_keeps_whole_numbers_whole() -> void:
	var folder := _write_pack("Alpha")
	var file := FileAccess.open(folder.path_join("pack.json"), FileAccess.WRITE)
	file.store_string('{"players": 22, "tags": ["Puzzle"]}')
	file.close()
	var pack := _loaded(folder)
	var manager := await _manager()

	pack.tags.append("Action")
	manager._save_mod(pack)

	var written := FileAccess.get_file_as_string(folder.path_join("pack.json"))
	assert_string_contains(written, '"players": 22', "22 stays 22")
	assert_string_contains(written, '"primary_count": 3', "counts are whole numbers too")
	assert_false(written.contains("22.0"), "not 22.0")
	assert_true(written.ends_with("\n"), "ends with a newline, like the rest of the repo")
