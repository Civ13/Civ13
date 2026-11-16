// Native probe for pay dirt washing.
// Run: python3 tests/ecology_spawning/run_linux.py . tests/placer/probe.dm
/world
	hub = ""
	hub_password = ""
	maxx = 20
	maxy = 20
	maxz = 1
	turf = /turf
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/obj/map_metadata/placer_probe/New()
	return
/mob/living/human/placer_probe/New()
	return
var/eco_failures = 0
var/eco_runtime_error = FALSE
/proc/eco_check(condition, label)
	if (!condition)
		eco_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	eco_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		movementMachine = new
		initialize_chemical_reagents()
		initialize_chemical_reactions()
		map = new /obj/map_metadata/placer_probe
		map.ordinal_age = 1
		placer_probe_checks()
	catch(var/exception/e)
		eco_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = eco_failures, "runtime_error" = eco_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/placer_probe_checks()
	var/n = 4000
	var/list/counts = list("rich" = 0, "tin" = 0, "rich_m" = 0, "rocker" = 0, "tin_tin" = 0, "barren_iron" = 0)
	for (var/i in 1 to n)
		if (pay_dirt_wash("rich", "sluice")[/obj/item/stack/ore/gold])
			counts["rich"]++
		if (pay_dirt_wash("rich", "sluice", TRUE)[/obj/item/stack/ore/gold])
			counts["rich_m"]++
		if (pay_dirt_wash("rich", "rocker")[/obj/item/stack/ore/gold])
			counts["rocker"]++
		var/list/t = pay_dirt_wash("tin", "sluice")
		if (t[/obj/item/stack/ore/gold])
			counts["tin"]++
		if (t[/obj/item/stack/ore/tin])
			counts["tin_tin"]++
		if (pay_dirt_wash("barren", "sluice")[/obj/item/stack/ore/iron_sand])
			counts["barren_iron"]++
	eco_check(abs(counts["rich"] / n - 0.27) < 0.03, "a sluice finds gold in about 27% of rich loads ([counts["rich"]])")
	eco_check(abs(counts["rich_m"] / n - 0.3375) < 0.03, "mercury in the riffles raises it a quarter ([counts["rich_m"]])")
	eco_check(abs(counts["rocker"] / n - 0.324) < 0.03, "a rocker finds more ([counts["rocker"]])")
	eco_check(abs(counts["tin"] / n - 0.09) < 0.02 && abs(counts["tin_tin"] / n - 0.6) < 0.04, "tin ground is mostly tin ([counts["tin"]], [counts["tin_tin"]])")
	eco_check(abs(counts["barren_iron"] / n - 0.5) < 0.04, "barren ground gives iron sand from the Classical age ([counts["barren_iron"]])")
	map.ordinal_age = 0
	var/iron0 = 0
	for (var/i in 1 to 500)
		if (pay_dirt_wash("barren", "sluice")[/obj/item/stack/ore/iron_sand])
			iron0++
	eco_check(iron0 == 0, "no iron sand in the Stone Age")
	var/turf/T = locate(5, 5, 1)
	eco_check(pay_dirt_grade(5, 5) == pay_dirt_grade(16, 16) && pay_dirt_type("rich") == /obj/item/stack/ore/pay_dirt/rich, "a district has one grade")
	var/datum/resource_stock/S = T.pay_dirt_stock()
	eco_check(S.take(1) && S.take(1) && S.take(1) && !S.take(1) && T.pay_dirt_stock() == S, "a bank tile gives three loads, then rests")
	var/obj/structure/placer_washer/sluice/SL = new(locate(8, 8, 1))
	SL.reagents.add_reagent("mercury", 2)
	eco_check(SL.mercury_charged(), "mercury charges the riffles")
	SL.spend_mercury()
	eco_check(abs(SL.reagents.get_reagent_amount("mercury") - 1.95) < 0.001, "each load washes a little away")
	var/obj/structure/placer_washer/rocker/R = new(locate(9, 9, 1))
	eco_check(!R.anchored && R.water_capacity == 40 && !R.mercury_charged(), "the rocker is movable with its own tank")
