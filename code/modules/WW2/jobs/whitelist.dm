// IF the job whitelist is enabled, are we whitelisted?
/datum/job/var/whitelisted = FALSE

/datum/job/var/super_whitelisted = TRUE

// validate a new_player via the "jobs" whitelist datum
/datum/job/proc/validate(var/mob/new_player/np)
	var/datum/whitelist/W = global_whitelists["jobs"]
	if (!W)
		return TRUE
	else if (config.use_job_whitelist)
		return W.validate(np.client)
	return TRUE
	var/datum/whitelist/Y = global_whitelists["super"]
	if (!Y)
		return TRUE
	else if (config.use_job_whitelist)
		return Y.validate(np.client)
	return TRUE
