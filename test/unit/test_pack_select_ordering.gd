extends GutTest

# Tests the draft grid's sort (A-Z / Z-A) + filter (All / Favorites) ordering,
# including favorites floating to the top.

const PACK_SELECT_PACKS: PackedScene = preload(
	"res://source/menus/menu_widgets/pack_select_packs.tscn"
)
const TITLES: Array = ["Apple", "Banana", "Cherry"]

var _saved_all_packs: Array[PackData]


func _texture() -> ImageTexture:
	var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	return ImageTexture.create_from_image(img)


func _path(title: String) -> String:
	return "user://__test_order_%s" % title


func _pack(title: String) -> PackData:
	var pack := PackData.new()
	pack.title = title
	pack.folder_path = _path(title)
	var backs: Array[ImageTexture] = [_texture()]
	pack.backs = backs
	return pack


func before_each() -> void:
	_saved_all_packs = PacksManager.all_packs
	var packs: Array[PackData] = [_pack("Apple"), _pack("Banana"), _pack("Cherry")]
	PacksManager.all_packs = packs


func after_each() -> void:
	PacksManager.all_packs = _saved_all_packs
	for title in TITLES:
		if FavoritesManager.is_favorite(_path(title)):
			FavoritesManager.toggle(_path(title))


func _titles(packs: Array) -> Array:
	var out: Array = []
	for pack in packs:
		out.append(pack.title)
	return out


func _make_grid() -> PackSelectPacks:
	var grid := PACK_SELECT_PACKS.instantiate() as PackSelectPacks
	add_child_autofree(grid)
	return grid


func test_sort_ascending_and_descending() -> void:
	var grid := _make_grid()
	await get_tree().process_frame

	grid.set_sort_ascending(true)
	assert_eq(_titles(grid._ordered_packs()), ["Apple", "Banana", "Cherry"], "A-Z order")

	grid.set_sort_ascending(false)
	assert_eq(_titles(grid._ordered_packs()), ["Cherry", "Banana", "Apple"], "Z-A order")


func test_favorites_float_to_top() -> void:
	FavoritesManager.toggle(_path("Banana"))
	var grid := _make_grid()
	await get_tree().process_frame

	grid.set_sort_ascending(true)
	assert_eq(
		_titles(grid._ordered_packs()), ["Banana", "Apple", "Cherry"], "favorite floats to top"
	)


func test_favorites_only_filter() -> void:
	FavoritesManager.toggle(_path("Cherry"))
	var grid := _make_grid()
	await get_tree().process_frame

	grid.set_favorites_only(true)
	assert_eq(_titles(grid._ordered_packs()), ["Cherry"], "only favorites shown")
