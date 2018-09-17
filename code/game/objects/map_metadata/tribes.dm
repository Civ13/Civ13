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
	front = "Pacific"
	faction_distribution_coeffs = list(INDIANS = 1)
	battle_name = "the tribes"
	var/targetnr = 2
	var/targetnr_text= "2"
	mission_start_message = "<big>Six tribes have been inhabiting this area for generations. Will they be able to get along?</big>"
	ambience = list('sound/ambience/jungle1.ogg')
	faction1 = INDIANS
	single_faction = TRUE
	songs = list(
		"Words Through the Sky:1" = 'sound/music/words_through_the_sky.ogg',)
obj/map_metadata/colony/job_enabled_specialcheck(var/datum/job/J)
	if (istype(J, /datum/job/indians/tribes))
		. = TRUE
	else
		. = FALSE
/obj/map_metadata/colony/faction2_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 15000 || admin_ended_all_grace_periods)

/obj/map_metadata/colony/faction1_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 15000 || admin_ended_all_grace_periods)

/obj/map_metadata/tribes/cross_message(faction)
	return ""

#undef NO_WINNER