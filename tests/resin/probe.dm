// Pine resin (code/modules/1713/resin.dm): tapping a pine for resin, cooking
// it down into lumps over a lit brazier, melting a lump back in a hot pot, and
// resin as a material and a torch fuel. The production procs run; only the
// do_after waits and the probe mob's other hand are stood in for.
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
/obj/map_metadata/resin_probe/New()
	return
/mob/living/human/resin_probe
	var/obj/item/other_hand = null
/mob/living/human/resin_probe/New()
	return
/mob/living/human/resin_probe/get_inactive_hand()
	return other_hand
/mob/living/human/resin_probe/put_in_hands(obj/item/W)
	return FALSE
var/resin_failures = 0
var/resin_runtime_error = FALSE
var/resin_wait_ok = TRUE
/proc/resin_check(condition, label)
	if (!condition)
		resin_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	resin_runtime_error = TRUE
	world.log << "runtime error: [e] [e.file]:[e.line]"
/obj/structure/wild/tree/live_tree/pine/resin_tap_wait(mob/living/human/H)
	return resin_wait_ok
/obj/item/weapon/reagent_containers/resin_cook_wait(mob/living/human/H, atom/source)
	return resin_wait_ok

/proc/resin_lumps(mob/living/human/H)
	. = 0
	for (var/obj/item/stack/material/resin/R in get_turf(H))
		. += R.amount
	for (var/obj/item/stack/material/resin/R in H)
		. += R.amount

/proc/resin_checks(mob/living/human/resin_probe/H, turf/T)
	var/obj/structure/wild/tree/live_tree/pine/P = new(locate(5, 7, 1))
	var/obj/item/weapon/reagent_containers/glass/bucket/B = new(H)
	var/obj/item/weapon/material/kitchen/utensil/knife/K = new(H)
	resin_check(P.resin_tree(), "a living pine is a resin tree")
	P.attackby(B, H)
	resin_check(B.reagents.total_volume == 0 && P.health == P.maxhealth, "without a knife in the other hand nothing is tapped and the tree is not hurt")
	H.other_hand = K
	P.attackby(B, H)
	resin_check(B.reagents.get_reagent_amount("resin") == 10 && P.health == P.maxhealth, "with a knife the bucket catches 10 resin ([B.reagents.get_reagent_amount("resin")])")
	P.attackby(B, H)
	resin_check(B.reagents.get_reagent_amount("resin") == 10, "the cut weeps again only after the wait")
	P.resin_tapped_at -= 11000
	P.attackby(B, H)
	resin_check(B.reagents.get_reagent_amount("resin") == 10, "the pine is still bled out after eighteen minutes")
	P.resin_tapped_at -= 1001
	resin_wait_ok = FALSE
	P.attackby(B, H)
	resin_wait_ok = TRUE
	resin_check(B.reagents.get_reagent_amount("resin") == 10, "an interrupted tapping gives nothing")
	P.attackby(B, H)
	resin_check(B.reagents.get_reagent_amount("resin") == 20, "after the wait it gives 10 more")
	var/obj/item/weapon/reagent_containers/glass/bucket/full = new(H)
	full.reagents.add_reagent("water", full.reagents.maximum_volume - 5)
	P.resin_tapped_at -= 12001
	P.attackby(full, H)
	resin_check(!full.reagents.has_reagent("resin") && !P.resin_bled_out(), "a container without room for 10 resin taps nothing and leaves the tree ready")
	P.resin_tapped_at = null
	H.a_intent = I_HARM
	P.attackby(B, H)
	H.a_intent = I_HELP
	resin_check(B.reagents.get_reagent_amount("resin") == 20, "in harm intent a container taps nothing")
	P.radiation = 20
	P.attackby(B, H)
	resin_check(B.reagents.get_reagent_amount("resin") == 20 && !P.resin_tree(), "a dead pine gives no resin")
	P.radiation = 0
	var/obj/structure/wild/tree/live_tree/O = new(locate(7, 7, 1))
	O.attackby(B, H)
	resin_check(B.reagents.get_reagent_amount("resin") == 20, "a broadleaf tree gives no resin")
	P.attackby(K, H)
	resin_check(P.health < P.maxhealth, "a knife on its own still cuts at the tree")
	// Cooking down.
	var/obj/structure/brazier/Z = new(T)
	Z.on = FALSE
	Z.attackby(B, H)
	resin_check(resin_lumps(H) == 0 && B.reagents.get_reagent_amount("resin") == 20, "an unlit brazier cooks nothing")
	Z.on = TRUE
	Z.attackby(B, H)
	resin_check(resin_lumps(H) == 1 && B.reagents.get_reagent_amount("resin") == 10 && B.reagents.get_reagent_amount("turpentine") == 2, "10 resin cooks into a lump and leaves 2 turpentine")
	persistence_save_in_progress = TRUE
	Z.attackby(B, H)
	persistence_save_in_progress = FALSE
	resin_check(resin_lumps(H) == 1 && B.reagents.get_reagent_amount("resin") == 10, "no cooking finishes during a world save")
	B.reagents.remove_reagent("resin", 5)
	Z.attackby(B, H)
	resin_check(resin_lumps(H) == 1 && B.reagents.get_reagent_amount("resin") == 5, "5 resin is not enough for a lump")
	var/obj/item/stack/material/resin/R = locate() in get_turf(H)
	if (!R)
		R = locate() in H
	resin_check(R && get_material_by_name("resin") && R.material && R.material.name == "resin", "resin is a material")
	// Melting.
	var/obj/item/weapon/reagent_containers/glass/bucket/pot = new(H)
	R.attackby(pot, H)
	resin_check(R && R.amount == 1 && !pot.reagents.has_reagent("resin"), "a cold pot melts no resin")
	pot.heated_until = world.time + 600
	R.amount = 2
	R.attackby(pot, H)
	resin_check(R.amount == 1 && pot.reagents.get_reagent_amount("resin") == 10, "a hot pot melts a lump into 10 resin")
	// Fuel.
	var/obj/item/flashlight/torch/TO = new(T)
	resin_check(TO.refuel_reagents["resin"] > TO.refuel_reagents["fat_oil"] && TO.refuel_reagents["turpentine"], "resin and turpentine fuel a torch, resin longer than oil")

/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		movementMachine = new
		map = new /obj/map_metadata/resin_probe
		map.ordinal_age = 1
		populate_material_list()
		var/turf/T = locate(5, 5, 1)
		var/mob/living/human/resin_probe/H = new(locate(5, 6, 1))
		H.a_intent = I_HELP
		resin_check(!world.port, "fixture has no listening port")
		resin_checks(H, T)
	catch(var/exception/e)
		resin_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = resin_failures, "runtime_error" = resin_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)
