// Belt drives, factory belts, transfer arms and fed saw mills step once a second. Idle belts and arms
// leave their lists, so an empty factory costs nothing here. A large factory
// resumes within the tick budget instead of stalling the server tick.
/datum/process_list/var/process/factory_belts/factory_belts = null

/process/factory_belts/setup()
	name = "factory belts"
	schedule_interval = 10
	start_delay = 1 SECOND
	priority = PROCESS_PRIORITY_MEDIUM
	fires_at_gamestates = list(GAME_STATE_PLAYING, GAME_STATE_FINISHED)
	processes.factory_belts = src

// A new snapshot starts a new belt step.
/process/factory_belts/reset_current_list()
	factory_belts_begin_step()
	PROCESS_USE_FASTEST_LIST(factory_active_belts)

/process/factory_belts/fire()
	for (current in current_list)
		var/obj/structure/factory_belt/B = current
		if (QDELETED(B))
			factory_active_belts -= B
		else
			B.belt_step()
		PROCESS_LIST_CHECK
		PROCESS_TICK_CHECK
	factory_arms_step()
	factory_mills_step()

/process/factory_belts/statProcess(client/C)
	..(C)
	C.add_stat("[factory_active_belts.len] active belts, [factory_active_arms.len] active arms, [factory_powered_drives.len]/[factory_active_drives.len] powered drives")
