extends GutTest

# Tests the run banner capture (#37): the crop is a true 3:1 region centred on
# the card table, never runs off an edge, and is never stretched.


func _image(width: int, height: int) -> Image:
	var img := Image.create(width, height, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	return img


func test_output_is_banner_sized() -> void:
	var banner := BannerCapture.crop_to_banner(_image(1920, 1080), 540.0)

	assert_eq(banner.get_width(), BannerCapture.BANNER_WIDTH, "banner width")
	assert_eq(banner.get_height(), BannerCapture.BANNER_HEIGHT, "banner height")


func test_band_is_centred_on_the_focus() -> void:
	# A 1920-wide frame gives a 640-tall band; centred on y=540 it starts at 220.
	var region := BannerCapture.banner_region(1920, 1080, 540.0)

	assert_eq(region, Rect2i(0, 220, 1920, 640), "band centred on the focus row")


func test_band_is_clamped_to_the_top_edge() -> void:
	var region := BannerCapture.banner_region(1920, 1080, 10.0)

	assert_eq(region.position.y, 0, "a focus near the top clamps the band to the top")
	assert_eq(region.size, Vector2i(1920, 640), "and the band keeps its size")


func test_band_is_clamped_to_the_bottom_edge() -> void:
	var region := BannerCapture.banner_region(1920, 1080, 5000.0)

	assert_eq(region.position.y, 440, "the lowest legal band start")
	assert_eq(region.size, Vector2i(1920, 640), "and the band keeps its size")


func test_region_is_always_three_to_one() -> void:
	for size in [Vector2i(1920, 1080), Vector2i(1280, 720), Vector2i(800, 800)]:
		var region := BannerCapture.banner_region(size.x, size.y, size.y / 2.0)
		assert_almost_eq(
			region.size.x / float(region.size.y),
			BannerCapture.ASPECT,
			0.01,
			"region for %s is 3:1, so nothing is stretched" % size
		)


func test_region_stays_inside_the_frame() -> void:
	for focus in [-500.0, 0.0, 540.0, 5000.0]:
		var region := BannerCapture.banner_region(1920, 1080, focus)
		assert_gte(region.position.y, 0, "band starts inside the frame for focus %f" % focus)
		assert_lte(region.position.y + region.size.y, 1080, "band ends inside for focus %f" % focus)


func test_a_very_wide_frame_narrows_instead_of_stretching() -> void:
	# 3000x400 would want a 1000-tall band; instead it takes the full height and
	# narrows to 1200 wide, centred, keeping a true 3:1 crop.
	var region := BannerCapture.banner_region(3000, 400, 200.0)

	assert_eq(region, Rect2i(900, 0, 1200, 400), "the band narrowed and centred horizontally")


func test_a_square_frame_still_produces_a_banner() -> void:
	var banner := BannerCapture.crop_to_banner(_image(800, 800), 400.0)

	assert_eq(banner.get_width(), BannerCapture.BANNER_WIDTH, "square input still crops to 3:1")
	assert_eq(banner.get_height(), BannerCapture.BANNER_HEIGHT, "square input still crops to 3:1")


func test_file_name_is_timestamped() -> void:
	var name := BannerCapture.file_name(
		{"year": 2026, "month": 8, "day": 25, "hour": 9, "minute": 5, "second": 3}
	)

	assert_eq(name, "pyramid-run-2026-08-25-090503.png", "zero-padded timestamp in the name")


func test_file_names_differ_between_captures() -> void:
	var first := BannerCapture.file_name(
		{"year": 2026, "month": 8, "day": 25, "hour": 9, "minute": 5, "second": 3}
	)
	var second := BannerCapture.file_name(
		{"year": 2026, "month": 8, "day": 25, "hour": 9, "minute": 5, "second": 4}
	)

	assert_ne(first, second, "a later capture does not overwrite an earlier one")


func test_output_directory_is_usable() -> void:
	var directory := BannerCapture.output_directory()

	assert_ne(directory, "", "a directory was chosen")
	assert_true(
		DirAccess.dir_exists_absolute(directory) or directory == "user://",
		"the chosen directory exists, or is the user:// fallback"
	)
