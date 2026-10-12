// TEST-ONLY candidate. Not included by civ13.dme.
/process/callproc
	var/list/queue = list()
	var/list/helpers = list()

/process/callproc/setup()
	name = "callproc"
	schedule_interval = 0.03 SECONDS // every 1/33th second
	start_delay = 10
	fires_at_gamestates = list(GAME_STATE_PREGAME, GAME_STATE_SETTING_UP, GAME_STATE_PLAYING, GAME_STATE_FINISHED)
	priority = PROCESS_PRIORITY_VERY_HIGH

	for (var/v in 1 to 5000)
		helpers += new /callproc_helper

	processes.callproc = src

// there are no PROCESS_TICK_CHECKs here, because that would make this proc too unreliable (trains rely on this)
/process/callproc/fire()
	for (current in queue)
		var/callproc_helper/C = current
		if (!C || isDeleted(C.object) || !C.function)
			release_helper(C)
			continue
		if (world.time >= C.time)
			var/datum/target = C.object
			var/function = C.function
			var/list/proc_args = C.args
			release_helper(C)
			if (hascall(target, function))
				if (proc_args && proc_args.len)
					call(target, function)(arglist(proc_args))
				else
					call(target, function)()
			else
				log_debug("Callproc process callproc for a '[target]' failed because it didn't have the proc '[function]'")
	current = null

/process/callproc/proc/release_helper(callproc_helper/C)
	queue -= C
	if (!C)
		return
	C.object = null
	C.function = ""
	C.args = null
	C.time = -1
	if (helpers.len < 5000)
		helpers += C
	else
		qdel(C)

/* function_as_path must be an absolute path because compile errors are better than runtime errors
 * it might work if you supply a relative path due to the way splittext() works, but don't - Kachnov */

/process/callproc/proc/queue(object, function_as_path, proc_args = null, time = 10)
	// turn "/object/proc/name" into "name"
	var/list/function_as_list = splittext(path2text(function_as_path), "/")
	var/function = function_as_list[function_as_list.len]

	var/callproc_helper/C
	if (helpers.len)
		C = helpers[helpers.len]
		helpers.Cut(helpers.len, helpers.len + 1)
	else
		C = new
	C.object = object
	C.function = function
	C.args = proc_args
	C.time = world.time + time
	queue += C

/* remove all callproc_helpers for an object to ensure they don't get piled up and called later
 * can be very expensive - Kachnov */
/process/callproc/proc/unqueue(object, maxtimes = INFINITY)
	. = FALSE
	if (maxtimes <= 0)
		return .
	for (var/helper in queue)
		var/callproc_helper/C = helper
		if (C && C.object == object)
			. = TRUE
			release_helper(C)
			--maxtimes
			if (maxtimes <= 0)
				return .
	return .

/callproc_helper
	parent_type = /datum
	var/datum/object = null
	var/function = ""
	var/list/args = null
	var/time = -1
