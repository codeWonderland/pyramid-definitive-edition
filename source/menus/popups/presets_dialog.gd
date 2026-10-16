class_name PresetsDialog extends PopupContainer

## The draft screen's presets: save the current picks under a name, or fill the
## draft from one of the player's presets or a featured one. Using a preset
## replaces the picks; the player can still adjust them before starting.

## How wide the dialog is, against the 1920x1080 reference.
const WIDTH: float = 900.0
## The tallest it may be, as a share of the screen.
const MAX_HEIGHT_SHARE: float = 0.9

@onready var _preset_name: LineEdit = %PresetName
@onready var _save_picks: Button = %SavePicks
@onready var _save_hint: Label = %SaveHint
@onready var _your_list: VBoxContainer = %YourList
@onready var _your_empty: Label = %YourEmpty
@onready var _featured_list: VBoxContainer = %FeaturedList
@onready var _featured_empty: Label = %FeaturedEmpty


func _ready() -> void:
	super._ready()
	_save_picks.pressed.connect(_save_current)
	_preset_name.text_submitted.connect(func(_text: String) -> void: _save_current())
	minimum_size_changed.connect(_resize)


func open() -> void:
	_preset_name.text = ""
	_refresh()
	show()
	_resize.call_deferred()


func _refresh() -> void:
	var has_picks := not RunManager.selected_packs.is_empty()
	_save_picks.disabled = not has_picks
	_save_hint.text = "" if has_picks else "Pick some games first, then save them here."
	_save_hint.visible = not _save_hint.text.is_empty()

	_fill(_your_list, PresetsManager.player_presets(), true)
	_your_empty.visible = _your_list.get_child_count() == 0
	_fill(_featured_list, PresetsManager.featured_presets(), false)
	_featured_empty.visible = _featured_list.get_child_count() == 0


func _fill(list: VBoxContainer, presets: Array[Dictionary], own: bool) -> void:
	for child in list.get_children():
		list.remove_child(child)
		child.queue_free()

	for preset in presets:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)

		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var title := Label.new()
		title.text = preset["name"]
		info.add_child(title)
		var detail := Label.new()
		detail.theme_type_variation = &"SmallLabel"
		detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		detail.text = _describe(preset)
		info.add_child(detail)
		row.add_child(info)

		var use := Button.new()
		use.text = "Use"
		use.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		use.pressed.connect(_use.bind(preset))
		row.add_child(use)

		if own:
			var delete := Button.new()
			delete.text = "Delete"
			delete.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			delete.pressed.connect(_delete.bind(preset["name"]))
			row.add_child(delete)

		list.add_child(row)


static func _describe(preset: Dictionary) -> String:
	var count: int = preset["packs"].size()
	var text := "%d game" % count if count == 1 else "%d games" % count
	var description: String = preset.get("description", "")
	return text if description.is_empty() else "%s · %s" % [text, description]


func _save_current() -> void:
	if PresetsManager.save_preset(_preset_name.text, RunManager.selected_packs):
		_preset_name.text = ""
		_refresh()
		_save_hint.text = "Saved."
		_save_hint.show()
	elif _preset_name.text.strip_edges().is_empty():
		_save_hint.text = "Give your preset a name."
		_save_hint.show()


## Fills the draft with the preset's games that are installed.
func _use(preset: Dictionary) -> void:
	var packs := PresetsManager.packs_for(preset)
	if packs.is_empty():
		_save_hint.text = "None of that preset's games are installed."
		_save_hint.show()
		return

	RunManager.selected_packs = packs
	RunManager.packs_updated.emit()
	_close()


func _delete(preset_name: String) -> void:
	PresetsManager.delete_preset(preset_name)
	_refresh()


## Sized to its content rather than most of the screen, and centred.
func _resize() -> void:
	var screen_size := get_viewport().get_visible_rect().size
	var scale_mult := minf(screen_size.x / 1920.0, screen_size.y / 1080.0)
	var height := get_combined_minimum_size().y
	var tallest := screen_size.y * MAX_HEIGHT_SHARE
	if height * scale_mult > tallest:
		scale_mult = tallest / height
	scale = Vector2(scale_mult, scale_mult)
	size = Vector2(WIDTH, height)
	position = screen_size / 2 - size * scale / 2
