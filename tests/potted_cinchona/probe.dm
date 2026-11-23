// Native probe: a potted cinchona comes back with only the quinine it had left (issue 6972).
// Run: python3 tests/ecology_spawning/run_linux.py . tests/potted_cinchona/probe.dm
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
/obj/map_metadata/potted_cinchona_probe/New()
	return
var/pc_failures = 0
var/pc_runtime_error = FALSE
/proc/pc_check(condition, label)
	if (!condition)
		pc_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	pc_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		map = new /obj/map_metadata/potted_cinchona_probe
		pc_checks()
	catch(var/exception/e)
		pc_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = pc_failures, "runtime_error" = pc_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/pc_checks()
	var/obj/structure/plant_pot/clay/light/P = new(locate(4, 4, 1))
	var/obj/item/weapon/reagent_containers/food/snacks/grown/cinchona/C = new(locate(5, 4, 1))
	C.reagents.remove_reagent("quinine", 4)
	C.bitecount = 2
	P.record_potted_cinchona(C)
	qdel(C)
	var/obj/item/weapon/reagent_containers/food/snacks/grown/cinchona/R = P.remove_potted_plant()
	pc_check(istype(R), "removing the plant returns a cinchona")
	pc_check(R && R.reagents.get_reagent_amount("quinine") == 6, "the returned cinchona keeps only its remaining quinine")
	pc_check(R && R.bitecount == 2, "the returned cinchona keeps its bite count")
	var/obj/structure/plant_pot/clay/light/W = new(locate(6, 4, 1))
	W.filled_type = /obj/item/weapon/reagent_containers/food/snacks/grown/cinchona
	var/obj/item/weapon/reagent_containers/food/snacks/grown/cinchona/F = W.remove_potted_plant()
	pc_check(F && F.reagents.get_reagent_amount("quinine") == 10, "a pot with no recorded plant still yields a whole cinchona")
