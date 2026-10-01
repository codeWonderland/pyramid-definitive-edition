class_name ModsSync extends RefCounted

## Brings the installed official mods up to a newer version - the mods bundled with
## the game, or the latest on GitHub - by touching only the files that differ.
##
## A version is described by a manifest: {"commit": sha, "time": unix seconds,
## "files": {path: hash}}, paths relative to the mods root. Hashes are git blob
## hashes, the same ones GitHub's tree API lists, so installed, bundled and remote
## files compare without downloading anything - and without git installed.

## Manifest of the mods bundled with the game. Regenerate it with
## `godot --headless -s tools/update_bundled_mods_manifest.gd` whenever the
## initial_mods/pyramid-mods submodule moves; a test fails if it's stale.
const BUNDLED_MANIFEST_PATH: String = "res://initial_mods/pyramid-mods.json"
## Manifest of what's installed in user://mods/pyramid-mods-main/.
const INSTALLED_MANIFEST_PATH: String = "user://mods/pyramid-mods-main.json"


## A file's git blob hash: SHA-1 over "blob <size>\0" and the contents.
static func blob_hash(bytes: PackedByteArray) -> String:
	var header := ("blob %d" % bytes.size()).to_utf8_buffer()
	header.append(0)

	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA1)
	hashing.update(header)
	if not bytes.is_empty():
		hashing.update(bytes)
	return hashing.finish().hex_encode()


## Whether a path is mod content rather than repo housekeeping (.github, dotfiles)
## or a Godot import sidecar. Only content is compared and synced.
static func is_content_path(path: String) -> bool:
	if path.ends_with(".import"):
		return false
	for segment in path.split("/"):
		if segment.is_empty() or segment.begins_with(".") or segment == "..":
			return false
	return true


## Hashes every content file under `root`, for an install with no manifest.
static func hash_folder(root: String) -> Dictionary:
	var files := {}
	_hash_into(root.trim_suffix("/"), "", files)
	return files


static func _hash_into(root: String, relative: String, files: Dictionary) -> void:
	var folder := root if relative.is_empty() else root.path_join(relative)
	var dir := DirAccess.open(folder)
	if dir == null:
		return

	for file_name in dir.get_files():
		var path := file_name if relative.is_empty() else relative.path_join(file_name)
		if is_content_path(path):
			files[path] = blob_hash(FileAccess.get_file_as_bytes(folder.path_join(file_name)))

	for sub in dir.get_directories():
		var path := sub if relative.is_empty() else relative.path_join(sub)
		if is_content_path(path):
			_hash_into(root, path, files)


## Reads a manifest file, or {} if it's missing or malformed.
static func read_manifest(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}

	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (
		data is Dictionary and data.get("commit") is String and data.get("files") is Dictionary
	):
		push_warning("ModsSync: %s is not a valid manifest" % path)
		return {}

	var time = data.get("time")
	data["time"] = int(time) if time is float or time is int else 0
	return data


static func write_manifest(path: String, manifest: Dictionary) -> bool:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("ModsSync: couldn't write %s" % path)
		return false

	file.store_string(JSON.stringify(manifest, "\t", true) + "\n")
	file.close()
	return true


## The manifest for a GitHub tree API response (`git/trees/<sha>?recursive=1`),
## or {} if the response is unusable or truncated (too big to list in one go).
static func manifest_from_tree(tree: Variant, commit: String, time: int) -> Dictionary:
	if not (tree is Dictionary and tree.get("tree") is Array) or tree.get("truncated") == true:
		return {}

	var files := {}
	for entry in tree["tree"]:
		if not (entry is Dictionary and entry.get("type") == "blob"):
			continue
		var path = entry.get("path")
		var sha = entry.get("sha")
		if path is String and sha is String and is_content_path(path):
			files[path] = sha

	return {"commit": commit, "time": time, "files": files}


## Whether `candidate` is a later version than `current`. A version with no time
## (an install from before manifests) counts as the oldest.
static func is_newer(candidate: Dictionary, current: Dictionary) -> bool:
	if candidate.is_empty() or candidate.get("commit") == current.get("commit"):
		return false
	return int(candidate.get("time", 0)) > int(current.get("time", 0))


## What going from `installed` to `target` (both path -> hash) takes: the paths to
## fetch because they're new or changed, and the paths to remove.
static func changes(installed: Dictionary, target: Dictionary) -> Dictionary:
	var fetch: Array[String] = []
	var remove: Array[String] = []

	for path in target:
		if installed.get(path) != target[path]:
			fetch.append(path)
	for path in installed:
		if not target.has(path):
			remove.append(path)

	fetch.sort()
	remove.sort()
	return {"fetch": fetch, "remove": remove}


## Copies each of `paths` from `source_root` into `stage_root`, but only where the
## source copy has the hash `target` wants. Returns the paths it couldn't supply,
## which still need downloading.
static func stage_from_folder(
	source_root: String, stage_root: String, paths: Array[String], target: Dictionary
) -> Array[String]:
	var missing: Array[String] = []

	for path in paths:
		var source := source_root.path_join(path)
		if not FileAccess.file_exists(source):
			missing.append(path)
			continue

		var bytes := FileAccess.get_file_as_bytes(source)
		if blob_hash(bytes) != target.get(path) or not _write(stage_root.path_join(path), bytes):
			missing.append(path)

	return missing


## Whether every one of `paths` is staged with the hash `target` wants, so a bad
## or cut-off download is never swapped in.
static func staged_correctly(stage_root: String, paths: Array[String], target: Dictionary) -> bool:
	for path in paths:
		var staged := stage_root.path_join(path)
		if not FileAccess.file_exists(staged):
			return false
		if blob_hash(FileAccess.get_file_as_bytes(staged)) != target.get(path):
			return false
	return true


## Moves the staged `fetched` files over the installed ones and deletes `removed`,
## then clears out folders that were left empty, such as a deleted pack's.
static func apply_staged(
	stage_root: String, dest_root: String, fetched: Array[String], removed: Array[String]
) -> void:
	for path in fetched:
		var dest := dest_root.path_join(path)
		DirAccess.make_dir_recursive_absolute(dest.get_base_dir())
		if FileAccess.file_exists(dest):
			DirAccess.remove_absolute(dest)
		DirAccess.rename_absolute(stage_root.path_join(path), dest)

	for path in removed:
		var dest := dest_root.path_join(path)
		if FileAccess.file_exists(dest):
			DirAccess.remove_absolute(dest)
		_remove_empty_parents(dest_root, path.get_base_dir())


static func _remove_empty_parents(root: String, relative: String) -> void:
	while not relative.is_empty() and relative != ".":
		var folder := root.path_join(relative)
		var dir := DirAccess.open(folder)
		if dir == null or not dir.get_files().is_empty() or not dir.get_directories().is_empty():
			return
		DirAccess.remove_absolute(folder)
		relative = relative.get_base_dir()


## Brings `dest_root` from `installed` to `target` using only files in
## `source_root`, staging through `stage_root` so nothing changes unless every
## needed file is there. Returns whether it applied.
static func sync_from_folder(
	source_root: String,
	dest_root: String,
	stage_root: String,
	installed: Dictionary,
	target: Dictionary
) -> bool:
	var plan := changes(installed.get("files", {}), target.get("files", {}))
	clear(stage_root)

	var missing := stage_from_folder(source_root, stage_root, plan["fetch"], target["files"])
	if not missing.is_empty():
		push_warning(
			"ModsSync: %s is missing %d files it should have" % [source_root, missing.size()]
		)
		clear(stage_root)
		return false

	apply_staged(stage_root, dest_root, plan["fetch"], plan["remove"])
	clear(stage_root)
	return true


## The raw.githubusercontent.com URL path for a repo path, each segment escaped
## (pack folders have spaces and apostrophes) but the separators kept.
static func url_path(path: String) -> String:
	var segments: Array[String] = []
	for segment in path.split("/"):
		segments.append(segment.uri_encode())
	return "/".join(segments)


static func clear(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir:
		Helpers.delete_recursive(dir)


static func _write(path: String, bytes: PackedByteArray) -> bool:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_buffer(bytes)
	file.close()
	return true
