class_name Updater extends Control

const DATA_PATH: String = "https://api.github.com/repos/codeWonderland/pyramid-mods/branches/main"
# gdlint:ignore = max-line-length
const DOWNLOAD_PATH: String = "https://github.com/codeWonderland/pyramid-mods/archive/refs/heads/main.zip"
const NETWORK_CHECK_TIME: float = 15.0

var _has_internet: bool = false
var _has_requested_updates: bool = false
var _latest_version: String = ""
var _packs_loaded: bool = false
var _word_bank_loaded: bool = false
var _additional_rules_loaded: bool = false

@onready var _http_request: HTTPRequest = %HTTPRequest
@onready var _label: Label = %Label
@onready var _continue_button: Button = %Continue
@onready var _skip_button: Button = %Skip
@onready var _download_button: Button = %Download
@onready var _quit_button: Button = %Quit


func _ready() -> void:
	_quit_button.pressed.connect(_quit_game)
	_download_button.pressed.connect(_download_updates)
	_continue_button.pressed.connect(_continue)
	_skip_button.pressed.connect(_load_data)

	_check_internet_access()
	await get_tree().create_timer(NETWORK_CHECK_TIME).timeout
	_request_update_data(13, -1, [], [])


# === Network Request Functions ===


func _check_internet_access() -> void:
	_http_request.request_completed.connect(_validate_internet)
	_http_request.request("https://www.github.com", [], HTTPClient.METHOD_GET)


func _validate_internet(
	result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray
) -> void:
	_has_internet = true
	_request_update_data(result, response_code, headers, body)


func _request_update_data(
	result: int, _response_code: int, _headers: PackedStringArray, _body: PackedByteArray
) -> void:
	if _has_requested_updates:
		return

	_has_requested_updates = true

	if not _has_internet or result != 0:
		if UserSettingsManager.latest_version == "":
			_label.text = "Cannot access internet / download initial data. Please try again"
			_quit_button.show()
		else:
			_label.text = "Cannot access internet, using existing version"
			_load_data()

		return

	_label.text = "Checking for Updates..."
	_http_request.request_completed.connect(_check_update_data)
	_http_request.request(DATA_PATH, [], HTTPClient.METHOD_GET)


func _check_update_data(
	result: int, _response_code: int, _headers: PackedStringArray, body: PackedByteArray
) -> void:
	if result != 0:
		if UserSettingsManager.latest_version == "":
			_label.text = "Cannot pull updates data / download initial data. Please try again"
			_quit_button.show()
		else:
			_label.text = "Cannot pull updates data, using existing version"
			_load_data()

		return

	var parsed_json = JSON.parse_string(body.get_string_from_utf8())

	if parsed_json == null:
		if UserSettingsManager.latest_version == "":
			_label.text = "Cannot parse updates data / download initial data. Please try again"
			_quit_button.show()
		else:
			_label.text = "Cannot parse updates data, using existing version"
			_load_data()

	var sha = parsed_json["commit"]["sha"]
	_latest_version = sha

	if UserSettingsManager.latest_version == "":
		_download_updates()
	elif UserSettingsManager.latest_version == sha:
		_label.text = "Everything is Up to Date"
		_load_data()
	else:
		_label.text = "New Updates Found!"
		_download_button.show()
		_skip_button.show()


func _download_updates() -> void:
	_download_button.hide()
	_skip_button.hide()

	if UserSettingsManager.latest_version == "":
		_label.text = "Downloading Initial Data..."
	else:
		_label.text = "Downloading Updates..."

	_http_request.request_completed.disconnect(_check_update_data)
	_http_request.request_completed.connect(_apply_updates)
	_http_request.request(DOWNLOAD_PATH, [], HTTPClient.METHOD_GET)


func _apply_updates(
	result: int, _response_code: int, _headers: PackedStringArray, body: PackedByteArray
) -> void:
	if result != 0:
		if UserSettingsManager.latest_version == "":
			_label.text = "Issue downloading initial data. Please try again"
			_quit_button.show()
		else:
			_label.text = "Issue downloading latest updates, using existing version"
			_load_data()

		return

	# Save ZIP File
	var output_zip = FileAccess.open("user://updates.zip", FileAccess.WRITE)
	output_zip.store_buffer(body)
	output_zip.close()

	# Delete Old Mods Files
	var mods_folder = DirAccess.open("user://mods/")
	if mods_folder:
		_delete_recursive(mods_folder)

	# Create New Mods Folder
	var user_dir = DirAccess.open("user://")
	user_dir.make_dir("mods/")
	mods_folder = DirAccess.open("user://mods/")

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
	user_dir.remove("updates.zip")

	# Update Records
	UserSettingsManager.update_latest_version(_latest_version)

	_label.text = "Updates Applied"
	_load_data()


func _delete_recursive(folder: DirAccess) -> void:
	var folder_path = folder.get_current_dir(true)

	var files = folder.get_files()
	for file in files:
		folder.remove(file)

	var subfolders = folder.get_directories()
	for subfolder_path in subfolders:
		var full_subfolder_path = folder_path + "/" + subfolder_path
		var subfolder = DirAccess.open(full_subfolder_path)
		_delete_recursive(subfolder)

	DirAccess.remove_absolute(folder_path)


func _continue() -> void:
	var can_continue = true

	for check in [_packs_loaded, _word_bank_loaded, _additional_rules_loaded]:
		can_continue = can_continue and check

	if can_continue:
		get_tree().change_scene_to_packed(load("res://source/menus/pack_select.tscn"))


func _load_data() -> void:
	_download_button.hide()
	_skip_button.hide()

	_label.text = "Loading..."

	PackLoader.packs_loaded.connect(_on_packs_loaded)
	PackLoader.load()
	WordBankLoader.word_bank_loaded.connect(_on_word_bank_loaded)
	WordBankLoader.load()
	AdditionalRulesLoader.rules_loaded.connect(_on_additional_rules_loaded)
	AdditionalRulesLoader.load()


func _on_packs_loaded() -> void:
	_packs_loaded = true
	_continue()


func _on_word_bank_loaded() -> void:
	_word_bank_loaded = true
	_continue()


func _on_additional_rules_loaded() -> void:
	_additional_rules_loaded = true
	_continue()


func _quit_game() -> void:
	get_tree().quit()
