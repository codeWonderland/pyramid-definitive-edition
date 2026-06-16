extends GutTest

# Tests for source/mod-manager Helpers.delete_recursive() (submodule code,
# exercised here because the parent project is where it actually runs).

var _root: String


func before_each() -> void:
	_root = "user://test_delrec_%d" % randi()


func after_each() -> void:
	var dir = DirAccess.open(_root)
	if dir:
		Helpers.delete_recursive(dir)


func test_deletes_nested_tree() -> void:
	DirAccess.make_dir_recursive_absolute(_root + "/sub/deeper")

	var f := FileAccess.open(_root + "/top.txt", FileAccess.WRITE)
	f.store_string("hi")
	f.close()
	var f2 := FileAccess.open(_root + "/sub/deeper/leaf.txt", FileAccess.WRITE)
	f2.store_string("bye")
	f2.close()

	assert_true(DirAccess.dir_exists_absolute(_root), "tree exists before delete")

	Helpers.delete_recursive(DirAccess.open(_root))

	assert_false(DirAccess.dir_exists_absolute(_root), "whole tree removed, including root")


func test_handles_empty_directory() -> void:
	DirAccess.make_dir_recursive_absolute(_root)

	Helpers.delete_recursive(DirAccess.open(_root))

	assert_false(DirAccess.dir_exists_absolute(_root), "empty directory removed")
