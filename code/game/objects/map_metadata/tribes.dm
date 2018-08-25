#define NO_WINNER "The round is proceeding normally."
/obj/map_metadata/tribes
	ID = MAP_TRIBES
	title = "Tribes (225x225x2)"
//	lobby_icon_state = "pirates"
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall/)
	respawn_delay = 6000 // 10 minutes!
	squad_spawn_locations = FALSE
	reinforcements = FALSE
//	min_autobalance_players = 90
	faction_organization = list(
		INDIANS)
	available_subfactions = list(
		)
	roundend_condition_sides = list(
		list(INDIANS) = /area/caribbean/indians,
		)
	front = "Pacific"
	faction_distribution_coeffs = list(INDIANS = 1)
	battle_name = "Tribal village"
	mission_start_message = "" // to be replaced with the round's main event
	ambience = list('sound/ambience/jungle1.ogg')
	faction1 = INDIANS
	faction2 = INDIANS
	single_faction = TRUE

obj/map_metadata/tribes/job_enabled_specialcheck(var/datum/job/J)
	if (!(istype(J, /datum/job/indians/tribes)))
		. = FALSE
	else
		. = TRUE
	return .
/obj/map_metadata/tribes/faction2_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 0 || admin_ended_all_grace_periods)

/obj/map_metadata/tribes/faction1_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 0 || admin_ended_all_grace_periods)

/obj/map_metadata/tribes/cross_message(faction)
	return ""

/obj/map_metadata/tribes/reinforcements_ready()
	return (faction2_can_cross_blocks() && faction1_can_cross_blocks())

#undef NO_WINNER