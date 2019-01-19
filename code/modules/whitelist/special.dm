/datum/whitelist/jobs
	name = "jobs"

/datum/whitelist/jobs/validate(_arg)
	if (!enabled)
		return TRUE
	if (isclient(_arg))
		var/client/C = _arg
		var/path = "[config.masterdir]/1713/whitelist.txt"
		var/full_list = file2text(path)
		var/list/full_list_split = splittext(full_list, "\n")
		for (var/v = TRUE, v < full_list_split.len, v++)
			var/list/linesplit = splittext(full_list_split[v], "=")
			if (linesplit[1] == C.ckey)
				return TRUE
			if (ckey(linesplit[1]) == C.ckey)
				return TRUE
			if (lowertext(linesplit[1]) == C.ckey)
				return TRUE
	return FALSE