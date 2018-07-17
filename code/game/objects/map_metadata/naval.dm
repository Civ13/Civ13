#define NO_WINNER "No ship has been captured."
/obj/map_metadata/naval
	ID = MAP_NAVAL
	title = "Naval Battle (75x75x2)"
	lobby_icon_state = "pirates"
	prishtina_blocking_area_types = list(/area/prishtina/no_mans_land/invisible_wall/)
	respawn_delay = 1800
	squad_spawn_locations = FALSE
	reinforcements = FALSE
//	min_autobalance_players = 90
	supply_points_per_tick = list(
		BRITISH = 1.00,
		PIRATES= 1.00)
	faction_organization = list(
		BRITISH,
		PIRATES)
	available_subfactions = list(
		)
	roundend_condition_sides = list(
		list(BRITISH) = /area/prishtina/german,
		list(PIRATES) = /area/prishtina/soviet
		)
	front = "Pacific"
	faction_distribution_coeffs = list(BRITISH = 0.4, PIRATES = 0.6)
	songs = list(
		"He's a Pirate:1" = 'sound/music/hes_a_pirate.ogg',
		)
	meme = TRUE
	battle_name = "Naval Battle"

/obj/map_metadata/naval/germans_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 9000 || admin_ended_all_grace_periods)

/obj/map_metadata/naval/soviets_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 9000 || admin_ended_all_grace_periods)

/obj/map_metadata/naval/announce_mission_start(var/preparation_time)
	world << "<font size=4>All factions have <b>5 minutes</b> to prepare before the combat starts.</font>"

/obj/map_metadata/naval/reinforcements_ready()
	return (germans_can_cross_blocks() && soviets_can_cross_blocks())

#undef NO_WINNER