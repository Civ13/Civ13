/datum/controller/gameticker/proc/savestation()
	var/watch = start_watch()
	to_chat(world, "<FONT color='blue'><B>SAVING THE MAP! THIS USUALLY TAKES UNDER 10 SECONDS</B></FONT>")
	map_storage.Save_Records()
	sleep(20)
	var/started = 0
	map_storage.Save_World(the_station_areas)
	log_startup_progress("	Saved the map in [stop_watch(watch)]s.")
	return 1

/datum/controller/gameticker/proc/loadstation()
	var/watch = start_watch()
	var/started = 0
	log_startup_progress("Starting map load...")
	map_storage.Load_World(the_station_areas)
	if(started)
	log_startup_progress("	Loaded the map in [stop_watch(watch)]s.")
	return 1