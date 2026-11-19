// Native probe: an interrupted Adjust Zoom releases the scope's adjustment
// lock so a later attempt can start again (#6219).
// Run: python3 tests/ecology_spawning/run_linux.py . tests/scope_zoom/probe.dm
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
/obj/map_metadata/sz_probe/New()
	return

var/sz_failures = 0
var/sz_runtime_error = FALSE
/proc/sz_check(condition, label)
	if (!condition)
		sz_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	sz_runtime_error = TRUE
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
		map = new /obj/map_metadata/sz_probe
		sz_scope_checks()
	catch(var/exception/e)
		sz_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = sz_failures, "runtime_error" = sz_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/sz_scope_checks()
	var/mob/living/human/user = new(locate(5, 5, 1))
	var/obj/item/weapon/attachment/scope/adjustable/sniper_scope/S = new(user)
	user.put_in_active_hand(S)
	sz_check(S.loc == user && user.get_active_hand() == S, "the user holds an adjustable scope")
	spawn(0)
		S.adjust_scope(user)
	sleep(1)
	sz_check(S.looking, "adjusting locks the scope during the wait")
	user.forceMove(locate(6, 5, 1))
	sleep(15)
	sz_check(!S.looking, "moving during the wait releases the adjustment lock")
	user.forceMove(locate(5, 5, 1))
	spawn(0)
		S.adjust_scope(user)
	sleep(1)
	sz_check(S.looking, "a later attempt starts a new adjustment")
	user.forceMove(locate(6, 5, 1))
	sleep(15)
	sz_check(!S.looking, "the second interrupted attempt also releases the lock")
