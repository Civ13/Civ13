/proc/get_job_datums()
	var/list/occupations = list()
	var/list/all_jobs = typesof(/datum/job)

	for (var/A in all_jobs)
		var/datum/job/job = new A()
		if (!job)	continue
		occupations += job

	return occupations