#define NO_WINNER "The fighting for the town is still going on."
/obj/map_metadata/little_creek
	ID = MAP_LITTLE_CREEK
	title = "Big Trouble in Little Creek (100x100x2)"
	lobby_icon_state = "wildwest"
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall/)
	respawn_delay = 1200
	squad_spawn_locations = FALSE
//	min_autobalance_players = 90
	faction_organization = list(
		CIVILIAN,)
	available_subfactions = list(
		)
	roundend_condition_sides = list(
		list(CIVILIAN) = /area/caribbean/british
		)
	age = "1873"
	faction_distribution_coeffs = list(CIVILIAN = 1)
	battle_name = "Little Creek"
	mission_start_message = "<font size=4>At the small frontier town of <b>Little Creek</b>, the Sheriff recieves a warning: A group of outlaws is about to rob the town's bank! He must organize the bank's defense and prevent them...</font>"
	faction1 = CIVILIAN
	ambience = list('sound/ambience/desert.ogg')
	gamemode = "Bank Robbery"
	songs = list(
		"The Good, the Bad, and the Ugly Theme:1" = 'sound/music/good_bad_ugly.ogg',)
obj/map_metadata/little_creek/job_enabled_specialcheck(var/datum/job/J)
	..()
	if (J.is_cowboy == TRUE)
		. = TRUE
	else
		. = FALSE
/obj/map_metadata/fields/faction2_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 2400 || admin_ended_all_grace_periods)

/obj/map_metadata/fields/faction1_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 2400 || admin_ended_all_grace_periods)

/obj/map_metadata/colony/cross_message(faction)
	return "The grace wall is lifted!"

	#undef NO_WINNER