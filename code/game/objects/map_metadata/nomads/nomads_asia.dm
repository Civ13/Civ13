/obj/map_metadata/nomads/asia
	ID = MAP_NOMADS_ASIA
	title = "Nomads (Asia)"
	mission_start_message = "<big>After the collapse of the previous civilizations inhabiting this continent, people are starting to form groups and settle down. Will they be able to work together?</big><br><b>Wiki Guide: https://civ13.github.io/civ13-wiki/gamemodes/Civilizations_and_Nomads</b>"
	research_active = TRUE

/obj/map_metadata/nomads/asia/seasons()
	..() //call the parent process, so everything applies as usual
	if (season ==  "SUMMER" || season == "FALL")
		for (var/turf/floor/beach/water/flooded/DF) // Directly change, you have no Z levels on your map
			DF.ChangeTurf(/turf/floor/dirt/flooded)
	else
		for (var/turf/floor/dirt/flooded/DF) // Directly change, you have no Z levels on your map
			DF.ChangeTurf(/turf/floor/beach/water/flooded)