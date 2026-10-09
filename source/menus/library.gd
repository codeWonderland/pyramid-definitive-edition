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
@onready var _tags: Label = %Tags
@onready var _description: Label = %Description
@onready var _facts: Label = %Facts
@onready var _links: HBoxContainer = %Links
@onready var _store_link: Button = %StoreLink
@onready var _presskit_link: Button = %PresskitLink
@onready var _rules: Label = %Rules
@onready var _challenges: Label = %Challenges
@onready var _marks: HFlowContainer = %Marks
@onready var _cards: VBoxContainer = %Cards
@onready var _card_inspector: CardInspector = %CardInspector


func _ready() -> void:
	_back_button.pressed.connect(_back)
	_search.text_changed.connect(func(_query: String) -> void: _build_grid())
	_favorites_button.pressed.connect(_toggle_favorites_only)
	FavoritesManager.favorites_changed.connect(_on_favorites_changed)
	PlayerMarksManager.marks_changed.connect(_on_marks_changed)
	_store_link.pressed.connect(_open_link.bind("store_url"))
	_presskit_link.pressed.connect(_open_link.bind("presskit_url"))

	get_tree().get_root().size_changed.connect(_resize)

	_set_background()
	_update_favorites_label()
	_show_details(null)

	# Packs normally load on the way into a run; opening the library straight from
	# the main menu has to load them itself.
	if PacksManager.all_packs.is_empty():
		await PacksManager.load()

	_build_grid()


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
	SceneTransition.change_scene_to_packed(load("res://source/menus/main_menu.tscn"))


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
	_tags.text = ", ".join(pack.tags) if not pack.tags.is_empty() else "No categories recorded"
	var description = record.get("description")
	_description.text = description.strip_edges() if description is String else ""
	_description.visible = not _description.text.is_empty()
	_facts.text = describe_facts(pack)
	_store_link.visible = not PackRecord.web_link(record, "store_url").is_empty()
	_presskit_link.visible = not PackRecord.web_link(record, "presskit_url").is_empty()
	_links.visible = _store_link.visible or _presskit_link.visible
	_rules.text = describe_rules(record)
	_challenges.text = describe_challenges(record)
	_challenges.visible = not _challenges.text.is_empty()
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


## Price, play time and card counts. Counts come from the pack's actual images,
## not the record, since the two can disagree and the images are what gets dealt.
static func describe_facts(pack: PackData) -> String:
	var facts: Array[String] = []
	var record := pack.metadata

	if record.get("is_free") is bool:
		facts.append("Free" if record["is_free"] else "Paid")
	if record.get("estimated_time") is String and not record["estimated_time"].is_empty():
		facts.append("About %s per run" % record["estimated_time"])

	var counts := "%d primary · %d secondary" % [pack.primaries.size(), pack.secondaries.size()]
	if pack.curses.size() > 0:
		counts += " · %d curse" % pack.curses.size() + ("s" if pack.curses.size() > 1 else "")
	facts.append(counts)

	return "\n".join(facts)


static func describe_rules(record: Dictionary) -> String:
	var objectives = record.get("objectives")
	if not (objectives is Dictionary):
		return "No versus or co-op rules recorded"

	var lines: Array[String] = []
	if objectives.get("versus_tertiary") is String and not objectives["versus_tertiary"].is_empty():
		lines.append("Versus: %s" % objectives["versus_tertiary"])
	if objectives.get("co_op_rules") is String and not objectives["co_op_rules"].is_empty():
		lines.append("Co-op: %s" % objectives["co_op_rules"])

	return "\n".join(lines) if not lines.is_empty() else "No versus or co-op rules recorded"


## Dev and creator challenges, credited to whoever made them. Empty when none.
static func describe_challenges(record: Dictionary) -> String:
	var special = record.get("special_challenges")
	if not (special is Dictionary and special.get("entries") is Array):
		return ""

	var lines: Array[String] = []
	for entry in special["entries"]:
		if not (entry is Dictionary and entry.get("text") is String):
			continue

		var line: String = "• %s" % entry["text"]
		var contributor = entry.get("contributor")
		if contributor is Dictionary and contributor.get("handle") is String:
			var role = contributor.get("role")
			line += (" (%s%s)" % [contributor["handle"], ", %s" % role if role is String else ""])
		lines.append(line)

	if lines.is_empty():
		return ""
	return "Dev & creator challenges\n" + "\n".join(lines)


func _build_marks(pack: PackData) -> void:
	for child in _marks.get_children():
		_marks.remove_child(child)
		child.queue_free()

	for mark in PlayerMarksManager.MARKS:
		var box := CheckBox.new()
		box.text = mark["label"]
		box.theme_type_variation = &"SmallCheckBox"
		box.set_pressed_no_signal(PlayerMarksManager.has_mark(pack.folder_path, mark["id"]))
		box.toggled.connect(
			func(on: bool) -> void: PlayerMarksManager.set_mark(pack.folder_path, mark["id"], on)
		)
		_marks.add_child(box)


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
		heading.text = group[0]
		heading.theme_type_variation = &"SmallLabel"
		_cards.add_child(heading)

		var row := HFlowContainer.new()
		for texture in textures:
			var thumb := TextureButton.new()
			thumb.texture_normal = texture
			thumb.ignore_texture_size = true
			thumb.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
			thumb.custom_minimum_size = THUMBNAIL_SIZE * _scale()
			thumb.pressed.connect(_card_inspector.show_card.bind(texture))
			row.add_child(thumb)
		_cards.add_child(row)
