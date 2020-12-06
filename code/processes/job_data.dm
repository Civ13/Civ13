/* the job selection in new_player.dm and helper functions can incur massive overhead that makes them laggy and unresponsive
 * on highpop. This solves that - Kachnov */

// relevant clients stuff is gone now, it was too expensive, destabilized processes, and there was absolutely no way to fix it - Kachnov

/process/job_data
	var/list/job2players = list()

/process/job_data/setup()
	name = "job data"
	schedule_interval = 1 SECOND
	start_delay = 0 SECONDS
	fires_at_gamestates = list()
	priority = PROCESS_PRIORITY_IRRELEVANT
	processes.job_data = src

/process/job_data/fire()
	return

/process/job_data/proc/get_active_positions(var/datum/job/J)
	. = 0
	if (!job2players[J.title] || !islist(job2players[J.title]))
		return .
	for (var/mob/M in job2players[J.title])
		if (M.mind && M.client && M.mind.assigned_role == J.title && M.client.inactivity <= 10 * 60 * 10)
			++.

/process/job_data/proc/get_active_positions_name(var/J)
	. = 0
	if (!job2players[J] || !islist(job2players[J]))
		return .
	for (var/mob/M in job2players[J])
		if (M.mind && M.client && M.mind.assigned_role == J && M.client.inactivity <= 10 * 60 * 10)
			++.