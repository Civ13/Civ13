// Hold-to-fire on SStimer, headless. A fake client stands in for the real
// one (owner.mob and owner.Click() are looked up by name at runtime), so the
// probe drives /datum/autofire without a connected player. run.py compiles it
// into the production game with normal startup disabled.
/world
	hub = ""
	hub_password = ""
	maxx = 10
	maxy = 10
	maxz = 1
	turf = /turf
/world/Topic(T, addr, master, key)
	return "no"
var/af_errors = 0
/world/Error(exception/e, datum/e_src)
	af_errors++
	text2file("RUNTIME\t[e] on [e.file]:[e.line]\n", "af_log.txt")
var/af_fired = 0
/proc/af_mark()
	af_fired++
/datum/af_fake_client
	var/mob/mob
	var/clicks = 0
	var/sleep_once = 0
	var/datum/autofire/af
/datum/af_fake_client/proc/Click(object, location, control, params)
	clicks++
	if (!usr || usr != mob)
		text2file("FAIL: usr not set to the shooter\n", "af_log.txt")
	if (sleep_once)
		sleep_once = 0
		// While this click sleeps, the button is released and pressed again.
		af.stop()
		af.start(object, location, control, params)
		sleep(5)
/mob/af_probe
	var/af_delay = 2
/mob/af_probe/CanMobAutoclick(object, location, params)
	return af_delay
/proc/af_check(cond, msg)
	text2file("[cond ? "ok" : "FAIL"]: [msg]\n", "af_log.txt")
/world/New()
	makeDatumRefLists()
	spawn(5) af_run()
/proc/af_run()
	var/fps_before = world.fps
	if (!fexists("skip_start.txt"))
		Master.start_timer_loop()
	addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(af_mark)), 3)
	var/cancel = addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(af_mark)), 5, TIMER_STOPPABLE)
	deltimer(cancel)
	sleep(20)
	af_check(af_fired == 1, "one timer fired and the cancelled one did not ([af_fired])")
	af_check(world.fps == fps_before, "tick rate unchanged ([fps_before] -> [world.fps])")
	var/turf/T = locate(5,5,1)
	var/mob/af_probe/M = new(locate(2,2,1))
	var/datum/af_fake_client/C = new
	C.mob = M
	var/datum/autofire/A = new(C)
	C.af = A
	A.start(T, T, "mapwindow.map", "")
	af_check(C.clicks == 1, "first shot fires on mouse down ([C.clicks])")
	sleep(20)
	var/held = C.clicks
	af_check(held >= 8 && held <= 12, "about one shot per burst_delay while held ([held] in 2 s at 0.2 s)")
	A.stop()
	sleep(10)
	af_check(C.clicks == held, "release stops fire ([held] -> [C.clicks])")
	A.start(T, T, "mapwindow.map", "")
	sleep(4)
	M.af_delay = 0
	var/before = C.clicks
	sleep(10)
	af_check(C.clicks <= before + 1 && !A.target, "switching off full auto ends the hold ([before] -> [C.clicks])")
	M.af_delay = 2
	A.start(T, T, "mapwindow.map", "")
	sleep(4)
	M.stat = 2
	before = C.clicks
	sleep(10)
	af_check(C.clicks <= before + 1 && !A.target, "death ends the hold ([before] -> [C.clicks])")
	M.stat = 0
	C.clicks = 0
	C.sleep_once = 1
	A.start(T, T, "mapwindow.map", "")
	sleep(20)
	// Two chains would give about twice as many shots.
	af_check(C.clicks >= 12 && C.clicks <= 16, "a release and press during a sleeping click keeps one chain ([C.clicks] in 2.5 s; two chains give ~26)")
	A.stop()
	qdel(A)
	sleep(5)
	af_check(af_errors == 0, "no runtime errors ([af_errors])")
	text2file("DONE\n", "af_log.txt")
	del(world)
