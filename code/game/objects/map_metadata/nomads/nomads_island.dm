
/obj/map_metadata/nomads/island
	ID = MAP_NOMADS_ISLAND
	title = "Nomads (Island)"
	research_active = TRUE

	var/real_season = "wet"
	var/eruptions_enabled = TRUE

/obj/map_metadata/nomads/island/New()
	..()
	spawn(2000)
		eruption_check()
	spawn(1800)
		if (season == "SPRING") //fixes game setting the season as spring
			season = "Wet Season"


/obj/map_metadata/nomads/island/proc/eruption_check()
	spawn(rand(72000,126000))
		if (eruptions_enabled)
			do_eruption()
		eruption_check()
		
/obj/map_metadata/nomads/island/proc/do_eruption()
	if (eruptions_enabled)
		if (clients.len>5)
			to_chat(world, "<big><b>The mountain rumbles, while clouds of smoke emerge from the top... An eruption might be coming...</b></big>")
			spawn(rand(4800,6000))
				if (clients.len>5)
					volcano_eruption()
				return
		else
			return FALSE
	else
		return FALSE