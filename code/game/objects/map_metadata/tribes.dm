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
	valid_weather_types = list(WEATHER_RAIN, WEATHER_NONE, WEATHER_STORM, WEATHER_SMOG)
	availablefactions = list("Orc tribesman")
	availablefactions_run = TRUE
	civilizations = TRUE
	songs = list(
		"Words Through the Sky:1" = 'sound/music/words_through_the_sky.ogg',)
	gamemode = "Faction-Based RP"
/obj/map_metadata/tribes/New()
	var/newnamea = list("Orc Horde" = list(48,48,48,null,0,"skull","#9A1313","#000000"))
	var/newnameb = list("Ant Colony" = list(21,21,21,null,0,"star","#0C1EA7","#67A7CE"))
	var/newnamec = list("Gorilla Tribe" = list(27,32,30,null,0,"sun","#9A9A9A","#098518"))
	var/newnamed = list("Human Kingdom" = list(62,62,62,null,0,"cross","#E5C100","#FFFFFF"))
	var/newnamee = list("Lizard Clan" = list(21,21,21,null,0,"big_cross","#669932","#1E1E1E"))
	var/newnamef = list("Wolfpack" = list(21,21,21,null,0,"moon","#FFFFFF","#848484"))
	var/newnameg = list("Crustacean Union" = list(21,21,21,null,0,"seashell","#EEEEEE","#7F0000"))
	custom_civs += newnamea
	custom_civs += newnameb
	custom_civs += newnamec
	custom_civs += newnamed
	custom_civs += newnamee
	custom_civs += newnamef
	custom_civs += newnameg

	spawn(1)
		civilians_forceEnabled = TRUE
	..()

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