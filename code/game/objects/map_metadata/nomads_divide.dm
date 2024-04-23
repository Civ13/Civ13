
/obj/map_metadata/nomads_divide
	ID = MAP_NOMADS_DIVIDE
	title = "Nomads (Jungle-Desert)"
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
	mission_start_message = "<big>After ages as hunter-gatherers, people are starting to form groups and settle down. Will they be able to work together?</big><br><b>Wiki Guide: https://civ13.github.io/civ13-wiki/Civilizations_and_Nomads</b>"
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
	var/real_season = "wet"
/obj/map_metadata/nomads_divide/New()
	..()

	spawn(1200)
		if (season == "SPRING") //fixes game setting the season as spring
			season = "Wet Season"
	spawn(20000)
		seasons()

/obj/map_metadata/nomads_divide/cross_message(faction)
	return ""

/obj/map_metadata/nomads_divide/job_enabled_specialcheck(var/datum/job/J)
	if (J.is_nomad == TRUE)
		. = TRUE
	else
		. = FALSE
