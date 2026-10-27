/process/callproc
	var/list/queue = list()
	var/list/helpers = list()
	var/list/by_object = list()
	var/enqueued = 0
	var/invocations = 0
	var/cancelled = 0
	var/invalid = 0
	var/helpers_created = 0
	var/queue_high_water = 0

/process/callproc/setup()
	name = "callproc"
	schedule_interval = 0.03 SECONDS // every 1/33th second
	start_delay = 10
	fires_at_gamestates = list(GAME_STATE_PREGAME, GAME_STATE_SETTING_UP, GAME_STATE_PLAYING, GAME_STATE_FINISHED)
	priority = PROCESS_PRIORITY_VERY_HIGH

	for (var/v in 1 to 5000)
		helpers += new /callproc_helper
		helpers_created++

	processes.callproc = src

// there are no PROCESS_TICK_CHECKs here, because that would make this proc too unreliable (trains rely on this)
/process/callproc/fire()
	for (current in queue)
		var/callproc_helper/C = current
		if (!C || isDeleted(C.object) || !C.function)
			invalid++
			release_helper(C)
			continue
		if (world.time >= C.time)
			invocations++
			// Retire the helper before invoking user code, including exceptions/reentry.
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
	if (!C || !C.queued)
		return
	queue -= C
	C.queued = FALSE
	var/datum/index_target = C.index_target
	if (index_target)
		var/list/pending = by_object[index_target]
		pending -= C
		if (!pending.len)
			by_object -= index_target
	C.index_target = null
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
	// End removal avoids shifting the entire reserve on each scheduled call.
	if (helpers.len)
		C = helpers[helpers.len]
		helpers.Cut(helpers.len, helpers.len + 1)
	else
		C = new
		helpers_created++
	C.object = object
	C.function = function
	C.args = proc_args
	C.time = world.time + time
	queue += C
	C.queued = TRUE
	C.index_target = object
	if (object)
		var/list/pending = by_object[object]
		if (!pending)
			pending = list()
			by_object[object] = pending
		pending += C
	enqueued++
	queue_high_water = max(queue_high_water, queue.len)

// Cancellation visits only this target's pending callbacks, in enqueue order.
/process/callproc/proc/unqueue(object, maxtimes = INFINITY)
	. = FALSE
	if (maxtimes <= 0)
		return .
	var/list/pending = by_object[object]
	for (var/helper in pending)
		var/callproc_helper/C = helper
		if (C && C.object == object)
			. = TRUE
			cancelled++
			release_helper(C)
			--maxtimes
			if (maxtimes <= 0)
				return .
	return .

/process/callproc/statProcess(client/C)
	..(C)
	C.add_stat("[queue.len] queued, [helpers.len] reusable, [by_object.len] targets, [queue_high_water] peak")
	C.add_stat("[enqueued] scheduled, [invocations] invoked, [cancelled] cancelled, [invalid] invalid, [helpers_created] helpers created")

/callproc_helper
	parent_type = /datum
	var/queued = FALSE
	var/datum/index_target = null
	var/datum/object = null
	var/function = ""
	var/list/args = null
	var/time = -1
