class_name Updater extends Control

const DATA_PATH: String = "https://api.github.com/repos/codeWonderland/pyramid-mods/branches/main"
# gdlint:ignore = max-line-length
const DOWNLOAD_PATH: String = "https://github.com/codeWonderland/pyramid-mods/archive/refs/heads/main.zip"
# gdlint:ignore = max-line-length
const TREE_PATH: String = "https://api.github.com/repos/codeWonderland/pyramid-mods/git/trees/%s?recursive=1"
const RAW_FILE_PATH: String = "https://raw.githubusercontent.com/codeWonderland/pyramid-mods/%s/%s"
## Past this many changed files, one archive download beats fetching them singly.
const MAX_FILE_DOWNLOADS: int = 300
const PARALLEL_DOWNLOADS: int = 6
const NETWORK_CHECK_TIME: float = 15.0
const INITIAL_MODS_PATH: String = "res://initial_mods/pyramid-mods/"
const MODS_ROOT: String = "user://mods/"
const REMOTE_MODS_PATH: String = "user://mods/pyramid-mods-main/"
const UPDATE_ZIP_PATH: String = "user://updates.zip"
const UPDATE_TEMP_PATH: String = "user://mods_update_tmp/"

var _has_internet: bool = false
var _internet_check_resolved: bool = false
var _latest_version: String = ""
var _latest_time: int = 0
## The version being downloaded, and what's left of it to fetch.
var _target: Dictionary = {}
var _plan: Dictionary = {}
var _download_queue: Array[String] = []
var _downloads_in_flight: int = 0
var _download_failed: bool = false
var _downloads_finished: bool = false
var _packs_loaded: bool = false
var _word_bank_loaded: bool = false
var _additional_rules_loaded: bool = false
var _backgrounds_loaded: bool = false

@onready var _background: TextureRect = %Background
@onready var _http_request: HTTPRequest = %HTTPRequest
@onready var _loading_animation: LoadingAnimation = %LoadingAnimation
@onready var _label: Label = %Label
@onready var _continue_button: Button = %Continue
@onready var _skip_button: Button = %Skip
@onready var _download_button: Button = %Download
@onready var _quit_button: Button = %Quit


func _ready() -> void:
	_set_background()
	_quit_button.pressed.connect(_quit_game)
	_download_button.pressed.connect(_download_updates)
	_continue_button.pressed.connect(_continue)
	_skip_button.pressed.connect(_load_data)

	_check_internet_access()
	await get_tree().create_timer(NETWORK_CHECK_TIME).timeout
	_resolve_internet_check()


func _set_background() -> void:
	if BackgroundManager.backgrounds.has(UserSettingsManager.background):
		_background.texture = BackgroundManager.backgrounds[UserSettingsManager.background]


# === Network Request Functions ===


func _check_internet_access() -> void:
	_http_request.request_completed.connect(_on_internet_response, CONNECT_ONE_SHOT)
	_http_request.request("https://www.github.com", [], HTTPClient.METHOD_GET)


func _on_internet_response(
	result: int, _response_code: int, _headers: PackedStringArray, _body: PackedByteArray
) -> void:
	if result == HTTPRequest.RESULT_SUCCESS:
		_has_internet = true
	_resolve_internet_check()


func _resolve_internet_check() -> void:
	if _internet_check_resolved:
		return
	_internet_check_resolved = true

	_apply_bundled_mods()

	if not _has_internet:
		_label.text = "Loading..."
		_load_data()
		return

	_check_for_updates()


func _check_for_updates() -> void:
	_label.text = "Checking for Updates..."
	_http_request.request_completed.connect(_check_update_data, CONNECT_ONE_SHOT)
	_http_request.request(DATA_PATH, [], HTTPClient.METHOD_GET)


func _check_update_data(
	result: int, _response_code: int, _headers: PackedStringArray, body: PackedByteArray
) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		_label.text = "Couldn't check for updates, using existing mods"
		_load_data()
		return

	var parsed_json = JSON.parse_string(body.get_string_from_utf8())

	if parsed_json == null or not parsed_json.has("commit"):
		_label.text = "Couldn't parse updates info, using existing mods"
		_load_data()
		return

	var sha: String = parsed_json["commit"]["sha"]
	_latest_version = sha
	_latest_time = _commit_time(parsed_json)

	if UserSettingsManager.latest_version == sha:
		_label.text = "Everything is Up to Date"
		_load_data()
		return

	if _should_download_without_asking():
		_label.text = "New Updates Found!"
		_download_updates()
		return

	if UserSettingsManager.latest_version == "":
		_label.text = "Mod updates available, download?"
	else:
		_label.text = "New Updates Found!"

	_loading_animation.hide()
	_download_button.show()
	_skip_button.show()


## Whether a found update should just be applied rather than offered. Off by
## default - game updates bring new mods without a download - so players are
## asked first unless they've turned automatic updates on.
func _should_download_without_asking() -> bool:
	return UserSettingsManager.auto_update_mods


static func _commit_time(branch: Dictionary) -> int:
	var commit = branch["commit"].get("commit")
	if commit is Dictionary and commit.get("committer") is Dictionary:
		var date = commit["committer"].get("date")
		if date is String:
			return Time.get_unix_time_from_datetime_string(date)
	return 0


func _download_updates() -> void:
	_loading_animation.show()
	_download_button.hide()
	_skip_button.hide()
	_label.text = "Downloading Updates..."

	# List the new version's files first, to fetch only the ones that changed.
	_http_request.request_completed.connect(_on_tree_received, CONNECT_ONE_SHOT)
	_http_request.request(TREE_PATH % _latest_version, [], HTTPClient.METHOD_GET)


func _on_tree_received(
	result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray
) -> void:
	_target = {}
	if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
		var tree = JSON.parse_string(body.get_string_from_utf8())
		_target = ModsSync.manifest_from_tree(tree, _latest_version, _latest_time)

	if _target.is_empty():
		_download_archive()
		return

	_plan = ModsSync.changes(_installed_manifest().get("files", {}), _target["files"])
	ModsSync.clear(UPDATE_TEMP_PATH)
	# Files the game was shipped with needn't come over the network.
	_download_queue = ModsSync.stage_from_folder(
		INITIAL_MODS_PATH, UPDATE_TEMP_PATH, _plan["fetch"], _target["files"]
	)

	if _download_queue.size() > MAX_FILE_DOWNLOADS:
		ModsSync.clear(UPDATE_TEMP_PATH)
		_download_archive()
		return

	_download_failed = false
	_downloads_finished = false
	_downloads_in_flight = 0
	for i in range(mini(PARALLEL_DOWNLOADS, _download_queue.size())):
		_download_next_file()
	if _download_queue.is_empty() and _downloads_in_flight == 0:
		_finish_file_downloads()


func _download_next_file() -> void:
	if _download_queue.is_empty() or _download_failed:
		return

	var path: String = _download_queue.pop_back()
	var staged := UPDATE_TEMP_PATH.path_join(path)
	DirAccess.make_dir_recursive_absolute(staged.get_base_dir())

	var request := HTTPRequest.new()
	request.download_file = staged
	add_child(request)
	request.request_completed.connect(_on_file_downloaded.bind(request), CONNECT_ONE_SHOT)
	_downloads_in_flight += 1
	if request.request(RAW_FILE_PATH % [_latest_version, ModsSync.url_path(path)]) != OK:
		_on_file_downloaded(HTTPRequest.RESULT_CANT_CONNECT, 0, [], [], request)


func _on_file_downloaded(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	_body: PackedByteArray,
	request: HTTPRequest
) -> void:
	request.queue_free()
	_downloads_in_flight -= 1
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		_download_failed = true

	_download_next_file()
	if _downloads_in_flight == 0 and (_download_queue.is_empty() or _download_failed):
		_finish_file_downloads()


func _finish_file_downloads() -> void:
	# A request failing as it starts can land here before the first batch is out.
	if _downloads_finished:
		return
	_downloads_finished = true

	if (
		_download_failed
		or not ModsSync.staged_correctly(UPDATE_TEMP_PATH, _plan["fetch"], _target["files"])
	):
		ModsSync.clear(UPDATE_TEMP_PATH)
		_label.text = "Issue downloading latest updates, using existing mods"
		_load_data()
		return

	ModsSync.apply_staged(UPDATE_TEMP_PATH, REMOTE_MODS_PATH, _plan["fetch"], _plan["remove"])
	ModsSync.clear(UPDATE_TEMP_PATH)
	_record_installed(_target)

	_label.text = "Updates Applied"
	_load_data()


## The whole repo as one archive - the fallback when it can't be listed, or when
## so much changed that fetching file by file would be slower.
func _download_archive() -> void:
	_http_request.request_completed.connect(_apply_updates, CONNECT_ONE_SHOT)
	_http_request.request(DOWNLOAD_PATH, [], HTTPClient.METHOD_GET)


func _apply_updates(
	result: int, _response_code: int, _headers: PackedStringArray, body: PackedByteArray
) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		_label.text = "Issue downloading latest updates, using existing mods"
		_load_data()
		return

	# Save ZIP File
	if not _write_buffer_to_file(UPDATE_ZIP_PATH, body):
		_label.text = "Couldn't save update file, using existing mods"
		_load_data()
		return

	# Extract to a temporary directory first so a corrupt/malicious download can
	# never leave the user with half-deleted mods (existing mods stay untouched
	# until we know the new ones extracted cleanly).
	if not _extract_zip_to(UPDATE_ZIP_PATH, UPDATE_TEMP_PATH):
		_label.text = "Update download was invalid, using existing mods"
		_cleanup_path(UPDATE_TEMP_PATH)
		_cleanup_path(UPDATE_ZIP_PATH)
		_load_data()
		return

	# Extraction succeeded: now it's safe to swap in the new mods.
	var remote_mods = DirAccess.open(REMOTE_MODS_PATH)
	if remote_mods:
		Helpers.delete_recursive(remote_mods)

	DirAccess.make_dir_recursive_absolute(MODS_ROOT)
	_move_directory_contents(UPDATE_TEMP_PATH, MODS_ROOT)

	_cleanup_path(UPDATE_TEMP_PATH)
	_cleanup_path(UPDATE_ZIP_PATH)

	# Only record the new version once the swap has actually completed.
	if _target.is_empty():
		_target = {
			"commit": _latest_version,
			"time": _latest_time,
			"files": ModsSync.hash_folder(REMOTE_MODS_PATH),
		}
	_record_installed(_target)

	_label.text = "Updates Applied"
	_load_data()


func _write_buffer_to_file(path: String, body: PackedByteArray) -> bool:
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error(
			"Updater: failed to open %s for writing (%d)" % [path, FileAccess.get_open_error()]
		)
		return false

	file.store_buffer(body)
	file.close()
	return true


# Rejects path-traversal and absolute entries so a malicious archive can't write
# outside the extraction directory (zip-slip).
func _is_safe_zip_entry(path: String) -> bool:
	var normalized := path.replace("\\", "/")

	if normalized.begins_with("/"):
		return false

	# Drive-letter style absolute paths (e.g. "C:/...").
	if normalized.length() >= 2 and normalized[1] == ":":
		return false

	for segment in normalized.split("/"):
		if segment == "..":
			return false

	return true


func _extract_zip_to(zip_path: String, dest_root: String) -> bool:
	_cleanup_path(dest_root)
	DirAccess.make_dir_recursive_absolute(dest_root)

	var dest_dir = DirAccess.open(dest_root)
	if dest_dir == null:
		push_error("Updater: couldn't open extraction directory %s" % dest_root)
		return false

	var zip_reader = ZIPReader.new()
	if zip_reader.open(zip_path) != OK:
		push_error("Updater: couldn't open downloaded archive %s" % zip_path)
		return false

	var files = zip_reader.get_files()
	if files.is_empty():
		push_error("Updater: downloaded archive was empty")
		zip_reader.close()
		return false

	var base := dest_dir.get_current_dir()
	for file_path in files:
		if not _is_safe_zip_entry(file_path):
			push_warning("Updater: skipping unsafe archive entry %s" % file_path)
			continue

		if file_path.ends_with("/"):
			dest_dir.make_dir_recursive(base.path_join(file_path))
			continue

		var out_path := base.path_join(file_path)
		dest_dir.make_dir_recursive(out_path.get_base_dir())

		var out = FileAccess.open(out_path, FileAccess.WRITE)
		if out == null:
			push_error("Updater: failed to write %s during extraction" % out_path)
			zip_reader.close()
			return false

		out.store_buffer(zip_reader.read_file(file_path))
		out.close()

	zip_reader.close()
	return true


func _move_directory_contents(source_root: String, dest_root: String) -> void:
	var source_dir = DirAccess.open(source_root)
	if source_dir == null:
		return

	for sub in source_dir.get_directories():
		var dest := dest_root.path_join(sub)
		var existing = DirAccess.open(dest)
		if existing:
			Helpers.delete_recursive(existing)
		DirAccess.rename_absolute(source_root.path_join(sub), dest)

	for file_name in source_dir.get_files():
		var dest_file := dest_root.path_join(file_name)
		if FileAccess.file_exists(dest_file):
			DirAccess.remove_absolute(dest_file)
		DirAccess.rename_absolute(source_root.path_join(file_name), dest_file)


func _cleanup_path(path: String) -> void:
	if path.ends_with("/"):
		var dir = DirAccess.open(path)
		if dir:
			Helpers.delete_recursive(dir)
	elif FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


# === Initial Mods Functions ===


## Installs the mods the game shipped with: all of them on first run, and after
## that whichever files changed when a game update brings newer mods - so a Steam
## update delivers new mods without the game downloading anything.
func _apply_bundled_mods() -> void:
	var bundled := ModsSync.read_manifest(ModsSync.BUNDLED_MANIFEST_PATH)

	if not _remote_mods_present():
		_label.text = "Setting up initial mods..."
		DirAccess.make_dir_recursive_absolute(REMOTE_MODS_PATH)
		_copy_directory_recursive(INITIAL_MODS_PATH, REMOTE_MODS_PATH)
		# Recording the version means first boot won't download the same mods again.
		if not bundled.is_empty():
			_record_installed(bundled)
		return

	var installed := _installed_manifest()
	if not ModsSync.is_newer(bundled, installed):
		return

	_label.text = "Applying mod updates..."
	if ModsSync.sync_from_folder(
		INITIAL_MODS_PATH, REMOTE_MODS_PATH, UPDATE_TEMP_PATH, installed, bundled
	):
		_record_installed(bundled)


## What's installed. An install from before manifests were kept is hashed once to
## find out, and counts as older than any version with a time.
func _installed_manifest() -> Dictionary:
	var installed := ModsSync.read_manifest(ModsSync.INSTALLED_MANIFEST_PATH)
	if installed.is_empty():
		installed = {
			"commit": UserSettingsManager.latest_version,
			"time": 0,
			"files": ModsSync.hash_folder(REMOTE_MODS_PATH),
		}
	return installed


func _record_installed(manifest: Dictionary) -> void:
	ModsSync.write_manifest(ModsSync.INSTALLED_MANIFEST_PATH, manifest)
	UserSettingsManager.update_latest_version(manifest["commit"])


func _remote_mods_present() -> bool:
	var dir = DirAccess.open(REMOTE_MODS_PATH)
	if dir == null:
		return false
	return dir.get_files().size() > 0 or dir.get_directories().size() > 0


func _copy_directory_recursive(source: String, target: String) -> void:
	var source_dir = DirAccess.open(source)
	if source_dir == null:
		return

	DirAccess.make_dir_recursive_absolute(target)

	for file_name in source_dir.get_files():
		# Skip Godot import sidecars and ignore markers
		if file_name.ends_with(".import") or file_name == ".gdignore":
			continue

		var source_file = source.path_join(file_name)
		var target_file = target.path_join(file_name)
		var bytes = FileAccess.get_file_as_bytes(source_file)
		var out = FileAccess.open(target_file, FileAccess.WRITE)
		if out:
			out.store_buffer(bytes)
			out.close()

	for sub in source_dir.get_directories():
		if sub.begins_with("."):
			continue
		_copy_directory_recursive(source.path_join(sub), target.path_join(sub))


# === Data Loading ===


func _continue() -> void:
	var can_continue = true

	for check in [_packs_loaded, _word_bank_loaded, _additional_rules_loaded, _backgrounds_loaded]:
		can_continue = can_continue and check

	if can_continue:
		get_tree().change_scene_to_packed(load("res://source/menus/pack_select.tscn"))


func _load_data() -> void:
	_loading_animation.show()
	_download_button.hide()
	_skip_button.hide()

	_label.text = "Loading..."

	await get_tree().create_timer(0.1).timeout

	PacksManager.packs_loaded.connect(_on_packs_loaded)
	PacksManager.load()
	WordBankLoader.word_bank_loaded.connect(_on_word_bank_loaded)
	WordBankLoader.load()
	AdditionalRulesLoader.rules_loaded.connect(_on_additional_rules_loaded)
	AdditionalRulesLoader.load()
	BackgroundManager.backgrounds_loaded.connect(_on_backgrounds_loaded)
	BackgroundManager.load()


func _on_packs_loaded() -> void:
	_packs_loaded = true
	_continue()


func _on_word_bank_loaded() -> void:
	_word_bank_loaded = true
	_continue()


func _on_additional_rules_loaded() -> void:
	_additional_rules_loaded = true
	_continue()


func _on_backgrounds_loaded() -> void:
	_backgrounds_loaded = true
	_continue()


func _quit_game() -> void:
	get_tree().quit()
