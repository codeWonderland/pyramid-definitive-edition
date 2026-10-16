class_name Library extends Control

## Browse every game pack: a grid of packs on the left, and on the right what the
## mods record about the selected game, its cards, and the player's own marks.

const PACK_SELECT_CARD: PackedScene = preload(
	"res://source/menus/menu_widgets/pack_select_card.tscn"
)
# Sizes at the 1920x1080 reference; scaled to the window like the other screens.
const GRID_CARD_HEIGHT: float = 220.0
const THUMBNAIL_SIZE: Vector2 = Vector2(84, 120)

var _favorites_only: bool = false
## The widest mark label's natural width - the narrowest a mark tile can be.
var _marks_natural_width: float = 0.0
var _selected: PackData = null

@onready var _background: TextureRect = %Background
@onready var _back_button: TextureButton = %Back
@onready var _search: LineEdit = %Search
@onready var _favorites_button: Button = %FavoritesOnly
@onready var _grid: HFlowContainer = %Grid
@onready var _empty_grid_label: Label = %EmptyGridLabel
@onready var _placeholder: Label = %Placeholder
@onready var _details: VBoxContainer = %Details
@onready var _pack_name: Label = %PackName
@onready var _tag_chips: HFlowContainer = %TagChips
@onready var _pills: HFlowContainer = %Pills
@onready var _time_pill: PanelContainer = %TimePill
@onready var _play_time: Label = %PlayTime
@onready var _free_pill: PanelContainer = %FreePill
@onready var _rules_row: HBoxContainer = %RulesRow
@onready var _versus_tile: PanelContainer = %VersusTile
@onready var _versus_rule: Label = %VersusRule
@onready var _coop_tile: PanelContainer = %CoopTile
@onready var _coop_rule: Label = %CoopRule
@onready var _about_row: HBoxContainer = %AboutRow
@onready var _about_links: HBoxContainer = %AboutLinks
@onready var _store_link: Button = %StoreLink
@onready var _presskit_link: Button = %PresskitLink
@onready var _description_box: PanelContainer = %DescriptionBox
@onready var _description: Label = %Description
@onready var _marks: HFlowContainer = %Marks
@onready var _cards: VBoxContainer = %Cards
@onready var _card_inspector: CardInspector = %CardInspector
@onready var _how_to_play: HowToPlay = %HowToPlay


func _ready() -> void:
	_back_button.pressed.connect(_back)
	_search.text_changed.connect(func(_query: String) -> void: _build_grid())
	_favorites_button.pressed.connect(_toggle_favorites_only)
	FavoritesManager.favorites_changed.connect(_on_favorites_changed)
	PlayerMarksManager.marks_changed.connect(_on_marks_changed)
	_store_link.pressed.connect(_open_link.bind("store_url"))
	_presskit_link.pressed.connect(_open_link.bind("presskit_url"))

	get_tree().get_root().size_changed.connect(_resize)
	_marks.resized.connect(_fit_marks)

	_set_background()
	_update_favorites_label()
	_show_details(null)

	# Packs normally load on the way into a run; opening the library straight from
	# the main menu has to load them itself.
	if PacksManager.all_packs.is_empty():
		await PacksManager.load()

	_build_grid()
	_open_requested_pack()
	_how_to_play.show_if_new()


## How much smaller than the 1920x1080 reference the window is.
func _scale() -> float:
	var screen := get_viewport().get_visible_rect().size
	return minf(screen.x / 1920.0, screen.y / 1080.0)


func _resize() -> void:
	_build_grid()
	if _selected != null:
		_build_cards(_selected)


func _set_background() -> void:
	if BackgroundManager.backgrounds.has(UserSettingsManager.background):
		_background.texture = BackgroundManager.backgrounds[UserSettingsManager.background]


func _back() -> void:
	if _card_inspector.visible:
		return
	var destination: String = RunManager.library_return_scene
	RunManager.library_return_scene = ""
	if destination.is_empty():
		destination = "res://source/menus/main_menu.tscn"
	SceneTransition.change_scene_to_packed(load(destination))


## Opens the game another screen asked for (L over a game on the draft screen).
func _open_requested_pack() -> void:
	var wanted: String = RunManager.library_focus_path
	RunManager.library_focus_path = ""
	if wanted.is_empty():
		return
	for pack in PacksManager.all_packs:
		if pack.folder_path == wanted:
			_show_details(pack)
			return


# --- Grid ---


## Packs matching the search box and favourites toggle, A-Z like the draft screen.
func visible_packs() -> Array[PackData]:
	var packs: Array[PackData] = []
	for pack in PacksManager.all_packs:
		if _favorites_only and not FavoritesManager.is_favorite(pack.folder_path):
			continue
		if not FuzzyMatch.matches(_search.text, pack.title):
			continue
		packs.append(pack)
	return packs


func _build_grid() -> void:
	for child in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()

	var packs := visible_packs()
	_empty_grid_label.visible = packs.is_empty()

	for pack in packs:
		var card := PACK_SELECT_CARD.instantiate() as PackSelectCard
		card.custom_minimum_size = Vector2(0, GRID_CARD_HEIGHT * _scale())
		card.pack_data = pack
		card.tooltip_text = _display_name(pack)
		card.pressed.connect(_show_details)
		card.favorite_toggled.connect(
			func(p: PackData) -> void: FavoritesManager.toggle(p.folder_path)
		)
		_grid.add_child(card)


func _toggle_favorites_only() -> void:
	_favorites_only = not _favorites_only
	_update_favorites_label()
	_build_grid()


func _update_favorites_label() -> void:
	_favorites_button.text = "Showing: Favorites" if _favorites_only else "Showing: All"


func _on_favorites_changed() -> void:
	if _favorites_only:
		_build_grid()
	if _selected != null:
		_build_marks(_selected)


func _on_marks_changed(folder_path: String) -> void:
	if _selected != null and _selected.folder_path == folder_path:
		_build_marks(_selected)


# --- Details ---


func _show_details(pack: PackData) -> void:
	_selected = pack
	_placeholder.visible = pack == null
	_details.visible = pack != null
	if pack == null:
		return

	# The library lists packs with only their backs loaded.
	PackDataLoader.load_faces(pack)
	var record := pack.metadata
	_pack_name.text = _display_name(pack)
	_build_tag_chips(pack)

	_play_time.text = play_time(record)
	_time_pill.visible = not _play_time.text.is_empty()
	_free_pill.visible = record.get("is_free") == true
	_pills.visible = _time_pill.visible or _free_pill.visible

	_versus_rule.text = rule(record, "versus_tertiary")
	_coop_rule.text = rule(record, "co_op_rules")
	_versus_tile.visible = not _versus_rule.text.is_empty()
	_coop_tile.visible = not _coop_rule.text.is_empty()
	_rules_row.visible = _versus_tile.visible or _coop_tile.visible

	var description = record.get("description")
	_description.text = description.strip_edges() if description is String else ""
	_description_box.visible = not _description.text.is_empty()
	_store_link.visible = is_steam_link(PackRecord.web_link(record, "store_url"))
	_presskit_link.visible = not PackRecord.web_link(record, "presskit_url").is_empty()
	_about_links.visible = _store_link.visible or _presskit_link.visible
	_about_row.visible = (_description_box.visible or _store_link.visible or _presskit_link.visible)

	_build_marks(pack)
	_build_cards(pack)


## Opens one of the selected pack's links in the browser. Only web addresses are
## ever shown as buttons (PackRecord.web_link), so only those get here.
func _open_link(key: String) -> void:
	if _selected == null:
		return
	var url := PackRecord.web_link(_selected.metadata, key)
	if not url.is_empty():
		OS.shell_open(url)


## The spreadsheet's name for the game when the pack has one; the folder otherwise.
func _display_name(pack: PackData) -> String:
	var recorded = pack.metadata.get("name")
	return recorded if recorded is String and not recorded.is_empty() else pack.title


## "~45m", or "" when no time is recorded.
static func play_time(record: Dictionary) -> String:
	var time = record.get("estimated_time")
	if time is String and not time.strip_edges().is_empty():
		return "~%s" % time.strip_edges()
	return ""


## Whether a store link goes to Steam. The store button carries Steam's logo, so
## it's only offered for Steam pages.
static func is_steam_link(url: String) -> bool:
	var host := url.trim_prefix("https://").trim_prefix("http://").get_slice("/", 0).to_lower()
	return host in ["store.steampowered.com", "steamcommunity.com", "s.team"]


## One of the record's rules (versus_tertiary, co_op_rules), or "" when missing.
static func rule(record: Dictionary, key: String) -> String:
	var objectives = record.get("objectives")
	if not (objectives is Dictionary):
		return ""
	var text = objectives.get(key)
	return text.strip_edges() if text is String else ""


## A card section's heading, with how many cards it holds - counted from the
## images, which are what gets dealt, not from the record.
static func cards_heading(group: String, count: int) -> String:
	return "%s (%d)" % [group, count]


func _build_tag_chips(pack: PackData) -> void:
	for child in _tag_chips.get_children():
		_tag_chips.remove_child(child)
		child.queue_free()

	for tag in pack.tags:
		var chip := PanelContainer.new()
		chip.theme_type_variation = &"LibraryChip"
		var label := Label.new()
		label.text = tag
		label.theme_type_variation = &"SmallLabel"
		chip.add_child(label)
		_tag_chips.add_child(chip)


func _build_marks(pack: PackData) -> void:
	for child in _marks.get_children():
		_marks.remove_child(child)
		child.queue_free()

	# Equal-size toggles: solid when the mark is on.
	for mark in PlayerMarksManager.MARKS:
		var toggle := Button.new()
		toggle.toggle_mode = true
		toggle.text = mark["label"]
		toggle.theme_type_variation = &"LibraryMark"
		toggle.set_pressed_no_signal(PlayerMarksManager.has_mark(pack.folder_path, mark["id"]))
		toggle.toggled.connect(
			func(on: bool) -> void: PlayerMarksManager.set_mark(pack.folder_path, mark["id"], on)
		)
		_marks.add_child(toggle)

	_marks_natural_width = 0.0
	for toggle in _marks.get_children():
		_marks_natural_width = maxf(_marks_natural_width, toggle.get_combined_minimum_size().x)
	_fit_marks()


## Lays the marks out as equal tiles that fill each row, as the design has them:
## as many per row as fit the panel at the widest label's width, stretched to
## share the row evenly.
func _fit_marks() -> void:
	var count := _marks.get_child_count()
	if count == 0 or _marks.size.x <= 0.0:
		return
	var gap := float(_marks.get_theme_constant("h_separation"))
	var per_row := clampi(floori((_marks.size.x + gap) / (_marks_natural_width + gap)), 1, count)
	var width := floorf((_marks.size.x - gap * (per_row - 1)) / per_row)
	for toggle in _marks.get_children():
		toggle.custom_minimum_size.x = maxf(width, _marks_natural_width)


func _build_cards(pack: PackData) -> void:
	for child in _cards.get_children():
		_cards.remove_child(child)
		child.queue_free()

	for group in [
		["Primary", pack.primaries], ["Secondary", pack.secondaries], ["Curse", pack.curses]
	]:
		var textures: Array = group[1]
		if textures.is_empty():
			continue

		var heading := Label.new()
		heading.text = cards_heading(group[0], textures.size())
		heading.theme_type_variation = &"SmallLabel"
		_cards.add_child(heading)

		var row := HFlowContainer.new()
		for texture in textures:
			var thumb := TextureButton.new()
			thumb.texture_normal = texture
			thumb.ignore_texture_size = true
			thumb.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
			thumb.custom_minimum_size = THUMBNAIL_SIZE * _scale()
			thumb.pressed.connect(
				func() -> void: _card_inspector.show_card(texture, thumb.get_global_rect())
			)
			row.add_child(thumb)
		_cards.add_child(row)
