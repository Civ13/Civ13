// External effects are counted adapters; no script, audio or live server runs.
var/shell_calls = 0
var/control_calls = 0
var/last_action
var/last_map
var/failures = 0

/world
	maxx = 1
	maxy = 1
	maxz = 1
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/process/python
	var/last = 0
/process/python/proc/getScriptDir()
	return "scripts"
/process/python/proc/unix_runner()
	return "sudo python3"
/proc/log_debug(message)
	return
/proc/compat_shell(command)
	shell_calls++
	return TRUE
/proc/opendream_control_request(action, map_id)
	control_calls++
	last_action = action
	last_map = map_id
	return TRUE
/proc/check(value, label)
	if (!value)
		failures++
		world.log << "FAIL [label]"

/world/New()
	world.OpenPort("none")
	check(!world.port, "fixture listening port closed")
	var/process/python/runner = new()
#ifdef OPENDREAM
	check(runner.execute("mapswap.py", list("NOMADS")), "fixed map request succeeds")
	check(control_calls == 1 && last_action == "mapswap" && last_map == "NOMADS", "fixed dispatch preserved")
	check(!runner.execute("other.py", list()), "unsupported script rejected")
#else
	check(runner.execute("mapswap.py", list("NOMADS")), "native script adapter succeeds")
	check(!runner.execute("other.py", list()), "native cooldown preserved")
	check(control_calls == 0, "native script does not use OpenDream spool")
#endif
	sleep(2)
#ifdef OPENDREAM
	check(shell_calls == 0, "OpenDream makes no shell calls")
#else
	check(shell_calls == 3, "native shell adapter calls preserved")
#endif
	world.log << "DONE shell compatibility"
	if (!failures)
		world.log << "PASS shell compatibility"
	del(world)
	return
