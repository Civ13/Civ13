// Native probe: bolt-action jam deadline (#6752).
// Run: python3 tests/ecology_spawning/run_linux.py . tests/boltaction_jam/probe.dm
/world
	hub = ""
	hub_password = ""
	maxx = 12
	maxy = 12
	maxz = 1
	turf = /turf
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/obj/map_metadata/bj_probe/New()
	return

var/bj_failures = 0
var/bj_runtime_error = FALSE
/proc/bj_check(condition, label)
	if (!condition)
		bj_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	bj_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		GLOB.name_set_event = new /decl/observ/name_set
		GLOB.stat_set_event = new /decl/observ/stat_set
		makeDatumRefLists()
		movementMachine = new
		map = new /obj/map_metadata/bj_probe
		bj_checks()
	catch(var/exception/e)
		bj_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = bj_failures, "runtime_error" = bj_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)


/proc/bj_checks()
	var/mob/living/human/shooter = new(locate(2, 2, 1))
	var/obj/item/weapon/gun/projectile/boltaction/mosin/R = new(locate(2, 2, 1))
	R.safetyon = FALSE
	R.bolt_open = FALSE
	R.jammed_until = -1
	bj_check(shooter.has_empty_hand(both = FALSE), "the shooter has both hands free")
	bj_check(R.special_check(shooter), "an unjammed rifle may fire")
	R.jammed_until = world.time + 50
	bj_check(!R.special_check(shooter), "a jammed rifle refuses to fire before its deadline")
	R.jammed_until = world.time - 1
	bj_check(R.special_check(shooter), "the rifle fires again once the jam has cleared")
