/obj/map_metadata/nomads_stranded
	ID = MAP_NOMADS_STRANDED
	title = "Nomads (stranded)"
	lobby_icon = "icons/lobby/civ13.gif"
	no_winner ="The round is proceeding normally."
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall/)
	respawn_delay = 6000 // 10 minutes!
	has_hunger = TRUE

	faction_organization = list(
		CIVILIAN,)

	roundend_condition_sides = list(
		list(CIVILIAN) = /area/caribbean/british
		)
	age = "2015 A.D."
	civilizations = TRUE
	var/tribes_nr = 1
	faction_distribution_coeffs = list(CIVILIAN = 1)
	battle_name = "Stranded Island"
	mission_start_message = "<big>The ship has crashed and people are still washing ashore. Will they be able to work together to survive?</big><br><b>Wiki Guide: https://civ13.github.io/civ13-wiki/Civilizations_and_Nomads</b>"
	ambience = list('sound/ambience/jungle1.ogg')
	faction1 = CIVILIAN
	availablefactions = list("Nomad")
	songs = list(
		"Words Through the Sky:1" = "sound/music/words_through_the_sky.ogg",)
	research_active = FALSE
	nomads = TRUE
	gamemode = "Stranded Island (Modern)"
	var/real_season = "wet"
	ordinal_age = 8
	default_research = 230
	age1_done = TRUE
	age2_done = TRUE
	age3_done = TRUE
	age4_done = TRUE
	age5_done = TRUE
	age6_done = TRUE
	age7_done = TRUE
	age8_done = TRUE

/obj/map_metadata/nomads_stranded/New()
	..()
	spawn(1800)
		if (season == "SPRING") //fixes game setting the season as spring
			season = "Wet Season"
	spawn(18000)
		seasons()


/obj/map_metadata/nomads_stranded/cross_message(faction)
	return ""

/obj/map_metadata/nomads_stranded/job_enabled_specialcheck(var/datum/job/J)
	if (J.is_nomad == TRUE)
		. = TRUE
	else
		. = FALSE