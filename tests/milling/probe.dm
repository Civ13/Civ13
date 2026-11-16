// Native probe for industrial milling.
// Run: python3 tests/ecology_spawning/run_linux.py . tests/milling/probe.dm
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
/obj/map_metadata/milling_probe/New()
	return
/mob/living/human/milling_probe/New()
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
		map = new /obj/map_metadata/milling_probe
		map.ordinal_age = 1
		milling_probe_checks()
	catch(var/exception/e)
		eco_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = eco_failures, "runtime_error" = eco_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/milling_probe_crushed(obj/structure/drill/stamp_mill/M, path, amount)
	var/obj/item/stack/S = new path(locate(1, 1, 1))
	S.amount = amount
	return M.fill_hopper(S, amount)

/proc/milling_probe_checks()
	map.ordinal_age = 4
	var/obj/structure/drill/stamp_mill/water/mill/drum/D = new(locate(5, 5, 1))
	eco_check(!D.check_power() && !D.takes_plates, "the drum needs a mover and takes no plates")
	eco_check(milling_probe_crushed(D, /obj/item/stack/ore/crushed_ore/gold, 3) == 3 && !D.hopper_accepts(new /obj/item/stack/material/stone(locate(1, 1, 1))), "the drum hopper takes crushed ore, not stone")
	D.water_store = 60
	eco_check(!D.stamp_one_stone(1) && D.mill_stop_reason == "its quicksilver is spent", "a dry drum stops for quicksilver")
	D.reagents.add_reagent("mercury", 10)
	var/ok = D.stamp_one_stone(1)
	var/obj/item/stack/ore/amalgam/gold/A = locate() in get_turf(D)
	eco_check(ok && A && abs(D.reagents.get_reagent_amount("mercury") - 7.8) < 0.001 && D.water_store == 45, "a lucky load makes amalgam and loses 0.2u ([D.reagents.get_reagent_amount("mercury")])")
	var/obj/structure/mercury_separator/SEP = new(locate(6, 5, 1))
	D.stamp_one_stone(99)
	eco_check(abs(D.reagents.get_reagent_amount("mercury") - 7.77) < 0.001 && SEP, "with a separator the drum loses 0.03u")
	var/obj/structure/drill/stamp_mill/water/mill/table/T = new(locate(10, 10, 1))
	milling_probe_crushed(T, /obj/item/stack/ore/crushed_ore/silver, 2)
	T.water_store = 60
	T.stamp_one_stone(1)
	var/obj/item/stack/ore/silver/SV = locate() in get_turf(T)
	var/obj/item/stack/ore/tailings/TL = locate() in get_turf(T)
	eco_check(SV && TL && !T.reagents, "the shaking table gives clean silver and tailings without quicksilver")
	T.water_store = 0
	eco_check(!T.stamp_one_stone(1) && T.mill_stop_reason == "it has run out of water", "a dry table stops for water")
	var/obj/structure/drill/stamp_mill/water/mill/trommel/R = new(locate(14, 14, 1))
	eco_check(milling_probe_crushed(R, /obj/item/stack/ore/pay_dirt/rich, 4) == 4, "the trommel takes pay dirt")
	R.water_store = 60
	eco_check(!R.stamp_one_stone() && R.mill_stop_reason == "there is no free sluice box beside it", "a trommel needs a sluice")
	var/obj/structure/placer_washer/sluice/SL = new(locate(15, 14, 1))
	eco_check(R.stamp_one_stone() && R.loaded_stone_amount() == 3 && SL, "with a sluice beside it the trommel screens a load")
	var/obj/structure/drill/stamp_mill/M = new(locate(18, 18, 1))
	eco_check(M.takes_plates && !M.plates, "a stamp mill takes plates")
	M.plates = TRUE
	M.create_reagents(20)
	M.reagents.add_reagent("mercury", 10)
	milling_probe_crushed(M, /obj/item/stack/ore/silver_lode, 2)
	M.stamp_one_stone(1)
	var/obj/item/stack/ore/amalgam/silver/SA = locate() in get_turf(M)
	eco_check(SA && abs(M.reagents.get_reagent_amount("mercury") - 7.95) < 0.001 && M.loaded_stone_amount() == 1, "plates turn stamped silver ore into amalgam")
	M.reagents.clear_reagents()
	M.stamp_one_stone(1)
	var/obj/item/stack/ore/crushed_ore/silver/CS = locate() in get_turf(M)
	eco_check(CS, "without quicksilver the plated mill only crushes")
