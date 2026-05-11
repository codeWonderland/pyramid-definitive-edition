class_name Updater extends Control

const DATA_PATH: String = "https://api.github.com/repos/codeWonderland/pyramid-mods/branches/main"
# gdlint:ignore = max-line-length
const DOWNLOAD_PATH: String = "https://github.com/codeWonderland/pyramid-mods/archive/refs/heads/main.zip"
const NETWORK_CHECK_TIME: float = 15.0
const INITIAL_MODS_PATH: String = "res://initial_mods/pyramid-mods/"
const MODS_ROOT: String = "user://mods/"
const REMOTE_MODS_PATH: String = "user://mods/pyramid-mods-main/"

var _has_internet: bool = false
var _internet_check_resolved: bool = false
var _latest_version: String = ""
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

	_ensure_initial_mods_present()

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

	if UserSettingsManager.latest_version == sha:
		_label.text = "Everything is Up to Date"
		_load_data()
		return

	if UserSettingsManager.latest_version == "":
		_label.text = "Mod updates available, download?"
	else:
		_label.text = "New Updates Found!"

	_loading_animation.hide()
	_download_button.show()
	_skip_button.show()


func _download_updates() -> void:
	_loading_animation.show()
	_download_button.hide()
	_skip_button.hide()
	_label.text = "Downloading Updates..."

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
	var output_zip = FileAccess.open("user://updates.zip", FileAccess.WRITE)
	output_zip.store_buffer(body)
	output_zip.close()

	# Delete remote mods (preserve user://mods/local/)
	var remote_mods = DirAccess.open(REMOTE_MODS_PATH)
	if remote_mods:
		Helpers.delete_recursive(remote_mods)

	# Ensure mods root exists
	DirAccess.make_dir_recursive_absolute(MODS_ROOT)
	var mods_folder = DirAccess.open(MODS_ROOT)

	# Extract ZIP File
	var zip_reader = ZIPReader.new()
	zip_reader.open("user://updates.zip")

	var files = zip_reader.get_files()
	for file_path in files:
		if file_path.ends_with("/"):
			mods_folder.make_dir_recursive(file_path)
			continue

		mods_folder.make_dir_recursive(
			mods_folder.get_current_dir().path_join(file_path).get_base_dir()
		)
		var file = FileAccess.open(
			mods_folder.get_current_dir().path_join(file_path), FileAccess.WRITE
		)
		var buffer = zip_reader.read_file(file_path)
		file.store_buffer(buffer)

	# Delete Zip
	DirAccess.open("user://").remove("updates.zip")

	# Update Records
	UserSettingsManager.update_latest_version(_latest_version)

	_label.text = "Updates Applied"
	_load_data()


# === Initial Mods Functions ===


func _ensure_initial_mods_present() -> void:
	if _remote_mods_present():
		return

	_label.text = "Setting up initial mods..."
	DirAccess.make_dir_recursive_absolute(REMOTE_MODS_PATH)
	_copy_directory_recursive(INITIAL_MODS_PATH, REMOTE_MODS_PATH)


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
