//TODO: rewrite and standardise all controller datums to the datum/controller type
//TODO: allow all controllers to be deleted for clean restarts (see WIP master controller stuff) - MC done - lighting done
/client/proc/restart_controller()
	set category = "Debug"
	set name = "Restart Process"
	set desc = "Restart one of the various periodic loop controllers for the game (be careful!)"

	if (!check_rights(R_SERVER)) return

	var/process = input(src, "Which process?") in list("Cancel") | processScheduler.nameToProcessMap
	if (process == "Cancel")
		return

	processScheduler.restartProcess(process)

	message_admins("Admin [key_name_admin(usr)] has restarted the [process] process.")
	return

var/list/special_globalobjects = list("processScheduler", "Master", "Ticker", "Configuration", "Observation","Whitelists", "Job Master")
/client/proc/debug_controller()
	set category = "Debug"
	set name = "Debug Controller/GlobalObjects"
	set desc = "Debug various objects and loops for the game (be careful!)"

	if (!holder)	return

	var/list/globals = special_globalobjects.Copy()
	for (var/controller in processScheduler.nameToProcessMap)
		if (!globals.Find(controller))
			globals += controller

	var/datum = input("Which datum?") in globals

	switch(datum)

		if ("processScheduler")
			if (processScheduler)
				debug_variables(processScheduler)

/*		if ("Master")
			debug_variables(master_controller)*/

		if ("Ticker")
			debug_variables(ticker)

		if ("Configuration")
			debug_variables(config)

		if ("Observation")
			debug_variables(all_observable_events)

		if ("Job Master")
			if (job_master)
				debug_variables(job_master)

		else
			debug_variables(processScheduler.nameToProcessMap[datum])

	message_admins("Admin [key_name_admin(usr)] is debugging the [datum] controller.")
	return
