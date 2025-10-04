class_name MultiplayerRules extends PopupContainer

@onready var _scroll_container: ScrollContainer = %ScrollContainer
@onready var _per_game_rules: RichTextLabel = %PerGameRules


func _ready() -> void:
	super._ready()

	load_rules()

	_resize()
	super._override_resize()
	get_tree().get_root().size_changed.connect(_resize)


func load_rules() -> void:
	for pack in RunManager.selected_packs:
		if AdditionalRulesLoader.additional_rules.has(pack.title):
			_per_game_rules.text += ("\n{game_name}:\n{game_rule}\n".format(
				{
					game_name = pack.title.capitalize(),
					game_rule = AdditionalRulesLoader.additional_rules[pack.title]["multiplayer"]
				}
			))


func _resize() -> void:
	super._resize()
	_scroll_container.custom_minimum_size.y = size.y - 130.0
