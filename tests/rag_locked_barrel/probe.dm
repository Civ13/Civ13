// Native probe: a rag cannot soak from a locked barrel (issue 6967).
// Run: python3 tests/ecology_spawning/run_linux.py . tests/rag_locked_barrel/probe.dm
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
/obj/map_metadata/rb_probe/New()
	return

var/rb_failures = 0
var/rb_runtime_error = FALSE
/proc/rb_check(condition, label)
	if (!condition)
		rb_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	rb_runtime_error = TRUE
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
		map = new /obj/map_metadata/rb_probe
		rb_checks()
	catch(var/exception/e)
		rb_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = rb_failures, "runtime_error" = rb_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/rb_checks()
	var/mob/living/human/H = new(locate(4, 4, 1))
	var/obj/structure/reagent_dispensers/largebarrel/B = new(locate(5, 4, 1))
	B.reagents.add_reagent("water", 50)
	B.custom_code = 1234
	B.locked = TRUE
	var/obj/item/weapon/reagent_containers/glass/rag/R = new(H)
	H.put_in_active_hand(R)
	R.afterattack(B, H, TRUE)
	rb_check(!R.reagents.total_volume, "a locked barrel does not soak the rag ([R.reagents.total_volume])")
	rb_check(B.reagents.get_reagent_amount("water") == 50, "the locked barrel keeps its water")
	B.locked = FALSE
	R.afterattack(B, H, TRUE)
	rb_check(R.reagents.total_volume > 0, "an unlocked barrel soaks the rag ([R.reagents.total_volume])")
