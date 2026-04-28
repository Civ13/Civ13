
/obj/map_metadata/nomads/mountain
	
	ID = MAP_NOMADS_MOUNTAIN
	title = "Nomads (Mountain)"
	mission_start_message = "<big>Your people has lived in the mountains for ages. Now, its time to expand and dig deeper, but as your ancestors always said, the deeper you dig, the more dangerous it gets...</big><br><b>Wiki Guide: https://civ13.github.io/civ13-wiki/Civilizations_and_Nomads</b>"
	research_active = TRUE

	var/real_season = "wet"

/obj/map_metadata/nomads/mountain/New()
	..()
	spawn(1800)
		if (season == "SPRING") //fixes game setting the season as spring
			season = "Wet Season"


/obj/map_metadata/nomads/mountain/seasons()
	if (real_season == "dry")
		season = "Wet Season"
		world << "<big>The <b>Wet Season</b> has started.</big>"
		change_weather_somehow()
		for (var/turf/floor/beach/drywater/D)
			D.ChangeTurf(/turf/floor/beach/water/swamp)
		real_season = "wet"
	else
		season = "Dry Season"
		world << "<big>The <b>Dry Season</b> has started.</big>"
		change_weather_somehow()
		for (var/turf/floor/beach/water/swamp/D)
			D.ChangeTurf(/turf/floor/beach/drywater)
		real_season = "dry"
	spawn(18000)
		seasons()
