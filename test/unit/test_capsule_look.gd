extends GutTest

# Tests the Steam-capsule look: the new default background with the old one kept
# as "Classic", and the Oxanium font at a readable weight everywhere.

const THEME: Theme = preload("res://assets/themes/main_theme.tres")


func test_classic_background_is_still_offered() -> void:
	BackgroundManager.load()

	assert_true(BackgroundManager.backgrounds.has("Default"), "the new capsule background")
	assert_true(BackgroundManager.backgrounds.has("Classic"), "the old default, kept")
	assert_ne(
		BackgroundManager.backgrounds["Default"],
		BackgroundManager.backgrounds["Classic"],
		"and they are different images"
	)


func test_theme_font_is_oxanium_at_a_readable_weight() -> void:
	# Oxanium's default weight is ExtraLight (200); used as-is the theme's thick
	# outlines swallow it, which is what went wrong importing it directly.
	var font := THEME.get_font("font", "Label")
	assert_true(font is FontVariation, "a weighted variation, not the raw font")

	var wght := TextServerManager.get_primary_interface().name_to_tag("wght")
	assert_eq((font as FontVariation).variation_opentype.get(wght), 700, "at bold weight")
	assert_string_contains(
		(font as FontVariation).base_font.resource_path, "Oxanium", "of the capsule font"
	)


func test_project_default_font_matches_the_theme() -> void:
	assert_eq(
		ProjectSettings.get_setting("gui/theme/custom_font"),
		"uid://b7oxnm1wght7",
		"controls without a theme font use the same one"
	)


func test_title_styles_do_not_overlap_their_own_lines() -> void:
	# Negative line spacing tuned for the old font made wrapped titles collide.
	for style in ["ExtraLargeTitle", "BigTitle", "MediumTitle", "SmallLabel"]:
		assert_gte(THEME.get_constant("line_spacing", style), 0, "%s lines don't overlap" % style)
