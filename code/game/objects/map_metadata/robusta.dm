#define NO_WINNER "The fighting is still going."
/obj/map_metadata/robusta
	ID = MAP_ROBUSTA
	title = "Isla Robusta (125x125x1)"
//	lobby_icon_state = "pirates"
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall/)
	respawn_delay = 0
	squad_spawn_locations = FALSE
	reinforcements = FALSE
//	min_autobalance_players = 90
	faction_organization = list(
		BRITISH,
		PIRATES,
		INDIANS)
	available_subfactions = list(
		)
	roundend_condition_sides = list(
		list(BRITISH) = /area/caribbean/british/land,
		list(PIRATES) = /area/caribbean/pirates/land,
		list(INDIANS) = /area/caribbean/indians,
		)
	front = "Pacific"
	faction_distribution_coeffs = list(BRITISH = 0.4, PIRATES = 0.4, INDIANS = 0.2)
//	songs = list(
//		"He's a Pirate:1" = 'sound/music/hes_a_pirate.ogg')
//	meme = TRUE
	battle_name = "Isla Robusta"
	mission_start_message = "<font size=4>All factions have <b>8 minutes</b> to prepare before the combat starts.</font>"
	ambience = list('sound/ambience/jungle1.ogg')

obj/map_metadata/robusta/job_enabled_specialcheck(var/datum/job/J)
	if (istype(J, /datum/job/pirates/battleroyale))
		. = FALSE
	else
		. = TRUE
	return .
/obj/map_metadata/robusta/faction2_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 4800 || admin_ended_all_grace_periods)

/obj/map_metadata/robusta/faction1_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 4800 || admin_ended_all_grace_periods)

/obj/map_metadata/robusta/reinforcements_ready()
	return (faction2_can_cross_blocks() && faction1_can_cross_blocks())

#undef NO_WINNER