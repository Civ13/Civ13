/* the jobs whitelist has special behavior for validate() and must be called
   with two args. Job datums have their own validate() proc, which is a wrapper
   for the whitelist procedure (ie it calls this datum's validate()) and only
   takes one arg. Therefore, you never need to call whitelist/jobs.validate()
   directly, you only need to call job.validate(new_player). */

/datum/whitelist/jobs
	name = "jobs"

/datum/whitelist/jobs/validate(_arg, var/desired_job_title)
	if (!enabled)
		return TRUE
	var/list/datalist = splittext(data, "&")
	if (isclient(_arg))
		var/client/C = _arg
		for (var/datum in datalist)
			if (findtext(datum, C.ckey) && findtext(datum, desired_job_title))
				return TRUE
	else if (istext(_arg))
		var/ckey = ckey(_arg)
		for (var/datum in datalist)
			if (findtext(datum, ckey) && findtext(datum, desired_job_title))
				return TRUE
	return FALSE

/datum/whitelist/super
	name = "super"

/datum/whitelist/super/validate(_arg, var/desired_job_title)
	if (!enabled)
		return TRUE
	var/list/datalist = splittext(data, "&")
	if (isclient(_arg))
		var/client/C = _arg
		for (var/datum in datalist)
			if (findtext(datum, C.ckey) && findtext(datum, desired_job_title))
				return TRUE
	else if (istext(_arg))
		var/ckey = ckey(_arg)
		for (var/datum in datalist)
			if (findtext(datum, ckey) && findtext(datum, desired_job_title))
				return TRUE
	return FALSE