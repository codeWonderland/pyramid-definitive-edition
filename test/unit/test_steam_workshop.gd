extends GutTest

# Tests the Steam Workshop support: it stays out of the way without Steam, keeps
# track of which items a player may update, lays packs out for upload so they
# install under their own name, and the mod manager only offers it when available.

const MOD_MANAGER: PackedScene = preload("res://source/mod-manager/mod_manager.tscn")


class FakeWorkshop:
	extends Node
	signal publish_progress(message: String)
	signal publish_finished(succeeded: bool, message: String)

	var available: bool = true
	var published: Array = []
	var opened: int = 0
	## Packs this fake treats as already on the Workshop.
	var on_workshop: Array = []
	## Pack folders import_own_packs() "copies" into the root it's given.
	var to_import: Array[String] = []

	func is_available() -> bool:
		return available

	func is_publishing() -> bool:
		return false

	func publish(pack: PackData) -> void:
		published.append(pack)

	func open_workshop() -> void:
		opened += 1

	func is_published(pack: PackData) -> bool:
		return on_workshop.has(pack)

	func import_own_packs(local_root: String) -> int:
		for title in to_import:
			var folder := local_root.path_join(title)
			DirAccess.make_dir_recursive_absolute(folder)
			for file_name in ["b1.png", "p1.png"]:
				Image.create(4, 4, false, Image.FORMAT_RGBA8).save_png(folder.path_join(file_name))
		return to_import.size()


var _root: String
var _real_workshop: Node


func before_each() -> void:
	_root = "user://test_workshop_%d" % randi()
	DirAccess.make_dir_recursive_absolute(_root)


func after_each() -> void:
	ModsSync.clear(_root)
	if _real_workshop != null:
		get_node("/root/SteamWorkshop").free()
		_real_workshop.name = "SteamWorkshop"
		_real_workshop = null


# --- Without Steam ---


func test_without_steam_nothing_is_offered() -> void:
	# Tests run headless, which never starts Steam.
	assert_false(SteamWorkshop.is_available())
	assert_eq(SteamWorkshop.installed_item_folders(), [] as Array[String], "no subscribed packs")

	SteamWorkshop.publish(PackData.new())
	assert_false(SteamWorkshop.is_publishing(), "publishing is a no-op")


# --- Item records ---


func test_only_the_publisher_updates_an_item() -> void:
	var metadata := {"workshop": SteamWorkshop.item_record(3512345678, "76561199242104382")}

	assert_eq(SteamWorkshop.owned_item_id(metadata, "76561199242104382"), 3512345678, "mine")
	assert_eq(SteamWorkshop.owned_item_id(metadata, "76561190000000001"), 0, "a copy of theirs")
	assert_eq(SteamWorkshop.owned_item_id({}, "76561199242104382"), 0, "never published")
	assert_eq(
		SteamWorkshop.owned_item_id({"workshop": {"id": 12.0, "owner": 5}}, "5"), 0, "junk record"
	)


func test_records_survive_a_save_and_reload_exactly() -> void:
	# A Steam account id is past what JSON's floats hold exactly, so it's a string.
	var record := SteamWorkshop.item_record(3512345678, "76561199242104382")
	var tags: Array[String] = ["Puzzle"]
	PackDataLoader.save_metadata(_root, {"workshop": record}, tags)

	assert_eq(PackDataLoader.load_metadata(_root)["workshop"], record)


# --- Republishing ---


## Writes a pack folder whose pack.json records Workshop item `item_id`.
func _pack_folder(root: String, title: String, item_id: String, owner: String) -> String:
	var folder := root.path_join(title)
	DirAccess.make_dir_recursive_absolute(folder)
	Image.create(4, 4, false, Image.FORMAT_RGBA8).save_png(folder.path_join("b1.png"))
	var metadata := {}
	if not item_id.is_empty():
		metadata["workshop"] = SteamWorkshop.item_record(int(item_id), owner)
	PackDataLoader.save_metadata(folder, metadata, [] as Array[String])
	return folder


func test_only_my_published_packs_are_found_and_only_once() -> void:
	var items := _root.path_join("items")
	var mine := _pack_folder(items.path_join("111"), "Mine", "111", "me")
	_pack_folder(items.path_join("222"), "Theirs", "222", "someone else")
	_pack_folder(items.path_join("333"), "Mine Too", "333", "me")
	var item_folders: Array[String] = [
		items.path_join("111"), items.path_join("222"), items.path_join("333")
	]

	var found := SteamWorkshop.own_pack_folders(item_folders, "me", ["333"] as Array[String])

	assert_eq(found, [mine] as Array[String], "mine, skipping theirs and the one I have locally")


func test_local_packs_are_known_by_their_recorded_item() -> void:
	var local := _root.path_join("local")
	_pack_folder(local, "Renamed Locally", "111", "me")
	_pack_folder(local, "Never Published", "", "")

	assert_eq(SteamWorkshop.local_item_ids(local), ["111"] as Array[String])


func test_a_pack_is_copied_back_with_its_record() -> void:
	var source := _pack_folder(_root.path_join("items/111"), "Chicken TD", "111", "me")
	var local := _root.path_join("local")

	var copy := SteamWorkshop.copy_pack(source, local)

	assert_eq(copy, local.path_join("Chicken TD"), "under its own name")
	assert_true(FileAccess.file_exists(copy.path_join("b1.png")), "cards and all")
	assert_eq(
		SteamWorkshop.owned_item_id(PackDataLoader.load_metadata(copy), "me"),
		111,
		"so publishing it updates the same item"
	)
	assert_eq(SteamWorkshop.copy_pack(source, local), "", "and never over a pack of that name")


func test_a_local_copy_hides_the_subscribed_one() -> void:
	var local := PackData.new()
	local.metadata = {"workshop": SteamWorkshop.item_record(111, "me")}
	var same := PackData.new()
	same.metadata = {"workshop": SteamWorkshop.item_record(111, "me")}
	var other := PackData.new()
	other.metadata = {"workshop": SteamWorkshop.item_record(222, "them")}
	var item_packs: Array[PackData] = [same, other]
	var local_packs: Array[PackData] = [local]

	var shown := SteamWorkshop.without_local_copies(item_packs, local_packs)

	assert_eq(shown, [other] as Array[PackData], "the pack isn't listed twice")


func test_without_steam_nothing_counts_as_published() -> void:
	var pack := PackData.new()
	pack.metadata = {"workshop": SteamWorkshop.item_record(111, "me")}

	assert_false(SteamWorkshop.is_published(pack))
	assert_eq(SteamWorkshop.import_own_packs(_root), 0, "and nothing is fetched")


# --- Upload layout ---


func test_a_pack_is_staged_inside_a_folder_named_after_it() -> void:
	var pack := _root.path_join("PACKS/My Pack")
	DirAccess.make_dir_recursive_absolute(pack)
	for file_name in ["b1.png", "p1.png"]:
		Image.create(4, 4, false, Image.FORMAT_RGBA8).save_png(pack.path_join(file_name))
	FileAccess.open(pack.path_join("pack.json"), FileAccess.WRITE).store_string("{}")
	var staging := _root.path_join("staging")

	var content := SteamWorkshop.stage_pack(pack, staging)

	assert_eq(content, staging, "the folder handed to Steam")
	var staged := DirAccess.get_files_at(staging.path_join("My Pack"))
	assert_eq(Array(staged), ["b1.png", "p1.png", "pack.json"], "the pack's files, under its name")
	assert_eq(
		PackDataLoader.load_pack_from_path(staging.path_join("My Pack")).title,
		"My Pack",
		"so it installs with its own name"
	)


func test_a_missing_pack_stages_nothing() -> void:
	assert_eq(SteamWorkshop.stage_pack(_root.path_join("nope"), _root.path_join("staging")), "")


# --- The mod manager ---


func _swap_in(fake: FakeWorkshop) -> void:
	_real_workshop = get_node("/root/SteamWorkshop")
	_real_workshop.name = "RealSteamWorkshop"
	fake.name = "SteamWorkshop"
	get_tree().root.add_child(fake)


func _mod_manager() -> ModManager:
	var manager := MOD_MANAGER.instantiate() as ModManager
	manager.mods_path = _root + "/"
	add_child_autofree(manager)
	await get_tree().process_frame
	return manager


func test_the_mod_manager_hides_the_workshop_without_steam() -> void:
	var manager := await _mod_manager()

	assert_false(manager._publish_mod_button.visible, "no publish")
	assert_false(manager._browse_workshop_button.visible, "no browse")


func test_the_mod_manager_offers_the_workshop_with_steam() -> void:
	var fake := FakeWorkshop.new()
	_swap_in(fake)
	var manager := await _mod_manager()

	assert_true(manager._publish_mod_button.visible, "publish")
	assert_true(manager._browse_workshop_button.visible, "browse")
	assert_true(manager._import_workshop_button.visible, "get my packs back")

	manager._browse_workshop_button.pressed.emit()
	assert_eq(fake.opened, 1, "browse opens the Workshop")


func test_publishing_needs_a_selected_pack_and_reports_back() -> void:
	var fake := FakeWorkshop.new()
	_swap_in(fake)
	var manager := await _mod_manager()

	manager._publish_mod_button.pressed.emit()
	assert_true(fake.published.is_empty(), "nothing selected, nothing published")
	assert_string_contains(manager._workshop_status.text, "Select a pack")

	var pack := PackData.new()
	manager._selected_pack = pack
	manager._publish_mod_button.pressed.emit()
	assert_eq(fake.published, [pack], "the selected pack is published")
	assert_true(manager._publish_mod_button.disabled, "one at a time")

	fake.publish_progress.emit("Uploading... 40%")
	assert_eq(manager._workshop_status.text, "Uploading... 40%", "progress shown")
	fake.publish_finished.emit(true, "Published to the Workshop.")
	assert_false(manager._publish_mod_button.disabled, "ready again")
	assert_eq(manager._workshop_status.text, "Published to the Workshop.")


func test_the_publish_button_says_when_it_will_update() -> void:
	var fake := FakeWorkshop.new()
	_swap_in(fake)
	var manager := await _mod_manager()
	var fresh := PackData.new()
	var published := PackData.new()
	fake.on_workshop = [published]

	manager._select_pack(fresh)
	assert_eq(manager._publish_mod_button.text, "Publish", "a new item")

	manager._select_pack(published)
	assert_eq(manager._publish_mod_button.text, "Update on Workshop", "the existing one")

	fake.on_workshop = [published, fresh]
	manager._select_pack(fresh)
	fake.publish_finished.emit(true, "Published to the Workshop.")
	assert_eq(manager._publish_mod_button.text, "Update on Workshop", "once it's out there")


func test_getting_my_workshop_packs_lists_them() -> void:
	var fake := FakeWorkshop.new()
	fake.to_import = ["Chicken TD"] as Array[String]
	_swap_in(fake)
	var manager := await _mod_manager()
	assert_eq(manager._mods_list.get_child_count(), 0, "nothing local to start with")

	manager._import_workshop_button.pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame

	assert_eq(manager._mods_list.get_child_count(), 1, "the copied pack is listed")
	assert_string_contains(manager._workshop_status.text, "Copied 1 of your Workshop pack here")

	fake.to_import = [] as Array[String]
	manager._import_workshop_button.pressed.emit()
	assert_string_contains(manager._workshop_status.text, "already here")
