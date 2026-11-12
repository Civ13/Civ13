// Native probe: a Geiger counter keeps one scan loop, resumes after load and lets old pulses expire.
// Run: python3 tests/ecology_spawning/run_linux.py . tests/geiger_counter/probe.dm
/world
	hub = ""
	hub_password = ""
	maxx = 5
	maxy = 5
	maxz = 1
	turf = /turf
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
var/geiger_failures = 0
var/geiger_runtime_error = FALSE
var/geiger_calls = 0
/proc/geiger_check(condition, label)
	if (!condition)
		geiger_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	geiger_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
// Counts live loop passes without touching sound or icons.
/obj/item/weapon/geiger_counter/probe/processing(generation)
	if (generation == scan_generation && scanning)
		geiger_calls++
	return ..()
/obj/item/weapon/geiger_counter/probe/update_icon()
	return
/proc/geiger_count_over(ticks)
	geiger_calls = 0
	sleep(ticks)
	return geiger_calls
/world/New()
	OpenPort("none")
	spawn(1)
		try
			geiger_check(!world.port, "fixture has no listening port")
			var/obj/item/weapon/geiger_counter/probe/G = new(locate(2, 2, 1))
			G.scanning = TRUE
			G.start_scanning()
			sleep(5)
			var/single = geiger_count_over(50)
			geiger_check(single >= 4 && single <= 6, "an ordinary switched-on counter scans once a second ([single] in 5 s)")
			// Quick off/on toggles before the pending callback wakes.
			for (var/i in 1 to 3)
				G.scanning = FALSE
				G.scan_generation++
				G.scanning = TRUE
				G.start_scanning()
			sleep(5)
			var/after_toggles = geiger_count_over(50)
			geiger_check(after_toggles >= 4 && after_toggles <= 6, "quick off/on toggles leave one loop ([after_toggles] in 5 s)")
			G.scanning = FALSE
			G.scan_generation++
			var/off = geiger_count_over(30)
			geiger_check(off == 0, "a switched-off counter stops scanning")
			// Stale pulse expiry.
			G.scanning = TRUE
			G.start_scanning()
			G.rad_act(5)
			geiger_check(G.radiation_count == 500, "a pulse gives a reading")
			sleep(12)
			geiger_check(G.radiation_count == 500, "a recent pulse is still reported")
			sleep(30)
			geiger_check(G.radiation_count == 0, "an old pulse expires after leaving the source")
			for (var/i in 1 to 4)
				G.rad_act(5)
				sleep(10)
			geiger_check(G.radiation_count == 500, "continued exposure keeps the reading")
			G.scanning = FALSE
			G.scan_generation++
			// Restore: saved on state, runtime fields excluded, then after_load().
			var/obj/item/weapon/geiger_counter/probe/L = new(locate(3, 3, 1))
			L.scanning = TRUE
			L.after_load()
			sleep(5)
			var/restored = geiger_count_over(50)
			geiger_check(restored >= 4 && restored <= 6, "a counter saved while on resumes one scan loop ([restored] in 5 s)")
			L.after_load()
			sleep(5)
			var/reloaded = geiger_count_over(50)
			geiger_check(reloaded >= 4 && reloaded <= 6, "a repeated load callback still leaves one loop ([reloaded] in 5 s)")
			L.scanning = FALSE
			L.scan_generation++
			var/obj/item/weapon/geiger_counter/probe/O = new(locate(4, 4, 1))
			O.after_load()
			var/idle = geiger_count_over(20)
			geiger_check(idle == 0 && !O.scan_generation, "a counter saved while off starts nothing")
			var/list/saved = L.get_saved_vars()
			geiger_check(!("scan_generation" in saved) && !("last_pulse_time" in saved), "loop state is not saved")
		catch(var/exception/e)
			geiger_check(FALSE, "exception [e] [e.file]:[e.line]")
		text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = geiger_failures, "runtime_error" = geiger_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
		del(world)
