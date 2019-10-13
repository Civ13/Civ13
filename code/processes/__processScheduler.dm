// Singleton instance of game_controller_new, setup in world.New()
var/global/processScheduler/processScheduler

/processScheduler
	parent_type = /datum
	// Processes known by the scheduler
	var/tmp/process/list/processes = list()

	// Processes known by the scheduler, ordered by priority
	var/tmp/process/list/priority_ordered_processes = list()

	// Processes that are currently running
	var/tmp/process/list/running = list()

	// Processes that are idle
	var/tmp/process/list/idle = list()

	// Processes that are queued to run
	var/tmp/process/list/queued = list()

	// Process name -> process object map
	var/tmp/process/list/nameToProcessMap = list()

	var/tmp/process/list/priorityToProcessMap = list()

	// Process last queued times (world time)
	var/tmp/process/list/last_queued = list()

	// Process last start times (real time)
	var/tmp/process/list/last_start = list()

	// Process last run durations
	var/tmp/process/list/last_run_time = list()

	// Per process list of the last 20 durations
	var/tmp/process/list/last_twenty_run_times = list()

	// Process highest run time
	var/tmp/process/list/highest_run_time = list()

	// How long to sleep between runs (set to tick_lag in New)
	var/tmp/scheduler_sleep_interval = 0

	// Controls whether the scheduler is running or not
	var/tmp/isRunning = FALSE

	// Setup for these processes will be deferred until all the other processes are set up.
	var/tmp/list/deferredSetupList = list()

	// When did we last process()
	var/last_process = -1

	// Because get_priority_ordered_processes() is expensive, don't do it every tick: Every second is 33 times less often (@ 33 fps), but still works
	var/next_get_priority_ordered_processes = -1
	var/list/last_priority_ordered_processes = null

/processScheduler/New()
	..()
	// When the process scheduler is first new'd, tick_lag may be wrong, so these
	//  get re-initialized when the process scheduler is started.
	// (These are kept here for any processes that decide to process before round start)
	scheduler_sleep_interval = world.tick_lag

/**
 * deferSetupFor
 * @param path processPath
 * If a process needs to be initialized after everything else, add it to
 * the deferred setup list. On goonstation, only the ticker needs to have
 * this treatment.
 */

/processScheduler/proc/deferSetupfor (var/processPath)
	if (!(processPath in deferredSetupList))
		deferredSetupList += processPath

/processScheduler/proc/setup()
	// There can be only one
	if (processScheduler && processScheduler != src)
		del(src)
		return FALSE

	var/process
	// Add all the processes we can find, except for the ticker
	for (process in subtypesof(/process))
		if (!(process in deferredSetupList))
			addProcess(new process(src))

	for (process in deferredSetupList)
		addProcess(new process(src))

	return TRUE

/processScheduler/proc/start()
	isRunning = TRUE
	// tick_lag will have been set by now, so re-initialize these
	scheduler_sleep_interval = world.tick_lag
	updateStartDelays()

	spawn(0)
		// after global lists are created
		for (var/process/P in processes)
			P.reset_current_list()
		// organize processes by priority
		priority_ordered_processes.Cut()
		for (var/priority in PROCESS_PRIORITY_VERY_HIGH to PROCESS_PRIORITY_IRRELEVANT)
			for (var/process/P in processes)
				if (P.priority == priority)
					priority_ordered_processes += P
		process()

/processScheduler/proc/process()

	while (isRunning)
		checkRunningProcesses()
		queueProcesses()
		runQueuedProcesses()
		last_process = world.time
		sleep(scheduler_sleep_interval)

/processScheduler/proc/stop()
	isRunning = FALSE

/processScheduler/proc/checkRunningProcesses()
	for (var/process/p in running)
		p.update()

		if (!p) // Process was killed
			continue

		var/status = p.getStatus()
		var/previousStatus = p.getPreviousStatus()

		// Check status changes
		if (status != previousStatus)
			//Status changed.
			switch(status)
				if (PROCESS_STATUS_PROBABLY_HUNG)
					message_admins("Process '[p.name]' may be hung.")
				if (PROCESS_STATUS_HUNG)
					message_admins("Process '[p.name]' is hung and will be restarted.")

/processScheduler/proc/queueProcesses()
	for (var/process/p in get_priority_ordered_processes())
		// Don't double-queue, don't queue running processes
		if (p.disabled || p.running || p.queued || !p.idle)
			continue

		if (ticker && !p.fires_at_gamestates.Find(ticker.current_state))
			continue

		// If the process should be running by now, go ahead and queue it
		if (world.time >= (last_queued[p] + p.schedule_interval))
			setQueuedProcessState(p)


/processScheduler/proc/runQueuedProcesses()
	#define MINIMUM_TICK_USAGE 10
	#define MAXIMUM_TICK_USAGE 90
	var/max_tick_usage = min(max(MINIMUM_TICK_USAGE, 100 - world.tick_usage), MAXIMUM_TICK_USAGE)
	var/initial_tick_usage = world.tick_usage

	var/list/tmpQueued = queued.Copy()
	var/list/processed = list()

	main:
		while (tmpQueued.len && (world.tick_usage-initial_tick_usage) < max_tick_usage)
			for (var/process/p in tmpQueued)
				var/used_tick_usage = world.tick_usage-initial_tick_usage
				var/available_tick_usage = max_tick_usage - used_tick_usage
				if (p.always_runs || p.priority != PROCESS_PRIORITY_IRRELEVANT || p == tmpQueued[1] || p.may_run(available_tick_usage))
					p.run_time_tick_usage = world.tick_usage
					if (p.run_time_tick_usage_allowance == -1)
						p.run_time_tick_usage_allowance = calculate_run_time_allowance(p.priority)
					// we finished our current run, reset our current_list to a fresh one
					relayProcess(p, tmpQueued)
					p.run_failures = 0
					processed += p
				else
					if (p) // p might have been killed between now and when the loop started, causing a runtime
						p.reset_current_list()
						tmpQueued -= p
				if (used_tick_usage >= max_tick_usage)
					break main

	for (var/process/p in queued-processed)
		++p.run_failures
	#undef MINIMUM_TICK_USAGE
	#undef MAXIMUM_TICK_USAGE


/processScheduler/proc/relayProcess(var/process/p, var/list/queue)
	set waitfor = FALSE
	if (p.process() != PROCESS_TICK_CHECK_RETURNED_EARLY)
		if (p)
			p.reset_current_list()
			queue -= p

/processScheduler/proc/addProcess(var/process/process)

	processes.Add(process)
	process.idle()
	idle.Add(process)

	// init recordkeeping vars
	last_start.Add(process)
	last_start[process] = 0
	last_run_time.Add(process)
	last_run_time[process] = 0
	last_twenty_run_times.Add(process)
	last_twenty_run_times[process] = list()
	highest_run_time.Add(process)
	highest_run_time[process] = 0

	// init starts and stops record starts
	recordStart(process, 0)
	recordEnd(process, 0)

	// Set up process
	process.setup()

	// Save process in the name -> process map
	nameToProcessMap[process.name] = process

	// Save process in the priority -> process map
	var/key = num2text(process.priority)
	if (!priorityToProcessMap[key])
		priorityToProcessMap[key] = list()
	priorityToProcessMap[key] += process

/processScheduler/proc/replaceProcess(var/process/oldProcess, var/process/newProcess)
	processes.Remove(oldProcess)
	processes.Add(newProcess)

	newProcess.idle()
	idle.Remove(oldProcess)
	running.Remove(oldProcess)
	queued.Remove(oldProcess)
	idle.Add(newProcess)

	last_start.Remove(oldProcess)
	last_start.Add(newProcess)
	last_start[newProcess] = 0

	last_run_time.Add(newProcess)
	last_run_time[newProcess] = last_run_time[oldProcess]
	last_run_time.Remove(oldProcess)

	last_twenty_run_times.Add(newProcess)
	last_twenty_run_times[newProcess] = last_twenty_run_times[oldProcess]
	last_twenty_run_times.Remove(oldProcess)

	highest_run_time.Add(newProcess)
	highest_run_time[newProcess] = highest_run_time[oldProcess]
	highest_run_time.Remove(oldProcess)

	recordStart(newProcess, 0)
	recordEnd(newProcess, 0)

	nameToProcessMap[newProcess.name] = newProcess

	// add processes to the priority_ordered_processes list so they actually process after dying - Kachnov
	for (var/v in 1 to priority_ordered_processes.len)
		if (priority_ordered_processes[v] == oldProcess)
			priority_ordered_processes[v] = newProcess

/processScheduler/proc/updateStartDelays()
	for (var/process/p in processes)
		if (p.start_delay)
			last_queued[p] = world.time - p.start_delay

/processScheduler/proc/processStarted(var/process/process)
	setRunningProcessState(process)
	recordStart(process)

/processScheduler/proc/processFinished(var/process/process)
	setIdleProcessState(process)
	recordEnd(process)

/processScheduler/proc/setIdleProcessState(var/process/process)
	running -= process
	queued -= process
	idle |= process

/processScheduler/proc/setQueuedProcessState(var/process/process)
	running -= process
	idle -= process
	queued |= process

	// The other state transitions are handled internally by the process.
	process.queued()

/processScheduler/proc/setRunningProcessState(var/process/process)
	queued -= process
	idle -= process
	running |= process

/processScheduler/proc/recordStart(var/process/process, var/time = null)
	if (isnull(time))
		time = TimeOfGame
		last_queued[process] = world.time
		last_start[process] = time
	else
		last_queued[process] = (time == 0 ? 0 : world.time)
		last_start[process] = time

/processScheduler/proc/recordEnd(var/process/process, var/time = null)
	if (isnull(time))
		time = TimeOfGame

	var/lastRunTime = time - last_start[process]

	if (lastRunTime < 0)
		lastRunTime = 0

	recordRunTime(process, lastRunTime)

/**
 * recordRunTime
 * Records a run time for a process
 */
/processScheduler/proc/recordRunTime(var/process/process, time)
	last_run_time[process] = time
	if (time > highest_run_time[process])
		highest_run_time[process] = time

	var/list/lastTwenty = last_twenty_run_times[process]
	if (lastTwenty.len == 20)
		lastTwenty.Cut(1, 2)

	lastTwenty.len++
	lastTwenty[lastTwenty.len] = time

/**
 * averageRunTime
 * returns the average run time (over the last 20) of the process
 */
/processScheduler/proc/averageRunTime(var/process/process)
	var/lastTwenty = last_twenty_run_times[process]

	var/t = 0
	var/c = 0
	for (var/time in lastTwenty)
		t += time
		c++

	if (c > 0)
		return t / c

	return c

/processScheduler/proc/getProcessLastRunTime(var/process/process)
	return last_run_time[process]

/processScheduler/proc/getProcessHighestRunTime(var/process/process)
	return highest_run_time[process]

/processScheduler/proc/getStatusData()
	var/list/data = list()

	for (var/process/p in processes)
		data.len++
		data[data.len] = p.getContextData()

	return data

/processScheduler/proc/hasProcess(var/processName as text)
	if (nameToProcessMap[processName])
		return TRUE

/processScheduler/proc/killProcess(var/processName as text)
	restartProcess(processName)

/processScheduler/proc/restartProcess(var/processName as text)
	if (hasProcess(processName))
		var/process/oldInstance = nameToProcessMap[processName]
		var/process/newInstance = new oldInstance.type(src)
		newInstance._copyStateFrom(oldInstance)
		replaceProcess(oldInstance, newInstance)
		oldInstance.kill()

/processScheduler/proc/enableProcess(var/processName as text)
	if (hasProcess(processName))
		var/process/process = nameToProcessMap[processName]
		process.enable()

/processScheduler/proc/disableProcess(var/processName as text)
	if (hasProcess(processName))
		var/process/process = nameToProcessMap[processName]
		process.disable()

/processScheduler/proc/statProcesses()
	if (!isRunning)
		stat("Processes", "Scheduler not running")
		return
	stat("Processes", "[processes.len] (R [running.len] / Q [queued.len] / I [idle.len])")
	for (var/process/p in processes)
		p.statProcess()

/processScheduler/proc/htmlProcesses()
	. = "<html><body>"
	if (!isRunning)
		. += "<p><big>Processes: Scheduler not running</big></p>"
		return
	. += "<p><big>Processes: [processes.len] (R [running.len] / Q [queued.len] / I [idle.len])</big></p>"
	for (var/process/p in processes)
		. += "<p><b>[p.name]</b>: [p.htmlProcess()]</p>"
	. += "</body></html>"

/processScheduler/proc/getProcess(var/process_name)
	return nameToProcessMap[process_name]

/processScheduler/proc/calculate_run_time_allowance(var/priority)
	. = 100
	switch (priority)
		if (PROCESS_PRIORITY_VERY_LOW)
			. *= 0.05
		if (PROCESS_PRIORITY_LOW)
			. *= 0.10
		if (PROCESS_PRIORITY_MEDIUM)
			. *= 0.15
		if (PROCESS_PRIORITY_HIGH)
			. *= 0.25
		if (PROCESS_PRIORITY_VERY_HIGH)
			. *= 0.35
		if (PROCESS_PRIORITY_IRRELEVANT)
			. *= 0.10
	. /= priorityToProcessMap[num2text(priority)]:len

/* returns a list of which processes need to run the most.
 * whenever a process fails to run on time, its priority gets bumped up by one.
 * it still won't run, however, unless there is enough of the tick left. Super expensive processes are screwed - Kachnov */
/processScheduler/proc/get_priority_ordered_processes()

	if (last_priority_ordered_processes && world.time < next_get_priority_ordered_processes)
		return last_priority_ordered_processes

	for (var/p in priority_ordered_processes)
		if (!p) // this shouldn't happen anymore, but just in case some chucklefuck admin deletes the process, it's staying here - Kachnov
			priority_ordered_processes -= p

	. = priority_ordered_processes.Copy()

	for (var/v in 1 to priority_ordered_processes.len)
		var/process/p = priority_ordered_processes[v]
		var/p_initial_priority = p.priority
		p.priority = max(p.priority - p.run_failures, PROCESS_PRIORITY_VERY_HIGH)
		var/vv = v
		while (vv > 1)
			var/process/pp = priority_ordered_processes[vv]
			if (p.priority > pp.priority)
				break
			--vv
		var/_tmp = .[vv]
		.[vv] = p
		.[v] = _tmp
		p.priority = p_initial_priority

	next_get_priority_ordered_processes = world.time + 20
	last_priority_ordered_processes = .