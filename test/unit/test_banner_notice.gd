extends GutTest

# Tests the notice shown after saving a run banner: capturing one changes nothing
# on screen, so without it the Save Banner button looked like it did nothing.

const NOTICE: PackedScene = preload("res://source/game/banner_notice.tscn")
const GAME_SCENE: PackedScene = preload("res://source/game/game.tscn")


func _notice() -> BannerNotice:
	var notice := NOTICE.instantiate() as BannerNotice
	add_child_autofree(notice)
	await get_tree().process_frame
	return notice


func test_a_saved_banner_says_where_it_went() -> void:
	var notice := await _notice()
	assert_false(notice.visible, "hidden until something is saved")

	notice.show_saved("/home/player/Pictures/pyramid-run-2026-11-05-143210.png")

	assert_true(notice.visible)
	assert_eq(notice._title.text, "Banner saved")
	assert_eq(notice._detail.text, "pyramid-run-2026-11-05-143210.png in Pictures")
	assert_true(notice._show_button.visible, "and offers to open the folder")


func test_a_failed_save_is_reported() -> void:
	var notice := await _notice()

	notice.show_failed("/home/player/Pictures/pyramid-run.png")

	assert_true(notice.visible)
	assert_eq(notice._title.text, "Couldn't save the banner")
	assert_false(notice._show_button.visible, "there's no file to show")


func test_the_notice_fades_away() -> void:
	var notice := await _notice()
	notice.show_saved("user://pyramid-run.png")

	await get_tree().create_timer(BannerNotice.SHOW_TIME + BannerNotice.FADE_TIME + 0.2).timeout

	assert_false(notice.visible, "gone after a few seconds")


func test_the_button_explains_itself_and_the_notice_is_kept_out_of_banners() -> void:
	RunManager.clear()
	RunManager.num_games = 1
	var texture := ImageTexture.create_from_image(Image.create(4, 4, false, Image.FORMAT_RGBA8))
	var pack := PackData.new()
	pack.title = "Test"
	pack.folder_path = "user://test_pack_banner_notice"
	pack.backs.append(texture)
	pack.primaries.append(texture)
	var packs: Array[PackData] = [pack]
	RunManager.selected_packs = packs
	var game := GAME_SCENE.instantiate() as Game
	add_child_autofree(game)
	await get_tree().process_frame

	assert_string_contains(game._capture_banner_button.tooltip_text, "wherever you choose")
	game._banner_notice.show_saved("user://pyramid-run.png")
	var hidden := game._hide_ui_for_capture()
	assert_has(hidden, game._banner_notice, "a showing notice is hidden for the capture")
	assert_false(game._banner_notice.visible)
	RunManager.popup_open = false


# --- Choosing where it goes ---


func _game() -> Game:
	RunManager.clear()
	RunManager.num_games = 1
	var texture := ImageTexture.create_from_image(Image.create(4, 4, false, Image.FORMAT_RGBA8))
	var pack := PackData.new()
	pack.title = "Test"
	pack.folder_path = "user://test_pack_banner_save"
	pack.backs.append(texture)
	pack.primaries.append(texture)
	var packs: Array[PackData] = [pack]
	RunManager.selected_packs = packs
	var game := GAME_SCENE.instantiate() as Game
	add_child_autofree(game)
	await get_tree().process_frame
	return game


func test_the_player_picks_where_it_goes_starting_at_home() -> void:
	var game := await _game()

	game._ask_where_to_save(Image.create(30, 10, false, Image.FORMAT_RGBA8))

	assert_true(game._banner_save_dialog.visible, "the save dialog opens")
	assert_eq(game._banner_save_dialog.current_dir, BannerCapture.home_directory(), "at home")
	assert_string_starts_with(game._banner_save_dialog.current_file, "pyramid-run-", "named")
	assert_true(RunManager.popup_open, "and holds the table while it's open")
	game._banner_save_dialog.hide()
	game._on_banner_save_cancelled()


func test_the_banner_is_saved_where_chosen() -> void:
	var game := await _game()
	var chosen := ProjectSettings.globalize_path("user://test_banner_choice_%d" % randi())
	game._ask_where_to_save(Image.create(30, 10, false, Image.FORMAT_RGBA8))
	game._banner_save_dialog.hide()

	game._banner_save_dialog.file_selected.emit(chosen)

	assert_true(FileAccess.file_exists(chosen + ".png"), "saved there, as a png")
	assert_true(game._banner_notice.visible, "and the notice says so")
	assert_false(RunManager.popup_open, "the table is free again")
	DirAccess.remove_absolute(chosen + ".png")


func test_cancelling_saves_nothing() -> void:
	var game := await _game()
	game._ask_where_to_save(Image.create(30, 10, false, Image.FORMAT_RGBA8))
	game._banner_save_dialog.hide()

	game._banner_save_dialog.canceled.emit()

	assert_null(game._pending_banner, "the picture is let go")
	assert_false(game._banner_notice.visible, "nothing to report")
	assert_false(RunManager.popup_open, "the table is free again")
