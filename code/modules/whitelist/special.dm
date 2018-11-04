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
	if (isclient(_arg))
		_arg = _arg:ckey
	var/path = "/home/1713/1713/whitelist.txt"
	for (var/ckey2discord_id in file2list(path))
		var/_ckey = splittext(ckey2discord_id, "=")[1]
		if (_ckey == _arg)
			return TRUE
		if (ckey(_ckey) == _arg)
			return TRUE
		if (lowertext(_ckey) == _arg)
			return TRUE
	return FALSE