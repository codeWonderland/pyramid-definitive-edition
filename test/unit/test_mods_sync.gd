extends GutTest

# Tests ModsSync, which updates the installed official mods by touching only the
# files that changed - from the mods bundled with the game, or from GitHub - and
# the bundled manifest that makes that possible.

const MANIFEST_TOOL: GDScript = preload("res://tools/update_bundled_mods_manifest.gd")

var _root: String


func before_each() -> void:
	_root = "user://test_mods_sync_%d" % randi()
	DirAccess.make_dir_recursive_absolute(_root)


func after_each() -> void:
	ModsSync.clear(_root)


func _put(folder: String, path: String, text: String) -> void:
	var full := _root.path_join(folder).path_join(path)
	DirAccess.make_dir_recursive_absolute(full.get_base_dir())
	var file := FileAccess.open(full, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _read(folder: String, path: String) -> String:
	return FileAccess.get_file_as_string(_root.path_join(folder).path_join(path))


func _hash(text: String) -> String:
	return ModsSync.blob_hash(text.to_utf8_buffer())


func _paths(paths: Array) -> Array[String]:
	var out: Array[String] = []
	out.assign(paths)
	return out


# --- Hashing ---


func test_hashes_match_git() -> void:
	# `printf 'hello\n' | git hash-object --stdin`
	assert_eq(_hash("hello\n"), "ce013625030ba8dba906f756967f9e9ca394464a")
	assert_eq(ModsSync.blob_hash(PackedByteArray()), "e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")


func test_only_mod_content_is_synced() -> void:
	assert_true(ModsSync.is_content_path("PACKS/a to z/p1.png"))
	assert_true(ModsSync.is_content_path("PACKS/darkest dungeon - butcher's circus/b1.png"))
	assert_false(ModsSync.is_content_path(".github/workflows/x.yml"), "repo housekeeping")
	assert_false(ModsSync.is_content_path("PACKS/.DS_Store"), "dotfiles")
	assert_false(ModsSync.is_content_path("PACKS/x/p1.png.import"), "import sidecars")
	assert_false(ModsSync.is_content_path("PACKS/../../escape.png"), "no climbing out")


func test_a_folder_hashes_like_git() -> void:
	_put("mods", "PACKS/x/p1.png", "one")
	_put("mods", "word_bank.json", "{}")
	_put("mods", ".github/ci.yml", "skip me")

	assert_eq(
		ModsSync.hash_folder(_root.path_join("mods")),
		{"PACKS/x/p1.png": _hash("one"), "word_bank.json": _hash("{}")}
	)


# --- Manifests ---


func test_a_github_tree_becomes_a_manifest() -> void:
	var tree := {
		"truncated": false,
		"tree":
		[
			{"path": "PACKS", "type": "tree", "sha": "t1"},
			{"path": "PACKS/x/p1.png", "type": "blob", "sha": "aaa"},
			{"path": ".github/ci.yml", "type": "blob", "sha": "bbb"},
		]
	}

	assert_eq(
		ModsSync.manifest_from_tree(tree, "abc", 5),
		{"commit": "abc", "time": 5, "files": {"PACKS/x/p1.png": "aaa"}}
	)
	tree["truncated"] = true
	assert_eq(ModsSync.manifest_from_tree(tree, "abc", 5), {}, "a partial listing isn't used")
	assert_eq(ModsSync.manifest_from_tree("nope", "abc", 5), {}, "nor is junk")


func test_manifests_round_trip_with_whole_number_times() -> void:
	var path := _root.path_join("manifest.json")
	var manifest := {"commit": "abc", "time": 1790723672, "files": {"a.png": "aaa"}}

	assert_true(ModsSync.write_manifest(path, manifest))
	assert_eq(ModsSync.read_manifest(path), manifest)
	assert_typeof(ModsSync.read_manifest(path)["time"], TYPE_INT)


func test_a_missing_or_broken_manifest_reads_as_empty() -> void:
	assert_eq(ModsSync.read_manifest(_root.path_join("missing.json")), {})
	_put("", "broken.json", '{"commit": 3}')
	assert_eq(ModsSync.read_manifest(_root.path_join("broken.json")), {})
	assert_push_warning("not a valid manifest")


func test_only_a_later_different_version_is_newer() -> void:
	var old := {"commit": "a", "time": 100}
	var new := {"commit": "b", "time": 200}

	assert_true(ModsSync.is_newer(new, old))
	assert_false(ModsSync.is_newer(old, new), "an older bundle doesn't undo a download")
	assert_false(ModsSync.is_newer(new, new), "same version")
	assert_true(ModsSync.is_newer(new, {"commit": "", "time": 0}), "beats an unrecorded install")
	assert_false(ModsSync.is_newer({}, old), "no bundled manifest, nothing to apply")


func test_changes_are_what_differs() -> void:
	var installed := {"same": "1", "edited": "2", "gone": "3"}
	var target := {"same": "1", "edited": "9", "added": "4"}

	assert_eq(
		ModsSync.changes(installed, target), {"fetch": ["added", "edited"], "remove": ["gone"]}
	)


# --- Staging and applying ---


func test_staging_only_takes_files_with_the_wanted_contents() -> void:
	_put("bundle", "PACKS/x/p1.png", "new")
	_put("bundle", "PACKS/x/p2.png", "stale")
	var target := {
		"PACKS/x/p1.png": _hash("new"),
		"PACKS/x/p2.png": _hash("fresh"),
		"PACKS/x/p3.png": _hash("other"),
	}

	var missing := ModsSync.stage_from_folder(
		_root.path_join("bundle"), _root.path_join("stage"), _paths(target.keys()), target
	)

	assert_eq(missing, _paths(["PACKS/x/p2.png", "PACKS/x/p3.png"]), "wrong or absent")
	assert_eq(_read("stage", "PACKS/x/p1.png"), "new", "the match was staged")
	assert_false(FileAccess.file_exists(_root.path_join("stage/PACKS/x/p2.png")))


func test_a_bad_download_is_caught_before_it_is_applied() -> void:
	_put("stage", "a.png", "truncated")

	assert_false(
		ModsSync.staged_correctly(
			_root.path_join("stage"), _paths(["a.png"]), {"a.png": _hash("whole")}
		)
	)
	assert_false(
		ModsSync.staged_correctly(_root.path_join("stage"), _paths(["b.png"]), {"b.png": "x"})
	)
	assert_true(
		ModsSync.staged_correctly(
			_root.path_join("stage"), _paths(["a.png"]), {"a.png": _hash("truncated")}
		)
	)


func test_applying_replaces_adds_and_removes_only_whats_listed() -> void:
	_put("mods", "PACKS/keep/p1.png", "keep")
	_put("mods", "PACKS/keep/p2.png", "old")
	_put("mods", "PACKS/dropped/b1.png", "bye")
	_put("stage", "PACKS/keep/p2.png", "new")
	_put("stage", "PACKS/added/b1.png", "hi")

	ModsSync.apply_staged(
		_root.path_join("stage"),
		_root.path_join("mods"),
		_paths(["PACKS/keep/p2.png", "PACKS/added/b1.png"]),
		_paths(["PACKS/dropped/b1.png"])
	)

	assert_eq(_read("mods", "PACKS/keep/p1.png"), "keep", "untouched")
	assert_eq(_read("mods", "PACKS/keep/p2.png"), "new", "replaced")
	assert_eq(_read("mods", "PACKS/added/b1.png"), "hi", "added")
	assert_false(
		DirAccess.dir_exists_absolute(_root.path_join("mods/PACKS/dropped")), "emptied pack gone"
	)
	assert_true(DirAccess.dir_exists_absolute(_root.path_join("mods/PACKS")), "its parent stays")


func test_syncing_from_a_bundle_moves_an_install_to_its_version() -> void:
	_put("mods", "PACKS/x/p1.png", "same")
	_put("mods", "PACKS/x/p2.png", "old")
	_put("mods", "PACKS/y/b1.png", "removed upstream")
	_put("bundle", "PACKS/x/p1.png", "same")
	_put("bundle", "PACKS/x/p2.png", "new")
	_put("bundle", "PACKS/z/b1.png", "added")
	var installed := {
		"commit": "a", "time": 1, "files": ModsSync.hash_folder(_root.path_join("mods"))
	}
	var bundled := {
		"commit": "b", "time": 2, "files": ModsSync.hash_folder(_root.path_join("bundle"))
	}

	var applied := ModsSync.sync_from_folder(
		_root.path_join("bundle"),
		_root.path_join("mods"),
		_root.path_join("stage"),
		installed,
		bundled
	)

	assert_true(applied)
	assert_eq(
		ModsSync.hash_folder(_root.path_join("mods")), bundled["files"], "now matches the bundle"
	)
	assert_false(DirAccess.dir_exists_absolute(_root.path_join("stage")), "staging cleaned up")


func test_a_bundle_missing_files_leaves_the_install_alone() -> void:
	_put("mods", "PACKS/x/p1.png", "old")
	_put("bundle", "PACKS/x/p1.png", "new")
	var installed := {
		"commit": "a", "time": 1, "files": ModsSync.hash_folder(_root.path_join("mods"))
	}
	var bundled := {
		"commit": "b",
		"time": 2,
		"files": {"PACKS/x/p1.png": _hash("new"), "PACKS/x/p2.png": _hash("not shipped")},
	}

	var applied := ModsSync.sync_from_folder(
		_root.path_join("bundle"),
		_root.path_join("mods"),
		_root.path_join("stage"),
		installed,
		bundled
	)

	assert_false(applied)
	assert_eq(_read("mods", "PACKS/x/p1.png"), "old", "nothing half-applied")
	assert_push_warning("missing 1 files")


func test_urls_escape_each_folder_but_keep_the_slashes() -> void:
	assert_eq(
		ModsSync.url_path("PACKS/darkest dungeon - butcher's circus/b1.png"),
		"PACKS/darkest%20dungeon%20-%20butcher%27s%20circus/b1.png"
	)


# --- The bundled manifest ---


func _git_available() -> bool:
	return OS.execute("git", ["-C", ProjectSettings.globalize_path("res://"), "rev-parse"]) == 0


func test_the_bundled_manifest_matches_the_bundled_mods() -> void:
	if not _git_available():
		pass_test("needs git and a checkout to compare against")
		return

	var bundled := ModsSync.read_manifest(ModsSync.BUNDLED_MANIFEST_PATH)
	var actual: Dictionary = MANIFEST_TOOL.from_git(
		ProjectSettings.globalize_path("res://initial_mods/pyramid-mods")
	)

	assert_false(actual.is_empty(), "the submodule is checked out")
	assert_eq(
		bundled.get("commit"),
		actual.get("commit"),
		(
			"initial_mods/pyramid-mods moved - run "
			+ "`godot --headless -s tools/update_bundled_mods_manifest.gd`"
		)
	)
	assert_eq(bundled.get("time"), actual.get("time"), "same commit time")
	assert_eq(bundled.get("files"), actual.get("files"), "same files")


func test_the_bundled_files_hash_to_the_manifest() -> void:
	# What the game actually reads, not what git says - so a sync from the bundle
	# can trust it.
	var bundled := ModsSync.read_manifest(ModsSync.BUNDLED_MANIFEST_PATH)

	assert_eq(ModsSync.hash_folder("res://initial_mods/pyramid-mods"), bundled.get("files"))
