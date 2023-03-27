/process/python
	var/last = 0
/process/python/setup()
	name = "python"
	schedule_interval = 5 SECONDS
	start_delay = 1 SECOND
	fires_at_gamestates = list()
	priority = PROCESS_PRIORITY_IRRELEVANT
	processes.python = src

/process/python/fire()
	return

/process/python/proc/execute(var/command, var/list/args = list())
	if (! shell())
		return FALSE
	if (world.realtime - last < 300)
		log_debug("python script \"[command]\" already running!")
		return FALSE

	if(world.realtime > last+300)
		for (var/argument in args)
			command = "[command] [argument]"
		log_debug("Executing python3 command '[command]'")
		last = world.realtime
		if (world.system_type == UNIX)
			return shell("sudo python3 [getScriptDir()]/[command]")
		return shell("python3 [getScriptDir()]/windows/[command]")

/process/python/proc/getScriptDir()
	return "scripts"
