/*#define PROCESS_SUPER_SLOWDOWN 4
#define PROCESS_HIGH_SLOWDOWN 3
#define PROCESS_MED_SLOWDOWN 2

var/hyperefficiency_mode = FALSE

/client/proc/toggle_hyperefficiency_mode()
	set category = "Debug"
	set name = "(WARNING!!!) Toggle Hyperefficiency Mode"
	if (!check_rights(R_HOST))
		return
	hyperefficiency_mode = !hyperefficiency_mode
	var/M = "[key_name(src)] [hyperefficiency_mode ? "enabled" : "disabled"] hyperefficiency mode. Tick usage will be [hyperefficiency_mode ? "be decreased" : "no longer be decreased"][hyperefficiency_mode ? " at the cost of slowing down vital & nonvital processes" : ""]."
	log_admin(M)
	message_admins(M)

	switch (hyperefficiency_mode)

		if (1)

			// slow down the train a bit
			if (german_train_master)
				german_train_master.velocity /= 1.25

			// slow down the mob process considerably
			mob_process.schedule_interval *= PROCESS_SUPER_SLOWDOWN

			// slow down the zoom process considerably
			zoom_process.schedule_interval *= PROCESS_HIGH_SLOWDOWN

			// slow down the obj process considerably
			obj_process.schedule_interval *= PROCESS_HIGH_SLOWDOWN

			// slow down the machinery process considerably
		//	machinery_process.schedule_interval *= PROCESS_HIGH_SLOWDOWN

			// pause unecessary processes
			weather_process.paused = TRUE
			time_of_day_process.paused = TRUE
			battlereport.paused = TRUE // this breaks the battlereport, which only works every 10 minutes anyway, so removed
//			inactivity_process.paused = TRUE // process is gone

			// slow down some vital processes a bit
			tickerProcess.schedule_interval *= PROCESS_MED_SLOWDOWN
			supplydrop_process.schedule_interval *= PROCESS_MED_SLOWDOWN

		if (0) // undo everything

			// undo train slowdown
			if (german_train_master)
				german_train_master.velocity = initial(german_train_master.velocity)

			// undo slowdown
			mob_process.schedule_interval /= PROCESS_SUPER_SLOWDOWN

			// undo slowdown
			zoom_process.schedule_interval /= PROCESS_HIGH_SLOWDOWN

			// undo slowdown
			obj_process.schedule_interval /= PROCESS_HIGH_SLOWDOWN

			// undo slowdown
		//	machinery_process.schedule_interval /= PROCESS_HIGH_SLOWDOWN

			// turn on unecessary processes
			weather_process.paused = FALSE
			time_of_day_process.paused = FALSE
			battlereport.paused = FALSE
//			inactivity_process.paused = FALSE // process is gone

			// undo slowdown
			tickerProcess.schedule_interval /= PROCESS_MED_SLOWDOWN
			supplydrop_process.schedule_interval /= PROCESS_MED_SLOWDOWN*/