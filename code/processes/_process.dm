// Process

/process
	parent_type = /datum
	/**
	 * State vars
	 */
	// Main controller ref
	var/tmp/processScheduler/main

	// TRUE if process is not running or queued
	var/tmp/idle = TRUE

	// TRUE if process is queued
	var/tmp/queued = FALSE

	// TRUE if process is running
	var/tmp/running = FALSE

	// TRUE if process is blocked up
	var/tmp/hung = FALSE

	// TRUE if process was killed
	var/tmp/killed = FALSE

	// Status text var
	var/tmp/status

	// Previous status text var
	var/tmp/previousStatus

	// TRUE if process is disabled
	var/tmp/disabled = FALSE

	/**
	 * Config vars
	 */
	// Process name
	var/name

	// Process schedule interval
	// This controls how often the process would run under ideal conditions.
	// If the process scheduler sees that the process has finished, it will wait until
	// this amount of time has elapsed from the start of the previous run to start the
	// process running again.
	var/tmp/schedule_interval = PROCESS_DEFAULT_SCHEDULE_INTERVAL // run every 50 ticks

	// hang_warning_time - this is the time (in 1/10 seconds) after which the server will begin to show "maybe hung" in the context window
	var/tmp/hang_warning_time = PROCESS_DEFAULT_HANG_WARNING_TIME

	// hang_alert_time - After this much time(in 1/10 seconds), the server will send an admin debug message saying the process may be hung
	var/tmp/hang_alert_time = PROCESS_DEFAULT_HANG_ALERT_TIME

	// hang_restart_time - After this much time(in 1/10 seconds), the server will automatically kill and restart the process.
	var/tmp/hang_restart_time = PROCESS_DEFAULT_HANG_RESTART_TIME

	/**
	 * recordkeeping vars
	 */

	// Records the time (1/10s timeoftick) at which the process last began running
	var/tmp/run_start = 0

	// Records the number of times this process has been killed and restarted
	var/tmp/times_killed = 0

	// Tick count
	var/tmp/ticks = 0

	var/tmp/last_task = ""

	// last object in a loop we iterated through
	var/tmp/current = null

	// Counts the number of times an exception has occurred; gets reset after 10
	var/tmp/list/exceptions = list()

	// Number of deciseconds to delay before starting the process
	var/start_delay = 0

	// are we paused (admin-initiated only)
	var/paused = FALSE

	// are our non-vital processes paused (admin-initiated only)
	// currently only implemented for the obj process
	var/paused_nonvital = 0

	// when can we call process()
	var/list/fires_at_gamestates = list(GAME_STATE_PREGAME, GAME_STATE_SETTING_UP, GAME_STATE_PLAYING, GAME_STATE_FINISHED)

	// lebenProcessScheduler stuff

	// at what tick usage did we start our more recent run
	var/run_time_tick_usage = -1
	// how long are we allowed to run? set in the scheduler whenever this is -1, not New(), since it relies on other processes
	var/run_time_tick_usage_allowance = -1
	// the higher priority, the more CPU we're expected to use
	var/priority = PROCESS_PRIORITY_MEDIUM
	// recorded list of objects we need to go through - never set for processes with priority IRRELEVANT
	var/list/current_list = null
	// move up our priority if we fail to run too many times
	var/run_failures = 0
	// do we ignore tick_usage checks and run no matter what
	var/always_runs = FALSE

/process/New(var/processScheduler/scheduler)
	..()
	main = scheduler
	previousStatus = "idle"
	idle()
	name = "process"
	schedule_interval = 50
	run_start = 0
	ticks = 0
	last_task = 0
	current = null

/process/proc/may_fire()
	return fires_at_gamestates.len == 4 || (ticker && fires_at_gamestates.Find(ticker.current_state))

/process/proc/started()
	// Initialize run_start so we can detect hung processes.
	run_start = TimeOfGame

	running()

	main.processStarted(src)

	onStart()

/process/proc/finished()
	ticks++
	idle()
	main.processFinished(src)
	onFinish()

/process/proc/fire()
	return

/process/proc/setup()
	return

/process/proc/process()
	. = TRUE
	started()
	if (!paused)
		. = fire()
	finished()
	return .

/process/proc/running()
	idle = FALSE
	queued = FALSE
	running = TRUE
	hung = FALSE
	setStatus(PROCESS_STATUS_RUNNING)

/process/proc/idle()
	queued = FALSE
	running = FALSE
	idle = TRUE
	hung = FALSE
	setStatus(PROCESS_STATUS_IDLE)

/process/proc/queued()
	idle = FALSE
	running = FALSE
	queued = TRUE
	hung = FALSE
	setStatus(PROCESS_STATUS_QUEUED)

/process/proc/hung()
	hung = TRUE
	setStatus(PROCESS_STATUS_HUNG)

/process/proc/handleHung()
	var/datum/lastObj = current
	var/lastObjType = "null"
	if (istype(lastObj))
		lastObjType = lastObj.type

	var/msg = "PROCESS SCHEDULER: [name] process hung at tick #[ticks]. Process was unresponsive for [(TimeOfGame - run_start) / 10] seconds and was restarted. Last task: [last_task]. Last Object Type: [lastObjType]"
	log_debug(msg)
	message_admins(msg)

	main.restartProcess(name)

/process/proc/kill()
	if (!killed)
		var/msg = "PROCESS SCHEDULER: [name] process was killed at tick #[ticks]."
		log_debug(msg)
		message_admins(msg)
		//finished()

		// Allow inheritors to clean up if needed
		onKill()

		// set killed var to TRUE
		killed = TRUE

		// This should del
		del(src)

/process/proc/update()
	// Clear delta
	if (previousStatus != status)
		setStatus(status)

	var/elapsedTime = getElapsedTime()

	if (hung)
		handleHung()
		return
	else if (elapsedTime > hang_restart_time)
		hung()
	else if (elapsedTime > hang_alert_time)
		setStatus(PROCESS_STATUS_PROBABLY_HUNG)
	else if (elapsedTime > hang_warning_time)
		setStatus(PROCESS_STATUS_MAYBE_HUNG)

/process/proc/getElapsedTime()
	return TimeOfGame - run_start

/process/proc/tickDetail()
	return

/process/proc/getContext()
	return "<tr><td>[name]</td><td>[main.averageRunTime(src)]</td><td>[main.last_run_time[src]]</td><td>[main.highest_run_time[src]]</td><td>[ticks]</td></tr>\n"

/process/proc/getContextData()
	return list(
	"name" = name,
	"averageRunTime" = main.averageRunTime(src),
	"lastRunTime" = main.last_run_time[src],
	"highestRunTime" = main.highest_run_time[src],
	"ticks" = ticks,
	"schedule" = schedule_interval,
	"status" = getStatusText(),
	"disabled" = disabled
	)

/process/proc/getStatus()
	return status

/process/proc/getStatusText(var/s = FALSE)
	if (!s)
		s = status
	switch(s)
		if (PROCESS_STATUS_IDLE)
			return "idle"
		if (PROCESS_STATUS_QUEUED)
			return "queued"
		if (PROCESS_STATUS_RUNNING)
			return "running"
		if (PROCESS_STATUS_MAYBE_HUNG)
			return "maybe hung"
		if (PROCESS_STATUS_PROBABLY_HUNG)
			return "probably hung"
		if (PROCESS_STATUS_HUNG)
			return "HUNG"
		else
			return "UNKNOWN"

/process/proc/getPreviousStatus()
	return previousStatus

/process/proc/getPreviousStatusText()
	return getStatusText(previousStatus)

/process/proc/setStatus(var/newStatus)
	previousStatus = status
	status = newStatus

/process/proc/setLastTask(var/task, var/object)
	last_task = task
	current = object

/process/proc/_copyStateFrom(var/process/target)

	// make sure we're set to the right datum in the processes list datum
	for (var/variable in processes.vars)
		var/process/P = processes.vars[variable]
		if (P == target)
			processes.vars[variable] = src

	main = target.main
	name = target.name
	schedule_interval = target.schedule_interval
	run_start = 0
	times_killed = target.times_killed
	ticks = target.ticks
	last_task = target.last_task
	current = target.current
	copyStateFrom(target)

/process/proc/copyStateFrom(var/process/target)
	return

/process/proc/onKill()
	return

/process/proc/onStart()
	return

/process/proc/onFinish()
	return

/process/proc/disable()
	disabled = TRUE

/process/proc/enable()
	disabled = FALSE

/process/proc/getAverageRunTime()
	return main.averageRunTime(src)

/process/proc/getLastRunTime()
	return main.getProcessLastRunTime(src)

/process/proc/getHighestRunTime()
	return main.getProcessHighestRunTime(src)

/process/proc/getTicks()
	return ticks

/process/proc/statProcess()
	var/averageRunTime = round(getAverageRunTime(), 0.1)/10
	var/lastRunTime = round(getLastRunTime(), 0.1)/10
	var/highestRunTime = round(getHighestRunTime(), 0.1)/10
	stat("[name]", "T#[getTicks()] | AR [averageRunTime] | LR [lastRunTime] | HR [highestRunTime]")

/process/proc/htmlProcess()
	var/averageRunTime = round(getAverageRunTime(), 0.1)/10
	var/lastRunTime = round(getLastRunTime(), 0.1)/10
	var/highestRunTime = round(getHighestRunTime(), 0.1)/10
	return "T#[getTicks()] | AR [averageRunTime] | LR [lastRunTime] | HR [highestRunTime]<br>"

/process/proc/catchException(var/exception/e, var/thrower)
	if (ispath(thrower) || istext(thrower))
		log_to_dd("PROCESS SCHEDULER: [src].catchException() was given a path or text type, [thrower], which was set to null.")
		log_debug("PROCESS SCHEDULER: [src].catchException() was given a path or text type, [thrower], which was set to null.")
		thrower = null // I think this prevents crashes - Kachnov
		return

	if (istype(e)) // Real runtimes go to the real error handler
		// There are two newlines here, because handling desc sucks
		e.desc = "  Caught by process: [name]\n\n" + e.desc
		if (thrower)
			world.Error(e, e_src = thrower)
		else
			world.Error(e)
		return

	var/etext = "[e]"
	var/eid = "[e]" // Exception ID, for tracking repeated exceptions
	var/ptext = "" // "processing..." text, for what was being processed (if known)
	if (istype(e))
		etext += " in [e.file], line [e.line]"
		eid = "[e.file]:[e.line]"
	if (eid in exceptions)
		if (exceptions[eid]++ >= 10)
			return
	else
		exceptions[eid] = TRUE
	if (istype(thrower, /datum))
		var/datum/D = thrower
		ptext = " processing [D.type]"
		if (istype(thrower, /atom))
			var/atom/A = thrower
			ptext += " ([A]) ([A.x],[A.y],[A.z])"
	log_to_dd("\[[time_stamp()]\] Process [name] caught exception[ptext]: [etext]")
	if (exceptions[eid] >= 10)
		log_to_dd("This exception will now be ignored for ten minutes.")
		spawn(6000)
			exceptions[eid] = 0

/process/proc/catchBadType(var/datum/caught)
	if (isnull(caught) || !istype(caught) || caught.gcDestroyed)
		return // Only bother with types we can identify and that don't belong
	catchException("Type [caught.type] does not belong in process' queue")

// sets current_list to an empty list (or null) by default
/process/proc/reset_current_list()
	if (priority != PROCESS_PRIORITY_IRRELEVANT)
		PROCESS_USE_FASTEST_LIST(list())

/process/proc/may_run(tick_usage_allowance)
	. = 0
	if (main.last_twenty_run_times[src] && main.last_twenty_run_times[src]:len)
		for (var/runtime in main.last_twenty_run_times[src])
			. = max(., runtime)
	. = . <= ((tick_usage_allowance/100) * world.tick_lag)
	if (!.)
		spawn (schedule_interval)
			main.last_twenty_run_times[src]:Cut()