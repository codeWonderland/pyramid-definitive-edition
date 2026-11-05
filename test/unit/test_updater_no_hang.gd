extends GutTest

# Tests that checking for mod updates can't keep the game on the loading screen:
# requests time out, a failed file list doesn't fall back to downloading the
# whole repo, a skipped download is never applied, and the mods load once.

const UPDATER: PackedScene = preload("res://source/updater/updater.tscn")


## The updater without its network check or mod loading, which in a test would
## reach GitHub and then change scene.
class QuietUpdater:
	extends Updater

	var loads: int = 0

	func _check_internet_access() -> void:
		pass

	func _load_data() -> void:
		if _data_loading:
			return
		_data_loading = true
		loads += 1


func _updater() -> QuietUpdater:
	var updater := UPDATER.instantiate()
	updater.set_script(QuietUpdater)
	add_child_autofree(updater)
	await get_tree().process_frame
	return updater as QuietUpdater


func test_update_requests_time_out() -> void:
	var updater := await _updater()

	assert_eq(updater._http_request.timeout, Updater.REQUEST_TIMEOUT, "no request waits forever")


func test_a_file_list_that_cant_be_fetched_doesnt_pull_the_whole_repo() -> void:
	var updater := await _updater()
	updater._latest_version = "abc"

	# GitHub refusing an unauthenticated request looks like this.
	updater._on_tree_received(HTTPRequest.RESULT_SUCCESS, 403, [], PackedByteArray())

	assert_false(updater._archive_downloading, "no archive download")
	assert_eq(updater.loads, 1, "the existing mods load")
	assert_string_contains(updater._label.text, "using existing mods")


func test_skipping_a_download_ignores_what_arrives_after() -> void:
	var updater := await _updater()
	updater._download_updates()
	assert_true(updater._skip_button.visible, "skipping is offered while downloading")

	updater._skip_button.pressed.emit()
	updater._on_tree_received(HTTPRequest.RESULT_SUCCESS, 200, [], "{}".to_utf8_buffer())
	updater._apply_updates(HTTPRequest.RESULT_SUCCESS, 200, [], PackedByteArray())

	assert_eq(updater.loads, 1, "the mods load once, and nothing late is applied")


func test_progress_counts_files() -> void:
	assert_eq(Updater.progress_text(12, 127), "Downloading Updates... 12 of 127")
	assert_eq(Updater.progress_text(-1, 5), "Downloading Updates... 0 of 5", "never below zero")
