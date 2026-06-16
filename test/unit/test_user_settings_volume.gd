extends GutTest

# Tests for the volume<->dB conversion in UserSettingsManager. db_to_volume must
# be the true inverse of volume_to_db (this was previously broken and saturated
# to 1.0 for almost any dB value).


func test_zero_volume_maps_to_silence() -> void:
	assert_eq(UserSettingsManager.volume_to_db(0.0), -100, "0 volume is the silence sentinel")
	assert_eq(UserSettingsManager.db_to_volume(-100), 0.0, "silence maps back to 0 volume")


func test_full_volume_maps_to_zero_db() -> void:
	assert_eq(UserSettingsManager.volume_to_db(1.0), 0, "full volume is 0 dB")
	assert_almost_eq(
		UserSettingsManager.db_to_volume(0), 1.0, 0.001, "0 dB maps back to full volume"
	)


func test_round_trip_for_tenths() -> void:
	for tenth in range(1, 11):
		var volume := tenth / 10.0
		var db := UserSettingsManager.volume_to_db(volume)
		var back := UserSettingsManager.db_to_volume(db)
		assert_almost_eq(back, volume, 0.001, "round trip preserves volume %f" % volume)


func test_db_to_volume_stays_in_range() -> void:
	for db in range(-30, 1):
		var volume := UserSettingsManager.db_to_volume(db)
		assert_between(volume, 0.0, 1.0, "volume for %d dB is within 0..1" % db)
