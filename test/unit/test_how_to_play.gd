extends GutTest

# Tests the "How to play" cards: each screen's card has real tips, shows its page,
# is remembered once dismissed, and comes back when the player asks for them
# again in settings.

const HOW_TO_PLAY: PackedScene = preload("res://source/menus/how_to_play/how_to_play.tscn")
const PAGES: Array[String] = [
	"res://source/menus/how_to_play/pages/draft.tres",
	"res://source/menus/how_to_play/pages/table.tres",
	"res://source/menus/how_to_play/pages/library.tres",
]
const SCREENS: Dictionary = {
	"res://source/menus/pack_select.tscn": &"draft",
	"res://source/game/game.tscn": &"table",
	"res://source/menus/library.tscn": &"library",
}

var _saved_seen: Array[String] = []


func before_each() -> void:
	_saved_seen = UserSettingsManager.how_to_play_seen.duplicate()


func after_each() -> void:
	UserSettingsManager.how_to_play_seen.assign(_saved_seen)
	UserSettingsManager._save_config()


func _card(page_path: String) -> HowToPlay:
	var card := HOW_TO_PLAY.instantiate() as HowToPlay
	card.page = load(page_path)
	add_child_autofree(card)
	return card


func test_every_page_has_a_title_and_tips() -> void:
	var ids := {}
	for path in PAGES:
		var page: HowToPlayPage = load(path)
		assert_false(String(page.id).is_empty(), "%s has an id" % path)
		assert_false(page.title.is_empty(), "%s has a title" % path)
		assert_gt(page.tips.size(), 1, "%s has tips" % path)
		ids[page.id] = true
	assert_eq(ids.size(), PAGES.size(), "ids are distinct, so each is remembered on its own")


func test_each_screen_carries_its_card() -> void:
	for scene_path in SCREENS:
		var scene: PackedScene = load(scene_path)
		var state := scene.get_state()
		var found := false
		for i in range(state.get_node_count()):
			if state.get_node_name(i) == "HowToPlay":
				for p in range(state.get_node_property_count(i)):
					if state.get_node_property_name(i, p) == "page":
						var page: HowToPlayPage = state.get_node_property_value(i, p)
						found = page.id == SCREENS[scene_path]
		assert_true(found, "%s shows the %s card" % [scene_path, SCREENS[scene_path]])


func test_the_card_shows_its_page() -> void:
	var card := _card(PAGES[1])
	await get_tree().process_frame

	card.show_page()

	assert_true(card.visible)
	assert_eq(card._title.text, "The Table")
	assert_eq(card._tips.get_child_count(), card.page.tips.size(), "one line per tip")
	assert_string_contains(card._tips.get_child(1).text, "press F over a card")


func test_dismissing_remembers_it_and_settings_bring_it_back() -> void:
	UserSettingsManager.reset_how_to_play()
	var card := _card(PAGES[0])
	await get_tree().process_frame
	assert_false(UserSettingsManager.has_seen_how_to_play("draft"), "new to this player")

	card.show_page()
	card._got_it.pressed.emit()

	assert_false(card.visible, "Got it puts it away")
	assert_true(UserSettingsManager.has_seen_how_to_play("draft"), "and it's remembered")
	var config := ConfigFile.new()
	config.load(UserSettingsManager.SAVE_PATH)
	assert_eq(config.get_value("how_to_play", "seen", []), ["draft"], "across restarts")

	UserSettingsManager.reset_how_to_play()
	assert_false(UserSettingsManager.has_seen_how_to_play("draft"), "settings bring it back")


func test_the_settings_button_brings_the_cards_back() -> void:
	UserSettingsManager.mark_how_to_play_seen("table")
	var menu := (load("res://source/menus/pause_menu.tscn") as PackedScene).instantiate()
	add_child_autofree(menu)
	await get_tree().process_frame

	menu._show_tips_again.pressed.emit()

	assert_false(UserSettingsManager.has_seen_how_to_play("table"))
	assert_true(menu._show_tips_again.disabled, "and says so")


func test_tests_and_tools_never_get_a_card() -> void:
	UserSettingsManager.reset_how_to_play()
	var card := _card(PAGES[2])

	assert_false(card.is_new(), "headless runs skip the card")
	card.show_if_new()
	await get_tree().create_timer(HowToPlay.ARRIVAL_DELAY + 0.1).timeout
	assert_false(card.visible, "so arriving shows nothing")
