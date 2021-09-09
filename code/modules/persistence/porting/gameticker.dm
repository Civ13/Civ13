//////////////////////////////////
///PERSISTENCE STUFF/////////////
/////////////////////////////////

#define TICK_LIMIT_RUNNING 90
#define TICK_LIMIT_TO_RUN 85

#define TICK_CHECK ( world.tick_usage > TICK_LIMIT_RUNNING ? stoplag() : 0 )

/proc/log_startup_progress(var/message)
	to_chat(world, "<span class='danger'>[message]</span>")

//Key thing that stops lag. Cornerstone of performance in ss13, Just sitting here, in unsorted.dm.
/proc/stoplag()
	. = 1
	sleep(world.tick_lag)
	if(world.tick_usage > TICK_LIMIT_TO_RUN) //woke up, still not enough tick, sleep for more.
		. += 2
		sleep(world.tick_lag*2)
		if(world.tick_usage > TICK_LIMIT_TO_RUN) //woke up, STILL not enough tick, sleep for more.
			. += 4
			sleep(world.tick_lag*4)
			//you might be thinking of adding more steps to this, or making it use a loop and a counter var
			//	not worth it.

/datum/controller/gameticker/proc/savestation()
	var/watch = start_watch()
	to_chat(world, "<FONT color='yellow'><B>SAVING THE MAP! THIS USUALLY TAKES UNDER A MINUTE</B></FONT>")
	sleep(5)
	map_storage.Save_World()
	log_startup_progress("	Saved the map in [stop_watch(watch)]s.")
	return 1

/datum/controller/gameticker/proc/loadstation()
	var/watch = start_watch()
	var/started = 0
	log_startup_progress("Starting map load...")
	sleep(1)
	map_storage.ClearMap()
	sleep(1)
	map_storage.Load_World()
	if(started)
		log_startup_progress("	Loaded the map in [stop_watch(watch)]s.")
	return 1