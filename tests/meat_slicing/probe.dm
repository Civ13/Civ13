// Native probe: direct meat slicing conserves toxins and germs (issue 6938).
// Run: python3 tests/ecology_spawning/run_linux.py . tests/meat_slicing/probe.dm
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
/obj/map_metadata/ms_probe/New()
	return

var/ms_failures = 0
var/ms_runtime_error = FALSE
/proc/ms_check(condition, label)
	if (!condition)
		ms_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	ms_runtime_error = TRUE
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
		map = new /obj/map_metadata/ms_probe
		ms_checks()
	catch(var/exception/e)
		ms_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = ms_failures, "runtime_error" = ms_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/ms_total(turf/T, id)
	. = 0
	for (var/obj/item/weapon/reagent_containers/food/snacks/rawcutlet/C in T)
		if (C.reagents)
			. += C.reagents.get_reagent_amount(id)

/proc/ms_count(turf/T)
	. = 0
	for (var/obj/item/weapon/reagent_containers/food/snacks/rawcutlet/C in T)
		.++

/proc/ms_checks()
	var/mob/living/human/cook = new(locate(2, 2, 1))
	var/obj/item/weapon/material/kitchen/utensil/knife/K = new(cook)
	var/turf/T1 = locate(4, 4, 1)
	var/obj/item/weapon/reagent_containers/food/snacks/meat/poisonfrog/F = new(T1)
	F.attackby(K, cook)
	ms_check(ms_count(T1) == 2, "frog meat cuts into two cutlets ([ms_count(T1)])")
	ms_check(abs(ms_total(T1, "cyanide") - 25) < 0.01, "the cutlets share all 25 units of the frog's cyanide ([ms_total(T1, "cyanide")])")
	ms_check(abs(ms_total(T1, "food_poisoning") - 15) < 0.01, "the cutlets share all 15 units of food poisoning ([ms_total(T1, "food_poisoning")])")
	var/turf/T2 = locate(8, 4, 1)
	var/obj/item/weapon/reagent_containers/food/snacks/bearmeat/B = new(T2)
	B.reagents.add_reagent("cholera", 6)
	B.attackby(K, cook)
	ms_check(ms_count(T2) == 3, "bear meat cuts into three cutlets ([ms_count(T2)])")
	ms_check(abs(ms_total(T2, "cholera") - 6) < 0.01, "three bear cutlets carry the slab's 6 units of cholera, not 9 ([ms_total(T2, "cholera")])")
