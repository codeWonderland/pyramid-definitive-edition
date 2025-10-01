class_name Game extends Control

const DICE_TEXTURES = [
	preload("res://assets/sprites/ui/icons/d1.png"),
	preload("res://assets/sprites/ui/icons/d2.png"),
	preload("res://assets/sprites/ui/icons/d3.png"),
	preload("res://assets/sprites/ui/icons/d4.png"),
	preload("res://assets/sprites/ui/icons/d5.png"),
	preload("res://assets/sprites/ui/icons/d6.png"),
]

var _popup_open: bool = false

@onready var _back_button: TextureButton = %Back
@onready var _title: Label = %Title
@onready var _settings_button: TextureButton = %Settings
@onready var _pause_menu: PauseMenu = %PauseMenu
@onready var _close_button: TextureButton = %Close
@onready var _die: TextureRect = %Die
@onready var _roll_die_button: TextureButton = %RollDie
@onready var _reroll_packs_button: TextureButton = %RerollGames
@onready var _multiplayer_rules_button: TextureButton = %MultiplayerRulesButton
@onready var _multiplayer_rules: MultiplayerRules = %MultiplayerRules
@onready var _coop_rules_button: TextureButton = %CoopRulesButton
@onready var _coop_rules: CoopRules = %CoopRules


func _ready() -> void:
	_resize()
	get_tree().get_root().size_changed.connect(_resize)

	# Button Callbacks
	_back_button.pressed.connect(_back)
	_settings_button.pressed.connect(_open_settings)
	_close_button.pressed.connect(_close_game)
	_roll_die_button.pressed.connect(_roll_die)
	_reroll_packs_button.pressed.connect(_reroll_packs)
	_multiplayer_rules_button.pressed.connect(_show_multiplayer_rules)
	_coop_rules_button.pressed.connect(_show_coop_rules)

	# Popup Callbacks
	_pause_menu.closing.connect(_on_popup_closing)
	_multiplayer_rules.closing.connect(_on_popup_closing)
	_coop_rules.closing.connect(_on_popup_closing)

	# Scene Setup
	_reroll_packs()


func _resize() -> void:
	var screen_size = get_viewport().size as Vector2

	_title.size.x = screen_size.x * 0.6
	_title.position.x = screen_size.x * 0.2


func _back() -> void:
	if _popup_open:
		return

	get_tree().change_scene_to_packed(load("res://source/menus/num_games.tscn"))


func _open_settings() -> void:
	if _popup_open:
		return

	_pause_menu.show()
	_popup_open = true


func _close_game() -> void:
	if _popup_open:
		return

	# TODO: Create Close Game Dialog with Option to Save


func _roll_die() -> void:
	if _popup_open:
		return

	_die.texture = DICE_TEXTURES.pick_random()
	_die.show()
	AudioManager.play_sfx(AudioManager.DICE_ROLL)


func _reroll_packs() -> void:
	if _popup_open:
		return

	_set_title()

	# TODO: Pack Rolling

	_resize()


func _show_multiplayer_rules() -> void:
	if _popup_open:
		return

	_popup_open = true

	_multiplayer_rules.show()


func _show_coop_rules() -> void:
	if _popup_open:
		return

	_popup_open = true

	_coop_rules.show()


func _on_popup_closing() -> void:
	_popup_open = false


func _set_title() -> void:
	var adjective = WordBankLoader.adjectives.pick_random()
	var noun = WordBankLoader.nouns.pick_random()

	_title.text = (
		("The {adjective} Pyramid of {noun}")
		. format(
			{
				adjective = adjective,
				noun = noun,
			}
		)
	)

	if _title.text.length() > 45:
		_title.theme_type_variation = &"MediumTitle"
	else:
		_title.theme_type_variation = &"BigTitle"
