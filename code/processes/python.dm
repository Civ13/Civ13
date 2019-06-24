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
	if (shell())
		if(world.realtime > last+300)
			for (var/argument in args)
				command = "[command] [argument]"
			log_debug("Executing python3.6 command '[command]'")
			last = world.realtime
			return shell("sudo python3.6 [getScriptDir()]/[command]")
		else
			log_debug("python mapswap already running!")
			return FALSE
	return FALSE

/process/python/proc/getScriptDir()
	return "scripts"
