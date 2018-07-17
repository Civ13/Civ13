/obj/map_metadata/test
	ID = "TESTCITY"
	title = "Test (70x70x1)"
	prishtina_blocking_area_types = list(/area/prishtina/no_mans_land/invisible_wall)
	faction_organization = list(
		GERMAN,
		SOVIET,
		PARTISAN,
		CIVILIAN,
		ITALIAN)
	available_subfactions = list(
		SCHUTZSTAFFEL,
		ITALIAN)
	faction_distribution_coeffs = list(GERMAN = 0.50, SOVIET = 0.50)
	respawn_delay = 0

/obj/map_metadata/test/germans_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 7200 || admin_ended_all_grace_periods)

/obj/map_metadata/test/soviets_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 7200 || admin_ended_all_grace_periods)

/obj/map_metadata/test/announce_mission_start(var/preparation_time)
	world << "<font size=4>All factions have <b>12 minutes</b> to prepare before combat will begin!</font>"