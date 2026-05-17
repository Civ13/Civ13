
/obj/map_metadata/nomads/jungle
	ID = MAP_NOMADS_JUNGLE
	title = "Nomads (Jungle)"
	description = "Battle on the Nomads (Jungle) map."
	research_active = TRUE

	var/real_season = "wet"

/obj/map_metadata/nomads/jungle/New()
	..()
	spawn(1800)
		if (season == "SPRING") //fixes game setting the season as spring
			season = "Wet Season"