// Native probe for lode ore and ore dressing.
// Run: python3 tests/ecology_spawning/run_linux.py . tests/lode/probe.dm
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
/obj/map_metadata/lode_probe/New()
	return
/mob/living/human/lode_probe/New()
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
		map = new /obj/map_metadata/lode_probe
		map.ordinal_age = 1
		lode_probe_checks()
	catch(var/exception/e)
		eco_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = eco_failures, "runtime_error" = eco_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/lode_probe_checks()
	var/n = 4000
	var/buddle = 0
	var/pan = 0
	var/tails = 0
	for (var/i in 1 to n)
		var/list/b = crushed_ore_wash(/obj/item/stack/ore/gold, 0.35)
		if (b[/obj/item/stack/ore/gold])
			buddle++
		if (b[/obj/item/stack/ore/tailings])
			tails++
		if (crushed_ore_wash(/obj/item/stack/ore/silver, 0.2)[/obj/item/stack/ore/silver])
			pan++
	eco_check(abs(buddle / n - 0.175) < 0.02, "a buddle recovers about a third of the metal ([buddle])")
	eco_check(abs(pan / n - 0.1) < 0.02, "a pan recovers a fifth ([pan])")
	eco_check(tails == n, "every load leaves tailings")
	var/obj/item/stack/ore/gold_quartz/Q = new(locate(2, 2, 1))
	var/obj/item/stack/ore/silver_lode/SV = new(locate(2, 2, 1))
	var/obj/item/stack/material/stone/ST = new(locate(2, 2, 1))
	eco_check(lode_crushed_type(Q) == /obj/item/stack/ore/crushed_ore/gold && lode_crushed_type(SV) == /obj/item/stack/ore/crushed_ore/silver && !lode_crushed_type(ST), "lode ore crushes to its own crushed ore")
	eco_check(is_mill_feed(Q) && is_mill_feed(ST) && !is_mill_feed(new /obj/item/stack/ore/gold(locate(2, 2, 1))), "mills take stone and lode ore only")
	var/obj/structure/drill/stamp_mill/M = new(locate(10, 10, 1))
	Q.amount = 5
	eco_check(M.fill_hopper(Q, 5) == 5 && M.fill_hopper(ST, 1) == 1 && M.loaded_stone_amount() == 6, "the hopper takes lode ore beside stone")
	var/stamped = 0
	while (M.loaded_stone() && M.loaded_stone().type == /obj/item/stack/ore/gold_quartz)
		if (!M.stamp_one_stone())
			break
		stamped++
	var/obj/item/stack/ore/crushed_ore/gold/CG = locate() in get_turf(M)
	eco_check(stamped == 5 && CG && CG.amount == 5, "the stamp mill turns each lump into a load of crushed ore")
	var/obj/structure/drill/stamp_mill/water/W = new(locate(14, 14, 1))
	eco_check(!W.check_power() && W.powerneeded == 0, "a water stamp mill needs a turning mover, not cable")
	var/obj/structure/placer_washer/buddle/B = new(locate(16, 16, 1))
	eco_check(B.accepts_feed(CG) && !B.accepts_feed(new /obj/item/stack/ore/pay_dirt(locate(2, 2, 1))), "the buddle takes crushed ore, not pay dirt")
	var/obj/structure/placer_washer/sluice/SL = new(locate(17, 17, 1))
	eco_check(!SL.accepts_feed(CG), "the sluice does not take crushed ore")
	var/found = 0
	for (var/i in 1 to 2000)
		var/turf/T = locate(5, 5, 1)
		found += T.mining_lode() ? 1 : 0
	eco_check(abs(found / 2000 - 0.0688) < 0.02, "about 7% of mined rock gives lode ore ([found])")
	for (var/obj/item/I in locate(5, 5, 1))
		qdel(I)
