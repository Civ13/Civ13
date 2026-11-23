// Native probe: a taser dart applies its stun and agony once, scaled by gloves (issue 6977).
// Run: python3 tests/ecology_spawning/run_linux.py . tests/taser_dart/probe.dm
/world
	hub = ""
	hub_password = ""
	maxx = 30
	maxy = 8
	maxz = 1
	turf = /turf/floor/dirt
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/obj/map_metadata/taser_dart_probe/New()
	return
var/td_failures = 0
var/td_runtime_error = FALSE
/proc/td_check(condition, label)
	if (!condition)
		td_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	td_runtime_error = TRUE
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
		map = new /obj/map_metadata/taser_dart_probe
		td_checks()
	catch(var/exception/e)
		td_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = td_failures, "runtime_error" = td_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/td_checks()
	var/mob/living/human/H = new(locate(4, 4, 1))
	var/obj/item/projectile/taser/P = new(locate(5, 4, 1))
	var/before = H.halloss
	P.on_hit(H, 0, "l_hand")
	td_check(H.halloss == before, "the generic hit rider adds no taser agony")
	td_check(!H.stunned, "the generic hit rider adds no taser stun")
	var/obj/item/projectile/bullet/B = new(locate(6, 4, 1))
	B.agony = 7
	B.on_hit(H, 0, "chest")
	td_check(H.halloss >= before + 7, "other projectiles still apply their agony rider")
