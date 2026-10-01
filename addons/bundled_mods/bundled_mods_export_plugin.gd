@tool
extends EditorExportPlugin

## Puts the official mods (initial_mods/pyramid-mods) and their manifest into every
## export. initial_mods/ is .gdignore'd so Godot never imports thousands of card
## images - which also means the exporter can't see them, so they're added here as
## raw files, at the same res:// paths the game reads them from.
##
## The manifest has to describe exactly these files, or a player's install would
## be recorded as a version it isn't. A stale one is an error and nothing is
## bundled; regenerate it with tools/update_bundled_mods_manifest.gd.

const MODS_ROOT: String = "res://initial_mods/pyramid-mods"
const MANIFEST_PATH: String = "res://initial_mods/pyramid-mods.json"


func _get_name() -> String:
	return "BundledMods"


func _export_begin(
	_features: PackedStringArray, _is_debug: bool, _path: String, _flags: int
) -> void:
	var manifest := ModsSync.read_manifest(MANIFEST_PATH)
	var files := ModsSync.hash_folder(MODS_ROOT)

	if manifest.is_empty() or files.is_empty():
		push_error(
			"Bundled mods: no mods or manifest in initial_mods/ - is the submodule checked out?"
		)
		return
	if files != manifest["files"]:
		push_error(
			(
				(
					"Bundled mods: %s doesn't match initial_mods/pyramid-mods - run "
					+ "`godot --headless -s tools/update_bundled_mods_manifest.gd`. Not bundling."
				)
				% MANIFEST_PATH
			)
		)
		return

	add_file(MANIFEST_PATH, FileAccess.get_file_as_bytes(MANIFEST_PATH), false)
	for path in files:
		var full := MODS_ROOT.path_join(path)
		add_file(full, FileAccess.get_file_as_bytes(full), false)

	print("Bundled mods: packed %d files from %s" % [files.size(), manifest["commit"]])
