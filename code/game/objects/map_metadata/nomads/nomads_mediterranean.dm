
/obj/map_metadata/nomads/mediterranean
	ID = MAP_NOMADS_MEDITERRANEAN
	title = "Nomads (Mediterranean)"
	description = "Battle on the Nomads (Mediterranean) map."
	research_active = TRUE

/obj/map_metadata/nomads/mediterranean/New()
	..()
	spawn(2500)
		for (var/i = 1, i <= 35, i++)
			var/turf/areaspawn = safepick(get_area_turfs(/area/caribbean/sea/sea))
			new/obj/structure/fish(areaspawn)