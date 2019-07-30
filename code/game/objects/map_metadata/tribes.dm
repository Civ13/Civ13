#define NO_WINNER "The round is proceeding normally."
/obj/map_metadata/tribes
	ID = MAP_TRIBES
	title = "Tribes (225x225x2)"
	lobby_icon_state = "civ13"
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall/)
	respawn_delay = 3600 // 6 minutes!
	squad_spawn_locations = FALSE
//	min_autobalance_players = 90
	faction_organization = list(
		CIVILIAN,)
	available_subfactions = list(
		)
	roundend_condition_sides = list(
		list(CIVILIAN) = /area/caribbean/british
		)
	age = "the lost time"
	ordinal_age = 2
	faction_distribution_coeffs = list(CIVILIAN = 1)
	battle_name = "the four tribes"
	mission_start_message = "<big>Four tribes are settling in this land. Will they be able to get along?<br>The grace wall will be up for <b>25 minutes</b>.</big>"
	ambience = list('sound/ambience/jungle1.ogg')
	faction1 = CIVILIAN
	is_singlefaction = TRUE
	availablefactions = list("Orc tribesman")
	availablefactions_run = TRUE
	songs = list(
		"Words Through the Sky:1" = 'sound/music/words_through_the_sky.ogg',)
	gamemode = "Faction-Based RP"
/obj/map_metadata/tribes/job_enabled_specialcheck(var/datum/job/J)
	..()
	if (istype(J, /datum/job/civilian/fantasy))
		. = TRUE
	else
		. = FALSE
/obj/map_metadata/tribes/faction2_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 15000 || admin_ended_all_grace_periods)

/obj/map_metadata/tribes/faction1_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 15000 || admin_ended_all_grace_periods)

/obj/map_metadata/tribes/cross_message(faction)
	return ""

#undef NO_WINNER