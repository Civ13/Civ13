/obj/map_metadata/city
	ID = MAP_CITY
	title = "City (150x150x1)"
	prishtina_blocking_area_types = list(/area/prishtina/no_mans_land/invisible_wall)
	respawn_delay = 2400
	squad_spawn_locations = FALSE
	supply_points_per_tick = list(
		GERMAN = 1.00,
		SOVIET = 1.50)
	faction_organization = list(
		GERMAN,
		SOVIET,
		PARTISAN,
		CIVILIAN,
		ITALIAN)
	available_subfactions = list(
		SCHUTZSTAFFEL = 33,
		ITALIAN = 33
		)
	faction_distribution_coeffs = list(GERMAN = 0.42, SOVIET = 0.58)
	battle_name = "Battle of Kiev"

/obj/map_metadata/city/germans_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 9000 || admin_ended_all_grace_periods)

/obj/map_metadata/city/soviets_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 9000 || admin_ended_all_grace_periods)

/obj/map_metadata/city/announce_mission_start(var/preparation_time)
	world << "<font size=4>All factions have <b>15 minutes</b> to prepare before combat will begin!</font>"

/obj/map_metadata/city/reinforcements_ready()
	return (germans_can_cross_blocks() && soviets_can_cross_blocks())