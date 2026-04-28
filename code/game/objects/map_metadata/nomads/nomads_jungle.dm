
/obj/map_metadata/nomads/jungle
	ID = MAP_NOMADS_JUNGLE
	title = "Nomads (Jungle)"
	research_active = TRUE

	var/real_season = "wet"

/obj/map_metadata/nomads/jungle/New()
	..()
	spawn(1800)
		if (season == "SPRING") //fixes game setting the season as spring
			season = "Wet Season"