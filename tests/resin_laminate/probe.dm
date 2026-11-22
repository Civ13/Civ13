// Phenolic resin and resin laminate (code/modules/1713/resin_laminate.dm): the
// bakelizer's resin setting and the hot press. The procs run; only the
// do_after wait and the probe mob's hands are stood in for.
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
/obj/map_metadata/laminate_probe/New()
	return
/mob/living/human/laminate_probe/New()
	return
/mob/living/human/laminate_probe/put_in_hands(obj/item/W)
	return FALSE
var/laminate_failures = 0
var/laminate_runtime_error = FALSE
var/laminate_wait_ok = TRUE
/proc/laminate_check(condition, label)
	if (!condition)
		laminate_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	laminate_runtime_error = TRUE
	world.log << "runtime error: [e] [e.file]:[e.line]"
/obj/structure/hot_press/press_wait(mob/living/human/H)
	return laminate_wait_ok

/proc/laminate_count(turf/T)
	. = 0
	for (var/obj/item/stack/material/resin_laminate/L in T)
		. += L.amount

/proc/laminate_checks(mob/living/human/laminate_probe/H, turf/T)
	H.a_intent = I_HELP
	// Bakelizer.
	var/obj/structure/bakelizer/K = new(T)
	K.bakelizer_make()
	laminate_check(K.plastic == 1 && !K.stock, "the plastic setting makes plastic sheets")
	K.setting = "phenolic_resin"
	K.bakelizer_make()
	K.bakelizer_make()
	laminate_check(K.plastic == 1 && K.stock && K.stock["phenolic_resin"] == 20, "the phenolic setting makes 10 units per step")
	var/obj/item/weapon/reagent_containers/glass/bucket/B = new(H)
	K.attackby(B, H)
	laminate_check(B.reagents.get_reagent_amount("phenolic_resin") == 20 && !K.stock.len, "an empty bucket draws the resin off")
	K.setting = "no_such_setting"
	K.bakelizer_make()
	laminate_check(K.setting == "plastic" && K.plastic == 2, "an unknown setting falls back to plastic")
	// Nylon.
	K.setting = "nylon_thread"
	K.bakelizer_make()
	laminate_check(K.nylon_thread == 2, "the nylon setting spins two skeins per step")
	laminate_check(K.bakelizer_eject_nylon(null) && K.nylon_thread == 0, "the Remove verb hands out the nylon thread")
	var/n = 0
	for (var/obj/item/stack/nylon_thread/NT in get_turf(K))
		n += NT.amount
	laminate_check(n == 2, "two skeins of nylon thread lie by the bakelizer")
	laminate_check(bakelizer_setting_age("nylon_thread") == 6 && bakelizer_setting_age("phenolic_resin") == 0, "nylon waits for WW2")
	K.setting = "photopolymer"
	K.bakelizer_make()
	laminate_check(K.photopolymer == 2 && K.bakelizer_eject_photopolymer(null) && K.photopolymer == 0 && bakelizer_setting_age("photopolymer") == 9, "the Digital Age photopolymer setting fills two bottles per step")
	var/material/NY = get_material_by_name("nylon")
	laminate_check(NY && NY.stack_type == /obj/item/stack/material/nylon, "nylon is a material")
	// Hot press.
	var/obj/structure/hot_press/P = new(locate(6, 5, 1))
	var/turf/PT = get_turf(P)
	var/obj/item/stack/material/cloth/C = new(T, 10)
	P.attackby(C, H)
	laminate_check(C.amount == 10 && laminate_count(PT) == 0, "no resin, no laminate")
	P.attackby(B, H)
	laminate_check(P.reagents.get_reagent_amount("phenolic_resin") == 20 && B.reagents.total_volume == 0, "resin pours into the press")
	var/obj/item/stack/material/cloth/few = new(locate(8, 8, 1), 3)
	P.attackby(few, H)
	laminate_check(few.amount == 3 && laminate_count(PT) == 0, "three sheets are too few")
	laminate_wait_ok = FALSE
	P.attackby(C, H)
	laminate_wait_ok = TRUE
	laminate_check(C.amount == 10 && P.reagents.get_reagent_amount("phenolic_resin") == 20 && P.icon_state == "hot_press", "an interrupted pressing uses nothing")
	P.attackby(C, H)
	laminate_check(C.amount == 6 && P.reagents.get_reagent_amount("phenolic_resin") == 10 && laminate_count(PT) == 2, "phenolic resin and four cloth press two sheets")
	var/obj/item/stack/material/silk/S = new(T, 4)
	P.attackby(S, H)
	laminate_check(laminate_count(PT) == 5 && P.reagents.get_reagent_amount("phenolic_resin") == 0, "silk presses three sheets, the best grade")
	B.reagents.add_reagent("resin", 10)
	P.attackby(B, H)
	P.attackby(C, H)
	laminate_check(C.amount == 2 && laminate_count(PT) == 6 && P.reagents.get_reagent_amount("resin") == 0, "plain pine resin presses at half yield")
	var/obj/item/stack/material/oilcloth/O = new(T, 4)
	B.reagents.add_reagent("resin", 10)
	P.attackby(B, H)
	P.attackby(O, H)
	laminate_check(O.amount == 4 && laminate_count(PT) == 6, "oilcloth is not pressed")
	var/material/M = get_material_by_name("resin_laminate")
	laminate_check(M && M.stack_type == /obj/item/stack/material/resin_laminate, "resin laminate is a material")

/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		movementMachine = new
		map = new /obj/map_metadata/laminate_probe
		map.ordinal_age = 1
		populate_material_list()
		var/turf/T = locate(5, 5, 1)
		var/mob/living/human/laminate_probe/H = new(locate(5, 6, 1))
		laminate_check(!world.port, "fixture has no listening port")
		laminate_checks(H, T)
	catch(var/exception/e)
		laminate_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = laminate_failures, "runtime_error" = laminate_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)
