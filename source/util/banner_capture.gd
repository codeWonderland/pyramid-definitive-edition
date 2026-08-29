class_name BannerCapture

## Turns a screen grab into a wide banner image of a run, sized for use as a
## social or stream header.

## 3:1, the usual shape for a header image.
const BANNER_WIDTH: int = 1500
const BANNER_HEIGHT: int = 500
const ASPECT: float = BANNER_WIDTH / float(BANNER_HEIGHT)
const FILE_PREFIX: String = "pyramid-run"


## Crops the largest 3:1 region that fits inside `source`, centred horizontally
## and vertically on `focus_center_y`, then scales it to banner size.
##
## The band is centred on the card table rather than the middle of the screen so
## the cards are always in frame, and clamped so it never runs off an edge. The
## crop is a true 3:1 region before scaling, so nothing is stretched.
static func crop_to_banner(source: Image, focus_center_y: float) -> Image:
	var region := banner_region(source.get_width(), source.get_height(), focus_center_y)

	var banner := source.get_region(region)
	banner.resize(BANNER_WIDTH, BANNER_HEIGHT, Image.INTERPOLATE_LANCZOS)
	return banner


## The largest true 3:1 region that fits in a frame of this size, centred
## horizontally and vertically on `focus_center_y` and clamped to the frame.
## Split out from the crop so the geometry can be checked exactly, without a
## resample blurring the answer.
static func banner_region(source_width: int, source_height: int, focus_center_y: float) -> Rect2i:
	var band_width := source_width
	var band_height := int(round(source_width / ASPECT))

	# An unusually wide window would want a band taller than the screen; take the
	# full height and narrow the band instead of stretching it.
	if band_height > source_height:
		band_height = source_height
		band_width = int(round(source_height * ASPECT))

	var left := int(round((source_width - band_width) / 2.0))
	var top := int(round(focus_center_y - band_height / 2.0))
	top = clampi(top, 0, source_height - band_height)

	return Rect2i(left, top, band_width, band_height)


## Where a banner should be written. Prefers the player's Pictures folder so the
## file can actually be found; falls back to user:// when the OS has no such
## folder (or reports one that doesn't exist).
static func output_directory() -> String:
	var pictures := OS.get_system_dir(OS.SYSTEM_DIR_PICTURES)
	if pictures != "" and DirAccess.dir_exists_absolute(pictures):
		return pictures

	return "user://"


## Timestamped so repeated captures of a run never overwrite each other.
static func file_name(now: Dictionary) -> String:
	return (
		"%s-%04d-%02d-%02d-%02d%02d%02d.png"
		% [
			FILE_PREFIX,
			now.get("year", 0),
			now.get("month", 0),
			now.get("day", 0),
			now.get("hour", 0),
			now.get("minute", 0),
			now.get("second", 0),
		]
	)
