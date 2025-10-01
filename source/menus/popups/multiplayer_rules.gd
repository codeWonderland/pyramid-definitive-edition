class_name MultiplayerRules extends PopupContainer

@onready var _per_game_rules: RichTextLabel = %PerGameRules


func _ready() -> void:
	super._ready()

	for pack in RunManager.selected_packs:
		if AdditionalRulesLoader.additional_rules.has(pack.title):
			_per_game_rules.text += ("\n{game_name}:\n{game_rule}\n".format(
				{
					game_name = pack.title.capitalize(),
					game_rule = AdditionalRulesLoader.additional_rules[pack.title]["multiplayer"]
				}
			))
