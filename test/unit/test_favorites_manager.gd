extends GutTest

# Tests for the FavoritesManager autoload (toggle, query, persistence).

const FAKE_PATH: String = "user://__test_fake_favorite_pack__"


func after_each() -> void:
	# Leave the real favorites store as we found it.
	if FavoritesManager.is_favorite(FAKE_PATH):
		FavoritesManager.toggle(FAKE_PATH)


func test_toggle_adds_and_removes() -> void:
	assert_false(FavoritesManager.is_favorite(FAKE_PATH), "not favorited to start")

	FavoritesManager.toggle(FAKE_PATH)
	assert_true(FavoritesManager.is_favorite(FAKE_PATH), "favorited after first toggle")

	FavoritesManager.toggle(FAKE_PATH)
	assert_false(FavoritesManager.is_favorite(FAKE_PATH), "un-favorited after second toggle")


func test_toggle_emits_favorites_changed() -> void:
	watch_signals(FavoritesManager)
	FavoritesManager.toggle(FAKE_PATH)
	assert_signal_emitted(FavoritesManager, "favorites_changed")


func test_favorite_persists_to_disk() -> void:
	FavoritesManager.toggle(FAKE_PATH)

	var config := ConfigFile.new()
	assert_eq(config.load(FavoritesManager.SAVE_PATH), OK, "favorites file written")
	var paths: Array = config.get_value("favorites", "paths", [])
	assert_true(paths.has(FAKE_PATH), "favorite persisted to disk")
