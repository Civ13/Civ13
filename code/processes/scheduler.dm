/************
* Scheduler *
************/

/process/scheduler
	var/list/scheduled_tasks

/process/scheduler/setup()
	name = "scheduler"
	schedule_interval = 3 SECONDS
	scheduled_tasks = list()
	fires_at_gamestates = list(GAME_STATE_PREGAME, GAME_STATE_SETTING_UP, GAME_STATE_PLAYING, GAME_STATE_FINISHED)
	priority = PROCESS_PRIORITY_MEDIUM
	processes.scheduler = src

/process/scheduler/fire()
	for (current in current_list)
		var/datum/scheduled_task/scheduled_task = current
		try
			if (world.time > scheduled_task.trigger_time)
				unschedule(scheduled_task)
				scheduled_task.pre_process()
				scheduled_task.process()
				scheduled_task.post_process()
		catch(var/exception/e)
			catchException(e, current)
			scheduled_tasks -= current

		PROCESS_LIST_CHECK
		PROCESS_TICK_CHECK

/process/scheduler/reset_current_list()
	PROCESS_USE_FASTEST_LIST(scheduled_tasks)

/process/scheduler/statProcess()
	..()
	stat(null, "[scheduled_tasks.len] task\s")

/process/scheduler/htmlProcess()
	return ..() + "[scheduled_tasks.len] tasks"

/process/scheduler/proc/schedule(var/datum/scheduled_task/st)
	scheduled_tasks += st
	destroyed_event.register(st, src, /process/scheduler/proc/unschedule)

/process/scheduler/proc/unschedule(var/datum/scheduled_task/st)
	if (st in scheduled_tasks)
		scheduled_tasks -= st
		destroyed_event.unregister(st, src)

/**********
* Helpers *
**********/
/proc/schedule_task_in(var/in_time, var/procedure, var/list/arguments = list())
	return schedule_task(world.time + in_time, procedure, arguments)

/proc/schedule_task_with_source_in(var/in_time, var/source, var/procedure, var/list/arguments = list())
	return schedule_task_with_source(world.time + in_time, source, procedure, arguments)

/proc/schedule_task(var/trigger_time, var/procedure, var/list/arguments)
	var/datum/scheduled_task/st = new/datum/scheduled_task(trigger_time, procedure, arguments, /proc/destroy_scheduled_task, list())
	processes.scheduler.schedule(st)
	return st

/proc/schedule_task_with_source(var/trigger_time, var/source, var/procedure, var/list/arguments)
	var/datum/scheduled_task/st = new/datum/scheduled_task/source(trigger_time, source, procedure, arguments, /proc/destroy_scheduled_task, list())
	processes.scheduler.schedule(st)
	return st

/proc/schedule_repeating_task(var/trigger_time, var/repeat_interval, var/procedure, var/list/arguments)
	var/datum/scheduled_task/st = new/datum/scheduled_task(trigger_time, procedure, arguments, /proc/repeat_scheduled_task, list(repeat_interval))
	processes.scheduler.schedule(st)
	return st

/proc/schedule_repeating_task_with_source(var/trigger_time, var/repeat_interval, var/source, var/procedure, var/list/arguments)
	var/datum/scheduled_task/st = new/datum/scheduled_task/source(trigger_time, source, procedure, arguments, /proc/repeat_scheduled_task, list(repeat_interval))
	processes.scheduler.schedule(st)
	return st

/*************
* Task Datum *
*************/
/datum/scheduled_task
	var/trigger_time
	var/procedure
	var/list/arguments
	var/task_after_process
	var/list/task_after_process_args

/datum/scheduled_task/New(var/_trigger_time, var/_procedure, var/list/_arguments, var/proc/_task_after_process, var/list/_task_after_process_args)
	..()
	trigger_time = _trigger_time
	procedure = _procedure
	arguments = _arguments ? _arguments : list()
	task_after_process = _task_after_process ? _task_after_process : /proc/destroy_scheduled_task
	task_after_process_args = istype(_task_after_process_args) ? _task_after_process_args : list()
	task_after_process_args += src

/datum/scheduled_task/Destroy()
	procedure = null
	arguments.Cut()
	task_after_process = null
	task_after_process_args.Cut()
	return ..()

/datum/scheduled_task/proc/pre_process()
	task_triggered_event.raise_event(src)

/datum/scheduled_task/proc/process()
	if (procedure)
		call(procedure)(arglist(arguments))

/datum/scheduled_task/proc/post_process()
	call(task_after_process)(arglist(task_after_process_args))

// Resets the trigger time, has no effect if the task has already triggered
/datum/scheduled_task/proc/trigger_task_in(var/trigger_in)
	trigger_time = world.time + trigger_in

/datum/scheduled_task/source
	var/datum/source

/datum/scheduled_task/source/New(var/trigger_time, var/datum/_source, var/procedure, var/list/arguments, var/proc/task_after_process, var/list/task_after_process_args)
	source = _source
	destroyed_event.register(source, src, /datum/scheduled_task/source/proc/source_destroyed)
	..(trigger_time, procedure, arguments, task_after_process, task_after_process_args)

/datum/scheduled_task/source/Destroy()
	source = null
	return ..()

/datum/scheduled_task/source/process()
	call(source, procedure)(arglist(arguments))

/datum/scheduled_task/source/proc/source_destroyed()
	qdel(src)

/proc/destroy_scheduled_task(var/datum/scheduled_task/st)
	qdel(st)

/proc/repeat_scheduled_task(var/trigger_delay, var/datum/scheduled_task/st)
	st.trigger_time = world.time + trigger_delay
	processes.scheduler.schedule(st)
