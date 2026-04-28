/obj/map_metadata/nomads/africa
	ID = MAP_NOMADS_AFRICA
	title = "Nomads (Africa)"
	research_active = TRUE

	var/eruptions_enabled = TRUE

/obj/map_metadata/nomads/africa/New()
	..()
	spawn(2000)
		eruption_check()

/obj/map_metadata/nomads/africa/proc/eruption_check()
	spawn(rand(33000,40000))
		if (eruptions_enabled)
			do_eruption()
		eruption_check()

/obj/map_metadata/nomads/africa/proc/do_eruption()
	if (eruptions_enabled)
		if (clients.len>5)
			world << "<big><b>The mountain rumbles, while clouds of smoke emerge from the top... An eruption might be coming...</b></big>"
			spawn(rand(4800,6000))
				if (clients.len>5)
					volcano_eruption()
					return TRUE
				else
					return FALSE
		else
			return FALSE
	else
		return FALSE

/obj/map_metadata/nomads/africa/volcano_eruption()
	for(var/turf/wall/rockwall/lavaspawner/L in world)
		L.start_lava_flow()
	world << "<font color='red'><big><b>The volcano erupts, with lava flowing down the mountain!</b></big></font>"
	return TRUE