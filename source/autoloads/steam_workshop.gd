extends Node

## Steam Workshop: loads the packs a player has subscribed to, and publishes their
## local packs. Only offered when the game runs through Steam - otherwise
## is_available() is false and every Workshop button stays hidden.
##
## Every call into GodotSteam goes through Engine.get_singleton("Steam"), never the
## `Steam` global. GodotSteam is a GDExtension: a build without its libraries (a
## GitHub release, CI) doesn't have the class, and a static reference would stop
## this script - and every scene that uses it - from compiling.
##
## A Workshop item's content is a folder holding the pack's folder, so a subscribed
## item installs as <Steam's item folder>/<pack name>/ and loads like any other
## pack, named after the pack rather than the item's number.

signal publish_progress(message: String)
signal publish_finished(succeeded: bool, message: String)

const APP_ID: int = 5277540
const SINGLETON: String = "Steam"
const WORKSHOP_URL: String = "https://steamcommunity.com/app/5277540/workshop/"
const ITEM_URL: String = "https://steamcommunity.com/sharedfiles/filedetails/?id=%d"
const STAGING_PATH: String = "user://workshop_upload/"
## Where a published pack records its item, in its pack.json.
const METADATA_KEY: String = "workshop"

# Valve's k_EResultOK, k_EWorkshopFileTypeCommunity, visibility Public, and the
# EItemState flags.
const RESULT_OK: int = 1
const FILE_TYPE_COMMUNITY: int = 0
const VISIBILITY_PUBLIC: int = 0
const STATE_INSTALLED: int = 4
const STATE_NEEDS_UPDATE: int = 8

var _steam: Object = null
var _publishing: bool = false


func _ready() -> void:
	_initialise()


## Steam answers everything through callbacks that only fire while they're pumped.
func _process(_delta: float) -> void:
	if _steam != null:
		_steam.call("run_callbacks")


## Whether the Workshop can be used: GodotSteam is present, Steam is running, and
## this account owns the game.
func is_available() -> bool:
	return _steam != null


func is_publishing() -> bool:
	return _publishing


func _initialise() -> void:
	# Headless means tests or tools, never a player; don't drag Steam into those.
	if not Engine.has_singleton(SINGLETON) or DisplayServer.get_name() == "headless":
		return

	var steam := Engine.get_singleton(SINGLETON)
	var response: Variant = steam.call("steamInitEx", APP_ID, false)
	# {status, verbal}; 0 is k_ESteamAPIInitResult_OK. Anything else is the normal
	# case for a copy not started from Steam, so it's only logged.
	if response is Dictionary and int(response.get("status", -1)) == 0:
		_steam = steam
	else:
		print("SteamWorkshop: Steam unavailable - %s" % str(response))


# --- Subscribed packs ---


## The installed folders of every subscribed item, each holding a pack folder.
## Items not downloaded yet, or out of date, are queued with Steam and show up on a
## later launch.
func installed_item_folders() -> Array[String]:
	var folders: Array[String] = []
	if _steam == null:
		return folders

	for item_id in _steam.call("getSubscribedItems", false):
		var state := int(_steam.call("getItemState", item_id))
		if state & STATE_NEEDS_UPDATE or not state & STATE_INSTALLED:
			_steam.call("downloadItem", item_id, true)
		if not state & STATE_INSTALLED:
			continue

		var info: Variant = _steam.call("getItemInstallInfo", item_id)
		if info is Dictionary and info.get("ret") and info.get("folder") is String:
			folders.append(info["folder"])

	return folders


func open_workshop() -> void:
	if _steam != null:
		_steam.call("activateGameOverlayToWebPage", WORKSHOP_URL, 0)


# --- Publishing ---


## The Workshop item this player already published `metadata`'s pack as, or 0. A
## pack copied from someone else carries their item, which this player can't update.
func owned_item_id(metadata: Dictionary, steam_id: String) -> int:
	var record = metadata.get(METADATA_KEY)
	if not (record is Dictionary and record.get("owner") is String and record["owner"] == steam_id):
		return 0
	var item_id = record.get("id")
	return int(item_id) if item_id is String and item_id.is_valid_int() else 0


## The record a published pack keeps in its pack.json. Ids are strings: a Steam
## account id doesn't survive JSON's floating-point numbers.
static func item_record(item_id: int, steam_id: String) -> Dictionary:
	return {"id": str(item_id), "owner": steam_id}


## Copies a pack into the upload layout - STAGING_PATH/<pack name>/ - and returns
## that root, or "" if the pack couldn't be read.
static func stage_pack(pack_folder: String, staging_root: String) -> String:
	ModsSync.clear(staging_root)
	var dir := DirAccess.open(pack_folder)
	if dir == null:
		return ""

	var target := staging_root.path_join(pack_folder.trim_suffix("/").get_file())
	DirAccess.make_dir_recursive_absolute(target)
	for file_name in dir.get_files():
		if dir.copy(pack_folder.path_join(file_name), target.path_join(file_name)) != OK:
			return ""
	return staging_root


## Publishes a local pack, creating its Workshop item the first time and updating
## it after that. Reports through publish_progress and publish_finished.
func publish(pack: PackData) -> void:
	if _steam == null or _publishing or pack == null or pack.backs.is_empty():
		return
	_publishing = true

	var steam_id := str(_steam.call("getSteamID"))
	var item_id := owned_item_id(pack.metadata, steam_id)
	var created := item_id == 0

	if created:
		self.publish_progress.emit("Creating a Workshop item...")
		_steam.call("createItem", APP_ID, FILE_TYPE_COMMUNITY)
		var reply: Array = await Signal(_steam, "item_created")
		if int(reply[0]) != RESULT_OK:
			_finish(false, "Steam couldn't create the item (error %d)." % int(reply[0]))
			return
		item_id = int(reply[1])
		pack.metadata[METADATA_KEY] = item_record(item_id, steam_id)
		PackDataLoader.save_metadata(pack.folder_path, pack.metadata, pack.tags)

	var content := stage_pack(pack.folder_path, STAGING_PATH)
	if content.is_empty():
		_finish(false, "Couldn't read the pack's files.")
		return

	var handle := int(_steam.call("startItemUpdate", APP_ID, item_id))
	_steam.call("setItemTitle", handle, _display_name(pack).left(128))
	_steam.call("setItemTags", handle, pack.tags, false)
	_steam.call("setItemContent", handle, ProjectSettings.globalize_path(content))
	var preview: String = pack.backs[0].get_meta(PackDataLoader.SOURCE_META, "")
	if not preview.is_empty():
		_steam.call("setItemPreview", handle, ProjectSettings.globalize_path(preview))
	if created:
		# Left alone on updates, so edits made on the Workshop page stick.
		_steam.call("setItemDescription", handle, _description(pack))
		_steam.call("setItemVisibility", handle, VISIBILITY_PUBLIC)

	self.publish_progress.emit("Uploading...")
	var updated: Array = []
	var on_updated := func(result: int, needs_agreement: bool, _file_id: int) -> void:
		updated.assign([result, needs_agreement])
	_steam.connect("item_updated", on_updated, CONNECT_ONE_SHOT)
	_steam.call("submitItemUpdate", handle, "Published from the mod manager")

	while updated.is_empty():
		await get_tree().process_frame
		var progress: Variant = _steam.call("getItemUpdateProgress", handle)
		if progress is Dictionary and int(progress.get("total", 0)) > 0:
			var percent := 100 * int(progress["processed"]) / int(progress["total"])
			self.publish_progress.emit("Uploading... %d%%" % percent)

	ModsSync.clear(STAGING_PATH)
	if int(updated[0]) != RESULT_OK:
		_finish(false, "Steam rejected the upload (error %d)." % int(updated[0]))
		return

	# Steam keeps a new author's items hidden until they accept the Workshop
	# agreement, which is on the item's page.
	_steam.call("activateGameOverlayToWebPage", ITEM_URL % item_id, 0)
	if bool(updated[1]):
		_finish(true, "Published - accept the Workshop agreement on its page to make it public.")
	else:
		_finish(true, "Published to the Workshop.")


func _finish(succeeded: bool, message: String) -> void:
	_publishing = false
	self.publish_finished.emit(succeeded, message)


func _display_name(pack: PackData) -> String:
	var recorded = pack.metadata.get("name")
	return recorded if recorded is String and not recorded.is_empty() else pack.title


func _description(pack: PackData) -> String:
	PackDataLoader.load_faces(pack)
	var lines := [
		"A challenge pack for The Pyramid: Definitive Edition.",
		"%d primary · %d secondary" % [pack.primaries.size(), pack.secondaries.size()],
	]
	if not pack.tags.is_empty():
		lines.append("Categories: %s" % ", ".join(pack.tags))
	return "\n".join(lines)
