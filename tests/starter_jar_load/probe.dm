// Native probe: a reloaded fermentation starter jar resumes its loop once.
// Run: python3 tests/ecology_spawning/run_linux.py . tests/starter_jar_load/probe.dm
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
var/jar_failures = 0
var/jar_runtime_error = FALSE
/proc/jar_check(condition, label)
	if (!condition)
		jar_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	jar_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
// Builds a jar as the loader would: saved fields set, timer excluded, then after_load().
/proc/jar_loaded(fermenting, icon, contents)
	var/obj/item/weapon/starterjar/J = new(locate(2, 2, 1))
	J.fermenting = fermenting
	J.icon_state = icon
	J.fermenting_contents = contents
	J.fermenting_timer = 0
	J.after_load()
	return J
/world/New()
	OpenPort("none")
	spawn(1)
		try
			jar_check(!world.port, "fixture has no listening port")
			var/obj/item/weapon/starterjar/flour = jar_loaded(1, "jarF", 0)
			jar_check(flour.ferment_loop && flour.fermenting_timer > world.time && flour.fermenting == 1, "a saved flour jar resumes fermenting with a fresh wait")
			var/first_timer = flour.fermenting_timer
			flour.resume_fermentation()
			jar_check(flour.fermenting_timer == first_timer && flour.ferment_loop, "resuming again does not restart or duplicate the wait")
			var/obj/item/weapon/starterjar/grain = jar_loaded(1, "jarG", 0)
			jar_check(grain.ferment_loop && grain.fermenting_timer > world.time, "a saved grain jar resumes fermenting")
			grain.fermenting_timer = world.time
			sleep(105)
			jar_check(grain.fermenting == 2 && grain.fermenting_contents == 1 && !grain.ferment_loop && grain.growth_loop, "the resumed fermentation finishes and starts yeast growth")
			var/obj/item/weapon/starterjar/yeast = jar_loaded(2, "jar3", 3)
			jar_check(yeast.growth_loop && yeast.fermenting_contents == 3, "a saved yeast culture resumes growing and keeps its quantity")
			var/obj/item/weapon/starterjar/legacy = jar_loaded(0, "jar2", 0)
			jar_check(legacy.fermenting == 2 && legacy.fermenting_contents == 2 && legacy.growth_loop, "an icon-only legacy jar still restores")
			var/obj/item/weapon/starterjar/empty = jar_loaded(0, "jar0", 0)
			jar_check(!empty.ferment_loop && !empty.growth_loop && empty.fermenting == 0, "an empty jar starts nothing")
			var/list/saved = yeast.get_saved_vars()
			jar_check(!("ferment_loop" in saved) && !("growth_loop" in saved), "loop guards are not saved")
		catch(var/exception/e)
			jar_check(FALSE, "exception [e] [e.file]:[e.line]")
		text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = jar_failures, "runtime_error" = jar_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
		del(world)
