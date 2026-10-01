extends SceneTree

## Writes ModsSync.BUNDLED_MANIFEST_PATH from the initial_mods/pyramid-mods
## submodule's checked-out commit. Run after moving that submodule, before a build:
##
##     godot --headless -s tools/update_bundled_mods_manifest.gd
##
## Needs git, which only this tool does - the game itself never runs git.

const SUBMODULE: String = "initial_mods/pyramid-mods"


func _init() -> void:
	var manifest := from_git(ProjectSettings.globalize_path("res://" + SUBMODULE))
	if manifest.is_empty():
		printerr("Couldn't read %s with git" % SUBMODULE)
		quit(1)
		return

	if not ModsSync.write_manifest(ModsSync.BUNDLED_MANIFEST_PATH, manifest):
		quit(1)
		return

	print("Wrote %d files at %s" % [manifest["files"].size(), manifest["commit"]])
	quit()


## The manifest of the commit checked out in the git repo at `repo`, or {}.
static func from_git(repo: String) -> Dictionary:
	var head := _git(repo, ["log", "-1", "--format=%H %ct"]).strip_edges().split(" ")
	if head.size() != 2:
		return {}

	var files := {}
	# quotePath off leaves spaces, apostrophes and accents as they are; git still
	# quotes a path holding a double quote, backslash or control character.
	var listing := _git(repo, ["-c", "core.quotePath=false", "ls-tree", "-r", "HEAD"])
	for line in listing.split("\n", false):
		# "<mode> blob <hash>\t<path>"
		var fields := line.split("\t", true, 1)
		var meta := fields[0].split(" ")
		if fields.size() != 2 or meta.size() != 3 or meta[1] != "blob":
			continue
		if fields[1].begins_with('"'):
			printerr("Rename %s - quotes and backslashes aren't supported in paths" % fields[1])
			return {}
		if ModsSync.is_content_path(fields[1]):
			files[fields[1]] = meta[2]

	return {"commit": head[0], "time": int(head[1]), "files": files}


static func _git(repo: String, args: Array) -> String:
	var output := []
	if OS.execute("git", ["-C", repo] + args, output) != 0 or output.is_empty():
		return ""
	return output[0]
