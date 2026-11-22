// Rubber trees (code/modules/1713/rubber_tapping.dm): tapping a jungle tree for
// latex in a rubber land, none on other continents, curing latex with sulphur
// into rubber, and rubber's uses. The production procs run; only the do_after
// waits and the probe mob's other hand are stood in for.
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
/obj/map_metadata/rubber_probe/New()
	return
/mob/living/human/rubber_probe
	var/obj/item/other_hand = null
/mob/living/human/rubber_probe/New()
	return
/mob/living/human/rubber_probe/get_inactive_hand()
	return other_hand
/mob/living/human/rubber_probe/put_in_hands(obj/item/W)
	return FALSE
var/rubber_failures = 0
var/rubber_runtime_error = FALSE
var/rubber_wait_ok = TRUE
/proc/rubber_check(condition, label)
	if (!condition)
		rubber_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	rubber_runtime_error = TRUE
	world.log << "runtime error: [e] [e.file]:[e.line]"
/obj/structure/wild/jungle/rubber_tap_wait(mob/living/human/H)
	return rubber_wait_ok
/obj/item/stack/ore/sulphur/rubber_cure_wait(mob/living/human/H)
	return rubber_wait_ok

/proc/rubber_sheets(mob/living/human/H)
	. = 0
	for (var/obj/item/stack/material/rubber/R in get_turf(H))
		. += R.amount
	for (var/obj/item/stack/material/rubber/R in H)
		. += R.amount

/proc/rubber_cable_units(turf/T)
	. = 0
	for (var/obj/item/stack/cable_coil/C in T)
		. += C.amount

/proc/rubber_checks(mob/living/human/rubber_probe/H, turf/T)
	var/obj/structure/wild/jungle/J = new(locate(5, 7, 1))
	var/obj/item/weapon/reagent_containers/glass/bucket/B = new(H)
	var/obj/item/weapon/material/kitchen/utensil/knife/K = new(H)
	map.ID = MAP_NOMADS_EARTH_AFRICA
	rubber_check(J.rubber_tree() && rubber_trees_here(), "a jungle tree in Africa is a rubber tree")
	J.attackby(B, H)
	rubber_check(B.reagents.total_volume == 0 && J.health == J.maxhealth, "without a knife in the other hand nothing is tapped and the tree is not hurt")
	H.other_hand = K
	J.attackby(B, H)
	rubber_check(B.reagents.get_reagent_amount("latex") == 10 && J.health == J.maxhealth, "with a knife the bucket catches 10 latex ([B.reagents.get_reagent_amount("latex")])")
	J.attackby(B, H)
	rubber_check(B.reagents.get_reagent_amount("latex") == 10, "the cut bleeds again only after the wait")
	J.latex_tapped_at -= 11000
	J.attackby(B, H)
	rubber_check(B.reagents.get_reagent_amount("latex") == 10, "the tree is still bled out after eighteen minutes")
	J.latex_tapped_at -= 1001
	rubber_wait_ok = FALSE
	J.attackby(B, H)
	rubber_wait_ok = TRUE
	rubber_check(B.reagents.get_reagent_amount("latex") == 10, "an interrupted tapping gives nothing")
	J.attackby(B, H)
	rubber_check(B.reagents.get_reagent_amount("latex") == 20, "after the wait it gives 10 more")
	var/obj/item/weapon/reagent_containers/glass/bucket/full = new(H)
	full.reagents.add_reagent("water", full.reagents.maximum_volume - 5)
	J.latex_tapped_at -= 12001
	J.attackby(full, H)
	rubber_check(!full.reagents.has_reagent("latex") && J.latex_bled_out() == FALSE, "a container without room for 10 latex taps nothing and leaves the tree ready")
	H.other_hand = null
	J.latex_tapped_at = null
	H.a_intent = I_HARM
	J.attackby(B, H)
	H.a_intent = I_HELP
	rubber_check(B.reagents.get_reagent_amount("latex") == 20, "in harm intent a container taps nothing")
	H.other_hand = K
	J.attackby(K, H)
	rubber_check(J.health < J.maxhealth, "a knife on its own still cuts at the tree")
	var/obj/structure/wild/jungle/acacia/A = new(locate(7, 7, 1))
	rubber_check(!A.rubber_tree(), "an acacia is no rubber tree")
	map.ID = MAP_NOMADS_GAIA
	var/obj/structure/wild/jungle/G = new(locate(3, 7, 1))
	G.attackby(B, H)
	rubber_check(!G.rubber_tree() && B.reagents.get_reagent_amount("latex") == 20, "on Gaia jungle trees give no latex")
	map.ID = "rubber_probe_island"
	rubber_check(G.rubber_tree(), "a land that is no continent keeps its rubber trees")
	// Curing.
	var/obj/item/stack/ore/sulphur/S = new(T)
	S.amount = 3
	S.attackby(B, H)
	var/obj/item/stack/material/rubber/R = locate() in get_turf(H)
	if (!R)
		R = locate() in H
	rubber_check(R && R.amount == 1 && S.amount == 2 && B.reagents.get_reagent_amount("latex") == 10, "10 latex and a sulphur rock cure into a sheet of rubber")
	B.reagents.remove_reagent("latex", 5)
	var/sheets_before = rubber_sheets(H)
	S.attackby(B, H)
	rubber_check(S.amount == 2 && B.reagents.get_reagent_amount("latex") == 5 && rubber_sheets(H) == sheets_before, "5 latex is not enough")
	B.reagents.add_reagent("latex", 5)
	persistence_save_in_progress = TRUE
	S.attackby(B, H)
	persistence_save_in_progress = FALSE
	rubber_check(S.amount == 2 && B.reagents.get_reagent_amount("latex") == 10 && rubber_sheets(H) == sheets_before, "no curing finishes during a world save")
	rubber_check(get_material_by_name("rubber") && R && R.material && R.material.name == "rubber", "rubber is a material")
	// Uses.
	var/obj/item/stack/material/copper/C = new(T)
	C.amount = 2
	R.amount = 2
	var/cable_before = rubber_cable_units(get_turf(R))
	R.attackby(C, H)
	rubber_check(R.amount == 1 && C.amount == 1 && rubber_cable_units(get_turf(R)) == cable_before + 1, "rubber and copper make one unit of insulated cable")

/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		movementMachine = new
		map = new /obj/map_metadata/rubber_probe
		map.ordinal_age = 5
		populate_material_list()
		var/turf/T = locate(5, 5, 1)
		var/mob/living/human/rubber_probe/H = new(locate(5, 6, 1))
		H.a_intent = I_HELP
		rubber_check(!world.port, "fixture has no listening port")
		rubber_checks(H, T)
	catch(var/exception/e)
		rubber_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = rubber_failures, "runtime_error" = rubber_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)
