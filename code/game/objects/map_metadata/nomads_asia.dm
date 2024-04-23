/obj/map_metadata/nomads_asia
	ID = MAP_NOMADS_ASIA
	title = "Nomads (Asia)"
	lobby_icon = 'icons/lobby/civilizations.gif'
	no_winner ="The round is proceeding normally."
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall/)
	respawn_delay = 6000 // 10 minutes!
	has_hunger = TRUE
	faction_organization = list(
		CIVILIAN,)

	roundend_condition_sides = list(
		list(CIVILIAN) = /area/caribbean/british
		)
	age = "5000 B.C."
	civilizations = TRUE
	var/tribes_nr = 1
	faction_distribution_coeffs = list(CIVILIAN = 1)
	battle_name = "the civilizations"
	mission_start_message = "<big>After the collapse of the previous civilizations inhabiting this continent, people are starting to form groups and settle down. Will they be able to work together?</big><br><b>Wiki Guide: https://civ13.github.io/civ13-wiki/Civilizations_and_Nomads</b>"
	ambience = list('sound/ambience/jungle1.ogg')
	faction1 = CIVILIAN
	availablefactions = list("Nomad")
	songs = list(
		"Words Through the Sky:1" = "sound/music/words_through_the_sky.ogg",)
	research_active = TRUE
	nomads = TRUE
	gamemode = "Classic (Stone Age Start)"
	var/list/arealist_r = list()
	var/list/arealist_g = list()
/obj/map_metadata/nomads_asia/New()
	..()
	spawn(18000)
		seasons()

/obj/map_metadata/nomads_asia/cross_message(faction)
	return ""

/obj/map_metadata/nomads_asia/job_enabled_specialcheck(var/datum/job/J)
	if (J.is_nomad == TRUE)
		. = TRUE
	else
		. = FALSE

/obj/map_metadata/nomads_asia/seasons()
	..() //call the parent process, so everything applies as usual
	if (season ==  "SUMMER" || season == "FALL")
		for (var/turf/floor/beach/water/flooded/DF) // Directly change, you have no Z levels on your map
			DF.ChangeTurf(/turf/floor/dirt/flooded)
	else
		for (var/turf/floor/dirt/flooded/DF) // Directly change, you have no Z levels on your map
			DF.ChangeTurf(/turf/floor/beach/water/flooded)