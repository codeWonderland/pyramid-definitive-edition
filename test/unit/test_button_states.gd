extends GutTest

# Tests button press/hover feedback in the theme (#16). Every interactive state
# used to point at the same style box, so nothing responded to hover or press.
#
# These assert the states are *distinct* rather than checking exact colours, so
# the look can be retuned without breaking the tests - what matters is that
# feedback exists at all.

const THEME: Theme = preload("res://assets/themes/main_theme.tres")


func _style(state: String, type: String) -> StyleBox:
	return THEME.get_stylebox(state, type)


## Buttons are outlined pills: a flat box with a fill and a border.
func _pill(state: String, type: String) -> StyleBoxFlat:
	var style := _style(state, type)
	assert_true(style is StyleBoxFlat, "%s/%s is a flat pill" % [type, state])
	return style as StyleBoxFlat


# --- Button ---


func test_button_defines_every_interactive_state() -> void:
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		assert_not_null(_style(state, "Button"), "Button defines a %s style" % state)


func test_button_hover_differs_from_normal() -> void:
	assert_ne(_style("hover", "Button"), _style("normal", "Button"), "hovering changes the button")


func test_button_pressed_differs_from_hover_and_normal() -> void:
	assert_ne(_style("pressed", "Button"), _style("normal", "Button"), "pressing looks different")
	assert_ne(
		_style("pressed", "Button"),
		_style("hover", "Button"),
		"and differs from merely hovering, so a click reads as a click"
	)


func test_button_hover_lightens_and_pressed_fills_with_the_outline() -> void:
	var normal := _pill("normal", "Button")
	var hover := _pill("hover", "Button")
	var pressed := _pill("pressed", "Button")

	assert_gt(normal.border_width_left, 0, "the pill has an outline")
	assert_gt(hover.bg_color.v, normal.bg_color.v, "hover lightens the fill")
	assert_eq(pressed.bg_color, normal.border_color, "pressing fills it with the outline colour")


func test_button_disabled_is_faded() -> void:
	var normal := _pill("normal", "Button")
	var disabled := _pill("disabled", "Button")

	assert_lt(disabled.bg_color.a, normal.bg_color.a, "a disabled button's fill is faded")
	assert_lt(disabled.border_color.a, normal.border_color.a, "and so is its outline")


func test_button_focus_does_not_mask_the_state_underneath() -> void:
	# Godot draws the focus style over the state style. An opaque focus box would
	# hide hover and press feedback on the button you just clicked, which is
	# exactly what used to happen here.
	var focus := _style("focus", "Button")

	assert_true(focus is StyleBoxFlat, "focus is a flat box, so it can be a ring")
	assert_false(
		(focus as StyleBoxFlat).draw_center, "the focus ring has no fill, so it masks nothing"
	)
	assert_gt(
		(focus as StyleBoxFlat).border_width_left, 0, "and it is actually visible as a border"
	)


# --- CheckBox ---


func test_checkbox_hover_and_pressed_differ_from_normal() -> void:
	assert_ne(
		_style("hover", "CheckBox"), _style("normal", "CheckBox"), "checkbox responds to hover"
	)
	assert_ne(_style("pressed", "CheckBox"), _style("normal", "CheckBox"), "and to being pressed")


func test_checkbox_focus_does_not_mask_the_state() -> void:
	var focus := _style("focus", "CheckBox")

	assert_true(focus is StyleBoxFlat, "focus is a flat box")
	assert_false((focus as StyleBoxFlat).draw_center, "with no fill")


# --- OptionButton ---


func test_option_button_states_are_distinct() -> void:
	assert_ne(
		_style("hover", "OptionButton"),
		_style("normal", "OptionButton"),
		"the dropdown responds to hover"
	)
	assert_ne(
		_style("pressed", "OptionButton"), _style("normal", "OptionButton"), "and to being pressed"
	)


func test_option_button_matches_the_buttons() -> void:
	for state in ["normal", "hover", "pressed"]:
		assert_eq(
			_style(state, "OptionButton"),
			_style(state, "Button"),
			"the dropdown's %s state is the button pill" % state
		)


# --- SelectableButton ---


func test_selectable_button_has_its_own_hover() -> void:
	# It overrides pressed/focus to show selection, so without its own hover it
	# would fall back to the plain Button look and clash.
	assert_ne(
		_style("hover", "SelectableButton"),
		_style("hover", "Button"),
		"the selectable variation hovers in its own style"
	)
	assert_ne(
		_style("hover", "SelectableButton"),
		_style("pressed", "SelectableButton"),
		"and hovering is not mistaken for being selected"
	)


# --- Nothing left sharing one style ---


func test_no_button_type_reuses_one_style_for_every_state() -> void:
	for type in ["Button", "CheckBox", "OptionButton"]:
		var normal := _style("normal", type)
		var distinct := 0
		for state in ["hover", "pressed"]:
			if _style(state, type) != normal:
				distinct += 1
		assert_eq(distinct, 2, "%s gives hover and pressed their own styles" % type)
