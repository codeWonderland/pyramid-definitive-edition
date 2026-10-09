extends GutTest

# Tests the shared entrance motion (#16): things arrive one after another and end
# exactly where and how they belong; a card grabbed mid-drop stops at once; and
# scene changes fade, ignoring a second change while one is under way.

const PACK_SELECT_PACKS: PackedScene = preload(
	"res://source/menus/menu_widgets/pack_select_packs.tscn"
)


func _controls(count: int) -> Array:
	var out: Array = []
	for i in range(count):
		var control := Control.new()
		control.custom_minimum_size = Vector2(40, 60)
		control.position = Vector2(10 * i, 100)
		add_child_autofree(control)
		out.append(control)
	return out


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func test_rising_in_starts_hidden_and_ends_as_laid_out() -> void:
	var controls := _controls(3)

	Motion.rise_in(controls)

	assert_eq(controls[0].modulate.a, 0.0, "starts hidden")
	assert_eq(controls[0].pivot_offset, Vector2(20, 30), "grows from its centre")
	await _wait(Motion.TIME + Motion.STAGGER * 3 + 0.1)
	for control in controls:
		assert_eq(control.modulate.a, 1.0, "fully shown")
		assert_eq(control.scale, Vector2.ONE, "full size")


func test_rising_in_is_staggered() -> void:
	var controls := _controls(3)

	Motion.rise_in(controls)
	await _wait(Motion.TIME * 0.5)

	assert_gt(controls[0].modulate.a, controls[2].modulate.a, "the first is ahead of the last")


func test_dropping_in_lands_where_it_was() -> void:
	var controls := _controls(2)

	Motion.drop_in(controls)

	assert_eq(controls[0].position, Vector2(0, 100 - Motion.DROP_HEIGHT), "starts above")
	await _wait(Motion.TIME + Motion.STAGGER * 2 + 0.1)
	assert_eq(controls[0].position, Vector2(0, 100), "lands on its spot")
	assert_eq(controls[1].position, Vector2(10, 100))
	assert_eq(controls[1].modulate.a, 1.0)


func test_a_card_grabbed_mid_drop_stays_with_the_player() -> void:
	var control: Control = _controls(1)[0]
	Motion.drop_in([control], 0.0)
	await _wait(Motion.TIME * 0.3)

	Motion.settle(control)
	control.position = Vector2(500, 500)
	await _wait(Motion.TIME)

	assert_eq(control.position, Vector2(500, 500), "the drop no longer moves it")
	assert_eq(control.modulate.a, 1.0, "and it's fully shown")
	Motion.settle(control)


func _packs(count: int) -> Array[PackData]:
	var packs: Array[PackData] = []
	var texture := ImageTexture.create_from_image(Image.create(4, 4, false, Image.FORMAT_RGBA8))
	for i in range(count):
		var pack := PackData.new()
		pack.title = "pack %d" % i
		pack.folder_path = "user://__test_motion_%d" % i
		pack.backs.append(texture)
		packs.append(pack)
	return packs


func test_the_draft_grid_rises_in_on_first_load_only() -> void:
	var saved := PacksManager.all_packs
	PacksManager.all_packs = _packs(4)
	var grid := PACK_SELECT_PACKS.instantiate() as PackSelectPacks
	add_child_autofree(grid)
	await get_tree().process_frame
	PacksManager.all_packs = saved
	assert_eq(grid.get_child_count(), 4, "the page is built")
	var first: Control = grid.get_child(0)
	assert_lt(first.modulate.a, 1.0, "the first page arrives")

	PacksManager.all_packs = _packs(4)
	grid.set_search_query("")
	PacksManager.all_packs = saved
	await get_tree().process_frame
	var rebuilt: Control = grid.get_child(grid.get_child_count() - 1)
	assert_eq(rebuilt.modulate.a, 1.0, "a search doesn't replay it")


func test_scene_changes_ignore_nothing_and_start_idle() -> void:
	assert_false(SceneTransition.is_changing(), "idle")
	SceneTransition.change_scene_to_packed(null)
	assert_false(SceneTransition.is_changing(), "nothing to change to, nothing happens")
	assert_false(SceneTransition._fade.visible, "and nothing is covered")
