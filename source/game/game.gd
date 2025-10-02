class_name Game extends Control

const DICE_TEXTURES = [
	preload("res://assets/sprites/ui/icons/d1.png"),
	preload("res://assets/sprites/ui/icons/d2.png"),
	preload("res://assets/sprites/ui/icons/d3.png"),
	preload("res://assets/sprites/ui/icons/d4.png"),
	preload("res://assets/sprites/ui/icons/d5.png"),
	preload("res://assets/sprites/ui/icons/d6.png"),
]

@onready var _back_button: TextureButton = %Back
@onready var _title: Label = %Title
@onready var _top_right: HBoxContainer = %TopRight
@onready var _settings_button: TextureButton = %Settings
@onready var _pause_menu: PauseMenu = %PauseMenu
@onready var _close_button: TextureButton = %Close
@onready var _card_group_collection: CardGroupCollection = %CardGroupCollection
@onready var _bottom_left: VBoxContainer = %BottomLeft
@onready var _die: TextureRect = %Die
@onready var _roll_die_button: TextureButton = %RollDie
@onready var _reroll_packs_button: TextureButton = %RerollGames
@onready var _bottom_right: VBoxContainer = %BottomRight
@onready var _multiplayer_rules_button: TextureButton = %MultiplayerRulesButton
@onready var _multiplayer_rules: MultiplayerRules = %MultiplayerRules
@onready var _coop_rules_button: TextureButton = %CoopRulesButton
@onready var _coop_rules: CoopRules = %CoopRules
@onready var _quit_dialog: QuitDialog = %QuitDialog
@onready var _save_dialog: SaveDialog = %SaveDialog


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
	_quit_dialog.closing.connect(_on_popup_closing)
	_save_dialog.closing.connect(_on_popup_closing)
	_quit_dialog.confirm_quit.connect(_on_quit_confirmed)
	_save_dialog.save_confirmed.connect(_on_save_confirmed)

	# Scene Setup
	_reroll_packs()


func _resize() -> void:
	var screen_size = get_viewport().size as Vector2
	var scale_mult = screen_size.x / 1280.0

	if screen_size.y / 720.0 < scale_mult:
		scale_mult = screen_size.y / 720.0

	if scale_mult <= 1.0:
		var new_scale = Vector2(scale_mult, scale_mult)
		_title.scale = new_scale
		_back_button.scale = new_scale
		_top_right.scale = new_scale
		_bottom_left.scale = new_scale
		_reroll_packs_button.scale = new_scale
		_bottom_right.scale = new_scale


func _back() -> void:
	if RunManager.popup_open:
		return

	get_tree().change_scene_to_packed(load("res://source/menus/num_games.tscn"))


func _open_settings() -> void:
	if RunManager.popup_open:
		return

	_pause_menu.show()
	RunManager.popup_open = true


func _close_game() -> void:
	if RunManager.popup_open:
		return

	_quit_dialog.show()
	RunManager.popup_open = true


func _roll_die() -> void:
	if RunManager.popup_open:
		return

	_die.texture = DICE_TEXTURES.pick_random()
	_die.show()
	AudioManager.play_sfx(AudioManager.DICE_ROLL)


func _reroll_packs() -> void:
	if RunManager.popup_open:
		return

	_set_title()

	var current_packs = RunManager.get_random_loadout()
	_card_group_collection.packs = current_packs

	_resize()


func _show_multiplayer_rules() -> void:
	if RunManager.popup_open:
		return

	RunManager.popup_open = true

	_multiplayer_rules.show()


func _show_coop_rules() -> void:
	if RunManager.popup_open:
		return

	RunManager.popup_open = true

	_coop_rules.show()


func _on_popup_closing() -> void:
	RunManager.popup_open = false


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


func _on_quit_confirmed() -> void:
	_save_dialog.show()


func _on_save_confirmed(should_save: bool) -> void:
	print("should save")
	print(should_save)
