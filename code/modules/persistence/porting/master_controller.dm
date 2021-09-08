//simplified MC that is designed to fail when procs 'break'. When it fails it's just replaced with a new one.
//It ensures master_controller.process() is never doubled up by killing the MC (hence terminating any of its sleeping procs)
//WIP, needs lots of work still
proc/string_explode(var/string, var/separator = "")
	//writepanic("[__FILE__].[__LINE__] \\/proc/string_explode() called tick#: [world.time]")
	if(istext(string) && (istext(separator) || isnull(separator)))
		return splittext(string, separator)
        
/proc/start_watch()
	return TimeOfGame

/proc/stop_watch(wh)
	return round(0.1 * (TimeOfGame - wh), 0.1)

var/global/datum/controller/game_controller/master_controller //Set in world.New()

var/global/controller_iteration = 0
var/global/last_tick_duration = 0

var/global/air_processing_killed = 0
var/global/pipe_processing_killed = 0

/datum/controller
	var/processing = 0
	var/iteration = 0
	var/processing_interval = 0

/datum/controller/proc/recover() // If we are replacing an existing controller (due to a crash) we attempt to preserve as much as we can.

/datum/controller/game_controller
	var/list/shuttle_list											// For debugging and VV

/datum/controller/game_controller/New()
	//There can be only one master_controller. Out with the old and in with the new.
	if(master_controller != src)
		if(istype(master_controller))
			qdel(master_controller)
		master_controller = src

	var/watch=0
	if(!job_master)
		watch = start_watch()
		job_master = new /datum/controller/occupations()
		job_master.SetupOccupations()
		log_startup_progress("Job setup complete in [stop_watch(watch)]s.")

/datum/controller/game_controller/Destroy()
	..()
	return 4

/datum/controller/game_controller/proc/setup()
	world.tick_lag = config.Ticklag

	ticker.loadstation()
	setup_objects()

/datum/controller/game_controller/proc/setup_objects()
	var/watch = start_watch()
	var/count = 0
	var/overwatch = start_watch() // Overall.

	watch = start_watch()
	log_startup_progress("Initializing objects...")
	for(var/atom/movable/object in world)
		object.initialize()
		count++
	log_startup_progress("	Initialized [count] objects in [stop_watch(watch)]s.")

	log_startup_progress("Finished object initializations in [stop_watch(overwatch)]s.")