
/obj/map_metadata/nomads/island
	ID = MAP_NOMADS_ISLAND
	title = "Nomads (Island)"
	research_active = TRUE

	var/real_season = "wet"
	var/eruptions_enabled = TRUE

/obj/map_metadata/nomads/island/New()
	..()
	if(!durable_schedule("nomads_eruption_boot", 2000))
		spawn(2000)
			eruption_check()
	if(!durable_schedule("nomads_initial_climate", 1800))
		spawn(1800)
			if (season == "SPRING") //fixes game setting the season as spring
				season = "Wet Season"


/obj/map_metadata/nomads/island/proc/eruption_check()
	var/delay = rand(72000,126000)
	if(durable_schedule("nomads_eruption_check", delay)) return
	spawn(delay)
		if (eruptions_enabled)
			do_eruption()
		eruption_check()
		
/obj/map_metadata/nomads/island/proc/do_eruption()
	if (eruptions_enabled)
		if (clients.len>5)
			to_chat(world, "<big><b>The mountain rumbles, while clouds of smoke emerge from the top... An eruption might be coming...</b></big>")
			var/delay = rand(4800,6000)
			if(durable_schedule("nomads_eruption_fire", delay)) return TRUE
			spawn(delay)
				if (clients.len>5)
					volcano_eruption()
				return
		else
			return FALSE
	else
		return FALSE