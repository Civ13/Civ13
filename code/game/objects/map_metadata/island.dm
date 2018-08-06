#define NO_WINNER "No ship has been captured."
/obj/map_metadata/island
	ID = MAP_ISLAND
	title = "Skull Island (125x125x2)"
//	lobby_icon_state = "pirates"
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall/)
	respawn_delay = 0
	squad_spawn_locations = FALSE
	reinforcements = FALSE
//	min_autobalance_players = 90
	faction_organization = list(
		BRITISH,
		PIRATES)
	available_subfactions = list(
		)
	roundend_condition_sides = list(
		list(BRITISH) = /area/caribbean/british/ship/,
		list(PIRATES) = /area/caribbean/pirates/land/inside
		)
	front = "Pacific"
	faction_distribution_coeffs = list(BRITISH = 0.6, PIRATES = 0.4)
	songs = list(
		"Fish in the Sea:1" = 'sound/music/shanties/fish_in_the_sea.ogg',
		"Spanish Ladies:1" = 'sound/music/shanties/spanish_ladies.ogg',
		"Irish Rovers:1" = 'sound/music/shanties/irish_rovers.ogg')
	meme = TRUE
	battle_name = "Skull Island"
	mission_start_message = "<font size=4>All factions have <b>10 minutes</b> to prepare before the combat starts.</font>"
/*	var/done = FALSE
/obj/map_metadata/island/check_events()
	if ((world.time >= 300) && !done)
		world << "Pirates are approaching!"
		for (var/obj/effect/area_teleporter/AT)
			AT.Activated()
			world << "Pirates are trying to board the ship!"
			done = TRUE
			return TRUE
	else return FALSE
*/
/obj/map_metadata/island/british_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 6000 || admin_ended_all_grace_periods)

/obj/map_metadata/island/pirates_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 6000 || admin_ended_all_grace_periods)

/obj/map_metadata/island/reinforcements_ready()
	return (british_can_cross_blocks() && pirates_can_cross_blocks())

#undef NO_WINNER