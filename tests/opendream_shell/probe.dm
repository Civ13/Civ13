// External effects are counted adapters; no script, audio or live server runs.
var/shell_calls = 0
var/file_checks = 0
var/control_calls = 0
var/last_action
var/last_map
var/sound_tts_num = 0
var/failures = 0

/world
	maxx = 1
	maxy = 1
	maxz = 1
/mob
	var/fixture_client = TRUE
/mob/living
	var/voice_pitch = 100
/mob/living/human
	var/original_job = TRUE
/process/python
	var/last = 0
/process/python/proc/getScriptDir()
	return "scripts"
/proc/ishuman(mob/M)
	return istype(M, /mob/living/human)
/proc/log_debug(message)
	return
/proc/compat_shell(command)
	shell_calls++
	return TRUE
/proc/compat_fexists(path)
	file_checks++
	return FALSE
/proc/opendream_control_request(action, map_id)
	control_calls++
	last_action = action
	last_map = map_id
	return TRUE
/mob/proc/playsound_local(location, path, volume)
	failures++
/proc/check(value, label)
	if (!value)
		failures++
		world.log << "FAIL [label]"

/world/New()
	world.port = 0
	var/mob/listener = new()
	var/mob/living/speaker = new()
	var/process/python/runner = new()
#ifdef OPENDREAM
	for (var/i = 1 to 1000)
		listener.play_tts("hello", speaker)
	check(runner.execute("mapswap.py", list("NOMADS")), "fixed map request succeeds")
	check(control_calls == 1 && last_action == "mapswap" && last_map == "NOMADS", "fixed dispatch preserved")
	check(!runner.execute("other.py", list()), "unsupported script rejected")
#else
	listener.play_tts("hello", speaker)
	listener.play_tts("", speaker)
	check(runner.execute("mapswap.py", list("NOMADS")), "native script adapter succeeds")
	check(!runner.execute("other.py", list()), "native cooldown preserved")
	check(control_calls == 0, "native script does not use OpenDream spool")
#endif
	sleep(2)
#ifdef OPENDREAM
	check(shell_calls == 0, "OpenDream makes no shell calls")
	check(sound_tts_num == 0, "OpenDream creates no speech jobs")
	check(file_checks == 0, "OpenDream makes no generated audio lookup")
#else
	// Speech invokes once, python capability + command twice, cooldown probe once.
	check(shell_calls == 4, "native shell adapter calls preserved")
	check(sound_tts_num == 1 && file_checks == 1, "native speech work preserved")
#endif
	world.log << "DONE shell compatibility"
	if (!failures)
		world.log << "PASS shell compatibility"
	del(world)
	return
