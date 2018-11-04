/* the jobs whitelist has special behavior for validate() and must be called
   with two args. Job datums have their own validate() proc, which is a wrapper
   for the whitelist procedure (ie it calls this datum's validate()) and only
   takes one arg. Therefore, you never need to call whitelist/jobs.validate()
   directly, you only need to call job.validate(new_player). */

/datum/whitelist/jobs
	name = "jobs"

/datum/whitelist/jobs/validate(_arg)
	if (!enabled)
		return TRUE
	var/path = "/home/1713/1713/whitelist.txt"
	var/full_list = file2text(path)
	var/list/full_list_split = splittext(full_list, "\n")
	for (var/v = TRUE, v < full_list_split.len, v++)
		var/list/linesplit = splittext(full_list_split[v], "=")
		if (linesplit[1] == _arg.ckey)
			return TRUE
		if (ckey(linesplit[1]) == _arg.ckey)
			return TRUE
		if (lowertext(linesplit[1]) == _arg.ckey)
			return TRUE
	return FALSE