
/obj/map_metadata/nomads/divide
	ID = MAP_NOMADS_DIVIDE
	title = "Nomads (Jungle-Desert)"
	description = "Battle on the Nomads (Jungle-Desert) map."
	research_active = TRUE

	var/real_season = "wet"

/obj/map_metadata/nomads/divide/New()
	..()
	spawn(1200)
		if (season == "SPRING") //fixes game setting the season as spring
			season = "Wet Season"
