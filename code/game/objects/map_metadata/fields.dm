#define NO_WINNER "The fighting for the town is still going on."
/obj/map_metadata/fields
	ID = MAP_FIELDS
	title = "Fields (140x60x1)"
	lobby_icon_state = "imperial"
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall/)
	respawn_delay = 300
	squad_spawn_locations = FALSE
//	min_autobalance_players = 90
	faction_organization = list(
		BRITISH,
		FRENCH)
	available_subfactions = list(
		)
	roundend_condition_sides = list(
		list(BRITISH) = /area/caribbean/colonies/british,
		list(FRENCH) = /area/caribbean/colonies/french
		)
	age = "1713"
	ordinal_age = 3
	faction_distribution_coeffs = list(BRITISH = 0.5, FRENCH = 0.5)
	battle_name = "Canadian Fields"
	mission_start_message = "<font size=4>The <b>French</b> and <b>British</b> armies are facing each other in Canada! Get ready for the line battle! It will start in <b>5 minutes</b></font>"
	faction1 = BRITISH
	faction2 = FRENCH
	ambience = list('sound/ambience/jungle1.ogg')

obj/map_metadata/fields/job_enabled_specialcheck(var/datum/job/J)
	..()
	if (J.is_army == TRUE)
		. = TRUE
	else
		. = FALSE
/obj/map_metadata/fields/faction2_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 3000 || admin_ended_all_grace_periods)

/obj/map_metadata/fields/faction1_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 3000 || admin_ended_all_grace_periods)


	#undef NO_WINNER