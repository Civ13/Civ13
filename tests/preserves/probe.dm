// Native preserves probe, included by tests/ecology_spawning/run_linux.py, never
// by the game DME. It drives code/modules/1713/preserves.dm.
/world
	hub = ""
	hub_password = ""
	maxx = 30
	maxy = 30
	maxz = 1
	turf = /turf
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/obj/map_metadata/preserve_probe/New()
	map = src
/mob/living/human/preserve_probe/New()
	icon_update = FALSE // no species: skip body overlays when held items change
	return
var/preserve_failures = 0
var/preserve_runtime_error = FALSE
/proc/preserve_check(condition, label)
	if (!condition)
		preserve_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	preserve_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		movementMachine = new
		new /obj/map_metadata/preserve_probe
		initialize_chemical_reactions()
		season = "SUMMER"
		for (var/turf/T in block(locate(1, 1, 1), locate(30, 30, 1)))
			T.ChangeTurf(/turf/floor/grass, FALSE, FALSE)
		preserve_kiln_checks()
		preserve_vinegar_checks()
		preserve_pickle_checks()
		preserve_jam_checks()
	catch(var/exception/e)
		preserve_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = preserve_failures, "runtime_error" = preserve_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/preserve_kiln_checks()
	var/obj/item/weapon/clay/crock/U = new
	preserve_check(U.result == /obj/item/weapon/reagent_containers/glass/crock, "unfired crock fires into a crock")
	qdel(U)

/proc/preserve_vinegar_checks()
	var/obj/item/weapon/reagent_containers/glass/crock/C = new(locate(3, 3, 1))
	C.reagents.add_reagent("wine", 10)
	preserve_check(C.icon_state == "crock" && C.overlays.len == 1, "open crock shows its fill")
	preserve_check(!C.crock_work() && C.reagents.get_reagent_amount("wine") == 10, "an open crock does nothing")
	C.flags &= ~OPENCONTAINER
	C.update_icon()
	preserve_check(C.icon_state == "crock_closed" && C.crock_has_work(), "closed crock with wine has work")
	preserve_check(C.crock_work() && C.reagents.get_reagent_amount("vinegar") == 6 && C.reagents.get_reagent_amount("wine") == 4, "one spell sours six wine")
	C.crock_work()
	preserve_check(C.reagents.get_reagent_amount("vinegar") == 10 && !C.reagents.get_reagent_amount("wine"), "all the wine turns to vinegar")
	preserve_check(!C.crock_has_work(), "nothing left to do")
	C.reagents.add_reagent("water", 10)
	preserve_check(!C.crock_has_work(), "water does not sour")
	preserve_check(C.persistence_runtime_var("crock_working") && !C.persistence_runtime_var("pickle_progress"), "work timer is runtime, pickle progress is saved")
	qdel(C)

/proc/preserve_pickle_checks()
	var/turf/stand = locate(10, 10, 1)
	var/mob/living/human/preserve_probe/H = new(stand)
	var/obj/item/weapon/reagent_containers/glass/crock/C = new(locate(11, 10, 1))
	var/obj/item/weapon/reagent_containers/food/snacks/grown/tomato/T1 = new(stand)
	var/obj/item/weapon/reagent_containers/food/snacks/grown/cabbage/T2 = new(stand)
	preserve_check(C.pack_food(T1, H) && C.pack_food(T2, H) && C.crock_food().len == 2, "two vegetables packed")
	var/obj/item/weapon/reagent_containers/food/snacks/grown/tomato/R = new(stand)
	R.rotten = TRUE
	preserve_check(!C.pack_food(R, H), "rotten food is refused")
	qdel(R)
	C.flags &= ~OPENCONTAINER
	var/obj/item/weapon/reagent_containers/food/snacks/grown/tomato/T3 = new(stand)
	preserve_check(!C.pack_food(T3, H), "a closed crock takes nothing")
	qdel(T3)
	preserve_check(!C.crock_has_work(), "no brine, no work")
	C.reagents.add_reagent("vinegar", 10)
	C.reagents.add_reagent("sodiumchloride", 3)
	preserve_check(!C.crock_has_work(), "too little salt for two")
	C.reagents.add_reagent("sodiumchloride", 1)
	preserve_check(C.crock_has_work(), "enough brine for two")
	C.crock_work()
	C.crock_work()
	preserve_check(C.pickle_progress == 2 && T1.decay > 0, "pickling takes time")
	C.crock_work()
	preserve_check(T1.decay == 0 && T2.decay == 0 && findtext(T1.name, "pickled ") == 1 && !T1.rots, "both are pickled and will keep")
	preserve_check(!C.reagents.get_reagent_amount("vinegar") && !C.reagents.get_reagent_amount("sodiumchloride"), "the brine is used up")
	preserve_check(!C.crock_has_work(), "pickles are not pickled twice")
	preserve_check(!C.take_food(H), "lid must come off to take food")
	C.flags |= OPENCONTAINER
	preserve_check(C.take_food(H) && C.crock_food().len == 1, "a pickle comes out")
	qdel(C)
	for (var/obj/item/I in H)
		qdel(I)
	for (var/obj/item/I in stand)
		qdel(I)
	qdel(H)

/proc/preserve_jam_checks()
	var/turf/stand = locate(20, 20, 1)
	var/mob/living/human/preserve_probe/H = new(stand)
	var/obj/item/weapon/reagent_containers/glass/preserve_jar/J = new(locate(21, 20, 1))
	J.reagents.add_reagent("berryjuice", 10)
	J.reagents.add_reagent("sugar", 5)
	J.reagents.process_reactions() // the chemistry process does this in game
	preserve_check(J.reagents.get_reagent_amount("jam") == 10 && !J.reagents.get_reagent_amount("berryjuice"), "berry juice and sugar set into jam")
	preserve_check(J.icon_state == "jam_jar" && J.overlays.len == 1, "the jar shows its jam")
	var/obj/item/weapon/reagent_containers/glass/beaker/B = new(stand)
	B.reagents.add_reagent("applejuice", 10)
	B.reagents.add_reagent("honey", 5)
	B.reagents.process_reactions()
	preserve_check(B.reagents.get_reagent_amount("jam") == 10, "apple juice and honey set into jam")
	qdel(B)
	var/obj/item/weapon/reagent_containers/food/snacks/breadslice/S = new(stand)
	var/obj/item/weapon/reagent_containers/food/snacks/jelliedtoast/T = J.spread_jam(S, H)
	preserve_check(istype(T) && QDELETED(S) && J.reagents.get_reagent_amount("jam") == 5, "jam spreads on bread")
	J.reagents.remove_reagent("jam", 5)
	preserve_check(J.icon_state == "preserve_jar" && !J.overlays.len, "an empty jar is clear")
	var/obj/item/weapon/reagent_containers/food/snacks/breadslice/S2 = new(stand)
	preserve_check(!J.spread_jam(S2, H) && !QDELETED(S2), "no jam, no toast")
	qdel(J)
	for (var/obj/item/I in stand)
		qdel(I)
	qdel(H)
