// Native probe: motorcycles take every fuel their engine burns (#6733).
// Run: python3 tests/ecology_spawning/run_linux.py . tests/motorcycle_refuel/probe.dm
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
/obj/map_metadata/mr_probe/New()
	return

var/mr_failures = 0
var/mr_runtime_error = FALSE
/proc/mr_check(condition, label)
	if (!condition)
		mr_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	mr_runtime_error = TRUE
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
		map = new /obj/map_metadata/mr_probe
		mr_refuel_checks()
	catch(var/exception/e)
		mr_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = mr_failures, "runtime_error" = mr_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/mr_bike(engine_path)
	var/obj/structure/vehicle/motorcycle/M = new(locate(6, 5, 1))
	M.engine = new engine_path(M)
	M.fueltank = new /obj/item/weapon/reagent_containers/glass/barrel/fueltank/bike25(M)
	M.fueltank.reagents.clear_reagents()
	return M

/proc/mr_can(list/contents)
	var/obj/item/weapon/reagent_containers/glass/beaker/large/B = new(locate(5, 5, 1))
	B.reagents.clear_reagents()
	for (var/R in contents)
		B.reagents.add_reagent(R, contents[R])
	return B

/proc/mr_refuel_checks()
	var/mob/living/human/user = new(locate(5, 5, 1))
	var/obj/structure/vehicle/motorcycle/M = mr_bike(/obj/structure/engine/internal/gasoline)
	var/obj/item/weapon/reagent_containers/glass/beaker/large/B = mr_can(list("enginefuel" = 10, "water" = 10))
	M.attackby(B, user)
	mr_check(M.fueltank.reagents.get_reagent_amount("enginefuel") == 10, "a gasoline engine's tank takes enginefuel")
	mr_check(B.reagents.get_reagent_amount("enginefuel") == 0, "the enginefuel leaves the container")
	mr_check(B.reagents.get_reagent_amount("water") == 10 && !M.fueltank.reagents.has_reagent("water"), "incompatible contents stay in the container")

	M = mr_bike(/obj/structure/engine/internal/gasoline/ethanol)
	B = mr_can(list("pethanol" = 30))
	M.attackby(B, user)
	mr_check(M.fueltank.reagents.get_reagent_amount("pethanol") == 25, "an ethanol-gasoline engine's tank fills with pethanol up to capacity")
	mr_check(B.reagents.get_reagent_amount("pethanol") == 5, "pethanol beyond the tank's room stays in the container")

	M = mr_bike(/obj/structure/engine/internal/gasoline)
	B = mr_can(list("gasoline" = 10, "enginefuel" = 20))
	M.attackby(B, user)
	mr_check(M.fueltank.reagents.total_volume == 25, "a mixed fuel container fills the tank to capacity")
	mr_check(B.reagents.total_volume == 5, "fuel beyond the tank's room stays in the container")

	M = mr_bike(/obj/structure/engine/internal/gasoline)
	B = mr_can(list("diesel" = 10))
	M.attackby(B, user)
	mr_check(M.fueltank.reagents.total_volume == 0 && B.reagents.get_reagent_amount("diesel") == 10, "unsupported fuel is not poured")
