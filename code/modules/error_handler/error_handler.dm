GLOBAL_VAR_INIT(total_runtimes, 0)
GLOBAL_VAR_INIT(total_runtimes_skipped, 0)

#ifdef DEBUG
#define ERROR_USEFUL_LEN 2

/world/Error(exception/e, datum/e_src)
	if(!istype(e)) //Something threw an unusual exception
		log_to_dd("\[[time_stamp()]] Uncaught exception: [e]")
		return ..()

	var/static/list/error_last_seen = list()
	var/static/list/error_cooldown = list() /* Error_cooldown items will either be positive(cooldown time) or negative(silenced error)
												If negative, starts at -1, and goes down by 1 each time that error gets skipped*/

	if(!error_last_seen) // A runtime is occurring too early in start-up initialization
		return ..()

	GLOB.total_runtimes++

	var/erroruid = "[e.file],[e.line]"
	var/last_seen = error_last_seen[erroruid]
	var/cooldown = error_cooldown[erroruid] || 0

	if(last_seen == null)
		error_last_seen[erroruid] = world.time
		last_seen = world.time

	if(cooldown < 0)
		error_cooldown[erroruid]-- //Used to keep track of skip count for this error
		GLOB.total_runtimes_skipped++
		return //Error is currently silenced, skip handling it
	//Handle cooldowns and silencing spammy errors
	var/silencing = FALSE

	//Each occurence of an unique error adds to its cooldown time...
	cooldown = max(0, cooldown - (world.time - last_seen)) + ERROR_COOLDOWN
	// ... which is used to silence an error if it occurs too often, too fast
	if(cooldown > ERROR_MAX_COOLDOWN)
		cooldown = -1
		silencing = TRUE
		spawn(0)
			usr = null
			sleep(ERROR_SILENCE_TIME)
			var/skipcount = abs(error_cooldown[erroruid]) - 1
			error_cooldown[erroruid] = 0
			if(skipcount > 0)
				log_to_dd("\[[time_stamp()]] Skipped [skipcount] runtimes in [e.file],[e.line].")
				GLOB.error_cache.log_error(e, skip_count = skipcount)

	error_last_seen[erroruid] = world.time
	error_cooldown[erroruid] = cooldown

	var/list/usrinfo = null
	var/locinfo
	if(istype(usr))
		usrinfo = list("  usr: [log_info_line(usr)]")
		locinfo = log_info_line(usr.loc)
		if(locinfo)
			usrinfo += "  usr.loc: [locinfo]"
	// The proceeding mess will almost definitely break if error messages are ever changed
	var/list/splitlines = splittext(e.desc, "\n")
	var/list/desclines = list()
	if(LAZYLEN(splitlines) > ERROR_USEFUL_LEN) // If there aren't at least three lines, there's no info
		for(var/line in splitlines)
			if(LAZYLEN(line) < 3 || findtext(line, "source file:") || findtext(line, "usr.loc:"))
				continue
			if(findtext(line, "usr:"))
				if(usrinfo)
					desclines.Add(usrinfo)
					usrinfo = null
				continue // Our usr info is better, replace it

			if(copytext(line, 1, 3) != "  ")
				desclines += ("  " + line) // Pad any unpadded lines, so they look pretty
			else
				desclines += line
	if(usrinfo) //If this info isn't null, it hasn't been added yet
		desclines.Add(usrinfo)
	if(silencing)
		desclines += "  (This error will now be silenced for [ERROR_SILENCE_TIME / 600] minutes)"
	

	// Now to actually output the error info...
	log_to_dd("\[[time_stamp()]] Runtime in [e.file],[e.line]: [e]")
	for(var/line in desclines)
		log_to_dd(line)
	if(GLOB.error_cache)
		GLOB.error_cache.log_error(e, desclines, e_src = e_src)
		
#endif

/proc/log_runtime(exception/e, datum/e_src, extra_info)
	if(!istype(e))
		world.Error(e, e_src)
		return

	if(extra_info)
		// Adding extra info adds two newlines, because parsing runtimes is funky
		if(islist(extra_info))
			e.desc = "  [jointext(extra_info, "\n  ")]\n\n" + e.desc
		else
			e.desc = "  [extra_info]\n\n" + e.desc

	world.Error(e, e_src)

#undef ERROR_USEFUL_LEN