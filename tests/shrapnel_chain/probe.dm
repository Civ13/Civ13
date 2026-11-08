// Shrapnel chain and lag capture, headless. run.py compiles this into the
// production game with normal startup disabled.
/world
	hub = ""
	hub_password = ""
	maxx = 20
	maxy = 20
	maxz = 1
	turf = /turf
/world/Topic(T, addr, master, key)
	return "no"
/world/Error(exception/e, datum/e_src)
	text2file("RUNTIME\t[e] on [e.file]:[e.line]\n", "sc_log.txt")

var/sc_explosions = 0
var/sc_fragment_rings = 0
var/sc_fragments = 0

// Explosions are only counted: nothing else of the scheduler runs here.
/process/callproc/sc_stub/queue(object, function, list/arguments, delay)
	sc_explosions++

/obj/item/weapon/grenade/frag/fragmentate(turf/T, fragment_number, spreading_range, list/fragtypes)
	sc_fragment_rings++

/obj/item/projectile/bullet/pellet/fragment/New()
	sc_fragments++
	..()

/proc/sc_log(line)
	text2file("[line]\n", "sc_log.txt")

/proc/sc_check(ok, label)
	sc_log("[ok ? "ok" : "FAIL"]: [label]")

/world/New()
	makeDatumRefLists()
	spawn(5) sc_run()

/proc/sc_run()
	processes.callproc = new /process/callproc/sc_stub
	var/turf/center = locate(10, 10, 1)

	// A frag grenade struck by several fragments goes off once.
	var/obj/item/weapon/grenade/frag/G = new(center)
	G.det_time = 1
	var/obj/item/projectile/P = new /obj/item/projectile(locate(1, 1, 1))
	for (var/i = 1 to 5)
		G.bullet_act(P)
	sleep(10)
	sc_check(sc_fragment_rings == 1, "frag grenade hit 5 times threw [sc_fragment_rings] fragment ring(s), expected 1")
	sc_check(sc_explosions == 1, "frag grenade hit 5 times exploded [sc_explosions] time(s), expected 1")

	// An AP mine set off twice (a mine clearer, then again) throws one ring.
	sc_explosions = 0
	sc_fragments = 0
	var/obj/item/mine/ap/armed/M = new(locate(10, 5, 1))
	M.nextCanExplode = -1
	var/obj/item/projectile/stray = new /obj/item/projectile(locate(1, 2, 1))
	M.trigger(stray)
	sc_check(sc_fragments == 0 && sc_explosions == 0, "a projectile does not set off an AP mine ([sc_fragments] fragments)")
	var/obj/item/clearer = new /obj/item(locate(1, 3, 1))
	M.trigger(clearer)
	var/first = sc_fragments
	M.trigger(clearer)
	sc_check(first > 0, "a mine clearer sets off the AP mine ([first] fragments)")
	sc_check(sc_fragments == first, "a second trigger adds no fragments ([sc_fragments - first] extra)")
	sc_check(sc_explosions == 1, "the AP mine exploded [sc_explosions] time(s), expected 1")

	// Sustained dilation saves a proc profile.
	var/process/time_track/T = new
	if (!hascall(T, "check_lag_capture"))
		sc_check(FALSE, "time tracking has no lag capture")
	else
		fdel("data/profile/")
		T.dilation = 80
		for (var/i = 1 to 3)
			call(T, "check_lag_capture")()
		sleep(120)
		T.dilation = 0
		call(T, "check_lag_capture")()
		var/list/files = flist("data/profile/")
		sc_check(files.len == 1, "a lag spike saved [files.len] profile(s), expected 1")
		T.dilation = 80
		for (var/i = 1 to 3)
			call(T, "check_lag_capture")()
		sleep(120)
		T.dilation = 0
		call(T, "check_lag_capture")()
		files = flist("data/profile/")
		sc_check(files.len == 1, "a second spike inside the cooldown saved no new profile ([files.len] total)")
	sc_log("DONE")
	del(world)
