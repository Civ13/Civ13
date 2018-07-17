#define NO_WINNER "Neither side has captured the other's base."
/obj/map_metadata/forest_new
	ID = MAP_FOREST_NEW
	title = "Forest (530x530x1)"
	prishtina_blocking_area_types = list(
		/area/prishtina/no_mans_land/invisible_wall)
	allow_bullets_through_blocks = list()
	roundend_condition_sides = list(
		list(GERMAN, ITALIAN) = /area/prishtina/german,
		list(SOVIET) = /area/prishtina/soviet/bunker)
	uses_supply_train = TRUE
	uses_main_train = TRUE
	supply_points_per_tick = list(
		SOVIET = 1.00,
		GERMAN = 1.50)
	faction_organization = list(
		GERMAN,
		SOVIET,
		PARTISAN,
		CIVILIAN,
		ITALIAN)
	// lower chances because paratroopers are fun too. Todo: make paratroopers a subfaction
	available_subfactions = list(
		SCHUTZSTAFFEL = 35,
		ITALIAN = 15)
	faction_distribution_coeffs = list(GERMAN = 0.42, SOVIET = 0.58)
	battle_name = "Battle of the Dnieper"

/obj/map_metadata/forest_new/germans_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 9000 || admin_ended_all_grace_periods)

/obj/map_metadata/forest_new/soviets_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 9000 || admin_ended_all_grace_periods)

/obj/map_metadata/forest_new/announce_mission_start(var/preparation_time)
	world << "<font size=4>All factions have <b>15 minutes</b> to prepare before combat will begin!</font>"

/obj/map_metadata/forest_new/reinforcements_ready()
	return (germans_can_cross_blocks() && soviets_can_cross_blocks())