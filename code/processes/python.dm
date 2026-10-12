/process/python
	var/last = 0
/process/python/setup()
	name = "python"
	schedule_interval = 2 SECONDS
	start_delay = 1 SECOND
	fires_at_gamestates = list()
	priority = PROCESS_PRIORITY_IRRELEVANT
	processes.python = src

/process/python/fire()
	return

/process/python/proc/execute(var/command, var/list/py_args = list())
	#ifdef OPENDREAM
	if (command == "mapswap.py" && py_args.len == 1)
		return opendream_control_request("mapswap", "[py_args[1]]")
	log_debug("Unsupported OpenDream script control: [command]")
	return FALSE
	#endif
	if (! shell())
		return FALSE
	if (world.realtime - last < 300)
		log_debug("python script \"[command]\" already running!")
		return FALSE

	if(world.realtime > last+300)
		for (var/argument in py_args)
			command = "[command] [argument]"
		log_debug("Executing python3 command '[command]'")
		last = world.realtime
		if (world.system_type == UNIX)
			return shell("sudo python3 [getScriptDir()]/[command]")
		return shell("python3 [getScriptDir()]/windows/[command]")

/process/python/proc/getScriptDir()
	return "scripts"

// OpenDream has no shell(). Only a locally configured supervisor can consume
// these fixed actions. No arbitrary executable or shell command enters the spool.
/proc/opendream_control_request(action, map_id = null)
	if (!(action in list("mapswap", "restart")))
		return FALSE
	var/root = "SQL/opendream-control/"
	if (!fexists("[root]enabled.json") || fexists("[root]game-request.json"))
		log_debug("OpenDream supervisor unavailable or request pending.")
		return FALSE
	var/request = json_encode(list("action" = action, "map" = map_id))
	// The consumer reads only after the final commit marker. Avoid fcopy:
	// OpenDream can retain the previous bytes of a reused temporary resource.
	if (!text2file(request, "[root]game-request.json"))
		return FALSE
	if (!text2file("ready", "[root]game-ready"))
		fdel("[root]game-request.json")
		return FALSE
	return TRUE

