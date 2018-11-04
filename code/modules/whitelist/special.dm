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
	world << "importing whitelist..."
	var/full_list = file2text(path)
	var/list/full_list_split = splittext(full_list, "=")
	for (var/v = TRUE, v < full_list_split.len, v++)
		if (full_list_split[v][1] == _arg)
			world << "[full_list_split[v][1]]"
			return TRUE
		if (ckey(full_list_split[v][1]) == _arg)
			world << "[full_list_split[v][1]]"
			return TRUE
		if (lowertext(full_list_split[v][1]) == _arg)
			world << "[full_list_split[v][1]]"
			return TRUE
	return FALSE