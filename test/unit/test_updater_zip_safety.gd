extends GutTest

# Tests for the zip-slip guard in Updater._is_safe_zip_entry(). A malicious or
# corrupt archive must not be able to write outside the extraction directory.

var _updater: Updater


func before_each() -> void:
	# Instantiate the script directly; we only exercise pure path logic and never
	# enter the tree, so the @onready node references stay untouched.
	_updater = Updater.new()


func after_each() -> void:
	_updater.free()


func test_accepts_normal_nested_entries() -> void:
	assert_true(_updater._is_safe_zip_entry("pyramid-mods-main/word_bank.json"))
	assert_true(_updater._is_safe_zip_entry("pyramid-mods-main/PACKS/Cool/b1.png"))
	assert_true(_updater._is_safe_zip_entry("pyramid-mods-main/"))


func test_rejects_parent_traversal() -> void:
	assert_false(_updater._is_safe_zip_entry("../evil.cfg"))
	assert_false(_updater._is_safe_zip_entry("pyramid-mods-main/../../settings.cfg"))
	assert_false(_updater._is_safe_zip_entry("a/../../b"))


func test_rejects_absolute_paths() -> void:
	assert_false(_updater._is_safe_zip_entry("/etc/passwd"))
	assert_false(_updater._is_safe_zip_entry("C:/Windows/system32"))


func test_rejects_backslash_traversal() -> void:
	assert_false(_updater._is_safe_zip_entry("foo\\..\\bar"))
