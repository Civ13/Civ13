#define NO_WINNER "The round is proceeding normally."
/obj/map_metadata/tribes
	ID = MAP_TRIBES
	title = "Tribes (225x225x2)"
	lobby_icon_state = "tribes"
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall/)
	respawn_delay = 6000 // 10 minutes!
	squad_spawn_locations = FALSE
//	min_autobalance_players = 90
	faction_organization = list(
		INDIANS,)
	available_subfactions = list(
		)
	roundend_condition_sides = list(
		list(INDIANS) = /area/caribbean/british
		)
	age = "5000 B.C."
	faction_distribution_coeffs = list(INDIANS = 1)
	battle_name = "the tribes"
	mission_start_message = "<big>Six tribes have been inhabiting this area for generations. Will they be able to get along?</big>"
	ambience = list('sound/ambience/jungle1.ogg')
	faction1 = INDIANS
	single_faction = TRUE
	availablefactions_run = TRUE
	songs = list(
		"Words Through the Sky:1" = 'sound/music/words_through_the_sky.ogg',)
obj/map_metadata/tribes/job_enabled_specialcheck(var/datum/job/J)
	..()
	if (istype(J, /datum/job/indians/tribes))
		. = TRUE
	else if (istype(J, /datum/job/indians/carib) || istype(J, /datum/job/indians/carib_chief) || istype(J, /datum/job/indians/carib_shaman))
		. = FALSE
	else
		. = FALSE
/obj/map_metadata/tribes/faction2_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 15000 || admin_ended_all_grace_periods)

/obj/map_metadata/tribes/faction1_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 15000 || admin_ended_all_grace_periods)

/obj/map_metadata/tribes/cross_message(faction)
	return ""

#undef NO_WINNER