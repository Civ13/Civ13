// Native probe for the hydraulic monitor and cyanide vat.
// Run: python3 tests/ecology_spawning/run_linux.py . tests/late_mining/probe.dm
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
/obj/map_metadata/late_mining_probe/New()
	return
/mob/living/human/late_mining_probe/New()
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
		map = new /obj/map_metadata/late_mining_probe
		map.ordinal_age = 3
		late_mining_probe_checks()
	catch(var/exception/e)
		eco_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = eco_failures, "runtime_error" = eco_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)


/proc/late_mining_probe_checks()
	map.ordinal_age = 4
	var/mob/living/human/late_mining_probe/H = new(locate(2, 2, 1))

	// The monitor
	var/turf/bank = new /turf/floor/dirt(locate(5, 6, 1))
	var/obj/structure/hydraulic_monitor/M = new(locate(5, 5, 1))
	M.set_dir(NORTH)
	eco_check(findtext(M.monitor_refusal(), "wrench"), "a loose monitor will not run")
	M.anchored = TRUE
	eco_check(findtext(M.monitor_refusal(), "river water"), "a monitor needs fresh water beside it")
	eco_check(bank.can_sift_resources(), "the target bank is dirt")
	var/grade = pay_dirt_grade(bank.x, bank.y)
	var/turf/G = M.strip_bank(bank)
	G = locate(5, 6, 1)
	eco_check(istype(G, /turf/floor/gravel/stripped), "the jet leaves stripped gravel ([G.type])")
	var/obj/item/stack/ore/pay_dirt/P = locate(/obj/item/stack/ore/pay_dirt) in G
	eco_check(P && P.amount == 6 && P.grade == grade, "a stripped bank gives 6 pay dirt of its own grade")
	eco_check(!G.can_sift_resources() && !G.pay_dirt_bank(), "stripped gravel never holds pay dirt again")

	// The vat
	var/obj/structure/placer_washer/cyanide_vat/V = new(locate(10, 10, 1))
	eco_check(!V.can_wash_load(H), "no cyanide leaching before the Early Modern age")
	map.ordinal_age = 5
	eco_check(!V.can_wash_load(H), "an empty vat will not leach")
	V.reagents.add_reagent("cyanide", 3)
	eco_check(!V.can_wash_load(H), "a vat with no zinc will not leach")
	var/obj/item/stack/material/zinc/Z = new(locate(1, 1, 1))
	Z.amount = 2
	V.attackby(Z, H)
	eco_check(V.zinc_loads == 10 && Z.amount == 1 && V.can_wash_load(H), "a zinc sheet charges the box for ten loads")
	var/list/hit = V.cyanide_leach_load(15)
	var/list/miss = V.cyanide_leach_load(16)
	eco_check(hit[/obj/item/stack/ore/gold] == 1 && !miss.len, "15% of tailings loads give a gold ore")
	eco_check(V.zinc_loads == 8 && V.reagents.get_reagent_amount("cyanide") == 1, "each load takes 1u cyanide and a tenth of the zinc")
	eco_check(V.accepts_feed(new /obj/item/stack/ore/tailings(locate(1, 1, 1))) && V.accepts_feed(new /obj/item/stack/ore/tailings/amalgam(locate(1, 1, 1))), "the vat takes both kinds of tailings")
	eco_check(V.drain(H) && V.reagents.get_reagent_amount("cyanide") == 0, "draining empties the vat")
