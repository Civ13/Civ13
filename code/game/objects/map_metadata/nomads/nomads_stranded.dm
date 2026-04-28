/obj/map_metadata/nomads/stranded
	ID = MAP_NOMADS_STRANDED
	title = "Nomads (stranded)"
	age = "2015 A.D."
	battle_name = "Stranded Island"
	mission_start_message = "<big>The ship has crashed and people are still washing ashore. Will they be able to work together to survive?</big><br><b>Wiki Guide: https://civ13.github.io/civ13-wiki/Civilizations_and_Nomads</b>"
	research_active = FALSE

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

/obj/map_metadata/nomads/stranded/New()
	..()
	spawn(1800)
		if (season == "SPRING") //fixes game setting the season as spring
			season = "Wet Season"