
/obj/map_metadata/nomads/desert
	ID = MAP_NOMADS_DESERT
	title = "Nomads (Desert)"
	ambience = list('sound/ambience/desert.ogg')
	research_active = TRUE
	var/real_season = "wet"

/obj/map_metadata/nomads/desert/New()
	..()
	spawn(1800)
		if (season == "SPRING") //fixes game setting the season as spring
			season = "Wet Season"