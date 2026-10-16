extends GutTest

# Tests draft presets: saving the current picks under a name, featured presets
# from the mods, and using either to fill the draft - following renamed packs and
# skipping removed ones.

const DIALOG: PackedScene = preload("res://source/menus/popups/presets_dialog.tscn")
const OFFICIAL: String = PacksManager.PACKS_FOLDER_PATH

var _saved_presets: Array[Dictionary] = []
var _saved_all_packs: Array[PackData] = []
var _saved_renames: Variant
var _root: String


func _pack(folder_path: String) -> PackData:
	var pack := PackData.new()
	pack.title = folder_path.get_file()
	pack.folder_path = folder_path
	pack.backs.append(ImageTexture.create_from_image(Image.create(4, 4, false, Image.FORMAT_RGBA8)))
	return pack


func before_each() -> void:
	_saved_presets = PresetsManager._player_presets.duplicate(true)
	_saved_all_packs = PacksManager.all_packs
	_saved_renames = PacksManager._renames
	PresetsManager._player_presets.clear()
	PacksManager._renames = {}
	PacksManager.all_packs = (
		[
			_pack(OFFICIAL + "alpha"),
			_pack(OFFICIAL + "bravo"),
			_pack("user://mods/local/PACKS/mine")
		]
		as Array[PackData]
	)
	_root = "user://test_presets_%d" % randi()
	DirAccess.make_dir_recursive_absolute(_root)
	RunManager.clear()


func after_each() -> void:
	PresetsManager._player_presets.assign(_saved_presets)
	PresetsManager._save()
	PacksManager.all_packs = _saved_all_packs
	PacksManager._renames = _saved_renames
	ModsSync.clear(_root)
	RunManager.clear()


# --- The player's presets ---


func test_saving_picks_survives_a_restart() -> void:
	assert_true(PresetsManager.save_preset(" Roguelikes ", PacksManager.all_packs))

	var config := ConfigFile.new()
	config.load(PresetsManager.SAVE_PATH)
	var stored: Array = config.get_value("presets", "list")
	assert_eq(stored.size(), 1)
	assert_eq(stored[0]["name"], "Roguelikes", "trimmed")
	assert_eq(stored[0]["packs"].size(), 3, "every pick, by folder")


func test_the_same_name_replaces_and_blank_ones_are_refused() -> void:
	var two: Array[PackData] = [PacksManager.all_packs[0], PacksManager.all_packs[1]]
	PresetsManager.save_preset("Faves", PacksManager.all_packs)
	PresetsManager.save_preset("faves", two)

	assert_eq(PresetsManager.player_presets().size(), 1, "replaced, ignoring case")
	assert_eq(PresetsManager.player_presets()[0]["packs"].size(), 2)
	assert_false(PresetsManager.save_preset("  ", two), "no name")
	assert_false(PresetsManager.save_preset("Empty", [] as Array[PackData]), "no games")


func test_deleting_a_preset() -> void:
	PresetsManager.save_preset("Gone soon", PacksManager.all_packs)

	PresetsManager.delete_preset("GONE SOON")

	assert_eq(PresetsManager.player_presets(), [] as Array[Dictionary])


# --- Featured presets ---


func test_featured_presets_come_from_the_mods() -> void:
	var path := _root.path_join("presets.json")
	var text := (
		'{"presets": [{"name": "Dev picks", "description": "Our favourites",'
		+ ' "packs": ["alpha", "bravo", 4]}, {"name": "", "packs": ["alpha"]}, 7]}'
	)
	FileAccess.open(path, FileAccess.WRITE).store_string(text)

	var featured := PresetsManager.load_featured(path, OFFICIAL)

	assert_eq(featured.size(), 1, "junk skipped")
	assert_eq(featured[0]["name"], "Dev picks")
	assert_eq(featured[0]["description"], "Our favourites")
	assert_eq(featured[0]["packs"], [OFFICIAL + "alpha", OFFICIAL + "bravo"], "as folder paths")
	assert_eq(
		PresetsManager.load_featured(_root.path_join("none.json"), OFFICIAL),
		[] as Array[Dictionary]
	)


# --- Using a preset ---


func test_a_preset_brings_its_installed_games_following_renames() -> void:
	PacksManager._renames = {"old bravo": "bravo"}
	var preset := {
		"name": "x", "packs": [OFFICIAL + "old bravo", OFFICIAL + "removed", OFFICIAL + "alpha"]
	}

	var packs := PresetsManager.packs_for(preset)

	assert_eq(
		packs,
		[PacksManager.all_packs[1], PacksManager.all_packs[0]] as Array[PackData],
		"renamed found, removed skipped, order kept"
	)


func test_the_dialog_saves_picks_and_uses_presets() -> void:
	var dialog := DIALOG.instantiate() as PresetsDialog
	add_child_autofree(dialog)
	await get_tree().process_frame
	RunManager.selected_packs = [PacksManager.all_packs[2]] as Array[PackData]

	dialog.open()
	dialog._preset_name.text = "Just mine"
	dialog._save_picks.pressed.emit()
	assert_eq(PresetsManager.player_presets()[0]["name"], "Just mine", "saved from the picks")
	assert_eq(dialog._your_list.get_child_count(), 1, "and listed")

	RunManager.selected_packs = [] as Array[PackData]
	watch_signals(RunManager)
	var row: HBoxContainer = dialog._your_list.get_child(0)
	(row.get_child(1) as Button).pressed.emit()  # Use

	assert_eq(
		RunManager.selected_packs,
		[PacksManager.all_packs[2]] as Array[PackData],
		"the draft is filled"
	)
	assert_signal_emitted(RunManager, "packs_updated", "and the picks strip refreshes")


func test_saving_is_off_with_nothing_picked() -> void:
	var dialog := DIALOG.instantiate() as PresetsDialog
	add_child_autofree(dialog)
	await get_tree().process_frame

	dialog.open()

	assert_true(dialog._save_picks.disabled)
	assert_true(dialog._save_hint.visible, "and says why")
