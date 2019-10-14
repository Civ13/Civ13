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
			queue -= C
			continue
		if (world.time >= C.time)
			if (hascall(C.object, C.function))
				if (C.args && C.args.len)
					call(C.object, C.function)(arglist(C.args))
				else
					call(C.object, C.function)()
			else
				log_debug("Callproc process callproc for a '[C.object]' failed because it didn't have the proc '[C.function]'")

			// just in case we don't reset all args, somehow
			C.object = null
			C.function = ""
			C.args = null
			C.time = -1

			// remove it from queue, add to helpers
			queue -= C
			helpers += C

/* function_as_path must be an absolute path because compile errors are better than runtime errors
 * it might work if you supply a relative path due to the way splittext() works, but don't - Kachnov */

/process/callproc/proc/queue(object, function_as_path, args = null, time = 10)
	// turn "/object/proc/name" into "name"
	var/list/function_as_list = splittext(path2text(function_as_path), "/")
	var/function = function_as_list[function_as_list.len]

	// get a callproc_helper and assign it to this function
	if (helpers)
		var/callproc_helper/C = helpers[1]
		C.object = object
		C.function = function
		C.args = args
		C.time = world.time + time
		helpers -= C
		queue += C

/* remove all callproc_helpers for an object to ensure they don't get piled up and called later
 * can be very expensive - Kachnov */
/process/callproc/proc/unqueue(object, maxtimes = INFINITY)
	. = FALSE
	for (var/helper in queue)
		var/callproc_helper/C = helper
		if (C && C.object == object)
			. = TRUE
			queue -= helper
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