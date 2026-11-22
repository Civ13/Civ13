// Lacquer and spirit varnish (code/modules/1713/lacquer.dm): tapping lacquer
// trees in the silk lands, mixing spirit varnish, and brushing a finish that
// slows wear. The procs run; only the do_after waits and the probe mob's hands
// are stood in for.
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
/obj/map_metadata/lacquer_probe/New()
	return
/mob/living/human/lacquer_probe
	var/obj/item/other_hand = null
/mob/living/human/lacquer_probe/New()
	return
/mob/living/human/lacquer_probe/get_inactive_hand()
	return other_hand
/mob/living/human/lacquer_probe/put_in_hands(obj/item/W)
	return FALSE
var/lacquer_failures = 0
var/lacquer_runtime_error = FALSE
var/lacquer_wait_ok = TRUE
/proc/lacquer_check(condition, label)
	if (!condition)
		lacquer_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	lacquer_runtime_error = TRUE
	world.log << "runtime error: [e] [e.file]:[e.line]"
/obj/structure/wild/tree/live_tree/lacquer_tap_wait(mob/living/human/H)
	return lacquer_wait_ok
/obj/item/finish_wait(mob/living/human/H, obj/item/target)
	return lacquer_wait_ok

/proc/lacquer_checks(mob/living/human/lacquer_probe/H, turf/T)
	H.a_intent = I_HELP
	map.ID = MAP_NOMADS_EARTH_ASIA
	// Tapping.
	var/obj/structure/wild/tree/live_tree/L = new(locate(5, 7, 1))
	var/obj/item/weapon/reagent_containers/glass/bucket/B = new(H)
	var/obj/item/weapon/material/kitchen/utensil/knife/K = new(H)
	lacquer_check(L.lacquer_tree(), "a broadleaf tree in Asia is a lacquer tree")
	L.attackby(B, H)
	lacquer_check(B.reagents.total_volume == 0, "without a knife nothing is tapped")
	H.other_hand = K
	lacquer_wait_ok = FALSE
	L.attackby(B, H)
	lacquer_wait_ok = TRUE
	lacquer_check(B.reagents.total_volume == 0, "an interrupted tap gives nothing")
	L.attackby(B, H)
	lacquer_check(B.reagents.get_reagent_amount("lacquer") == 5, "a knife and a bucket tap 5 lacquer")
	L.attackby(B, H)
	lacquer_check(B.reagents.get_reagent_amount("lacquer") == 5, "a tapped tree waits before it bleeds again")
	L.lacquer_tapped_at = world.time - 13000
	L.attackby(B, H)
	lacquer_check(B.reagents.get_reagent_amount("lacquer") == 10, "after the wait it bleeds again")
	map.ID = MAP_NOMADS_GAIA
	lacquer_check(!L.lacquer_tree(), "Gaia has no lacquer trees")
	var/obj/structure/wild/tree/live_tree/pine/P = new(locate(7, 7, 1))
	map.ID = MAP_NOMADS_EARTH_ASIA
	lacquer_check(!P.lacquer_tree(), "a pine is no lacquer tree")
	// Varnish.
	var/obj/item/weapon/reagent_containers/glass/bucket/V = new(H)
	V.reagents.add_reagent("resin", 10)
	V.reagents.add_reagent("ethanol", 5)
	for (var/i in 1 to 20) // the chemistry process would run these
		V.reagents.process_reactions()
	lacquer_check(V.reagents.get_reagent_amount("spirit_varnish") == 15 && !V.reagents.has_reagent("resin"), "resin and ethanol mix into spirit varnish")
	// Finishing.
	var/obj/item/weapon/reagent_containers/glass/finishing_pot/F = new(H)
	F.reagents.add_reagent("lacquer", 10)
	lacquer_check(F.icon_state == "lacquer_pot", "a pot of lacquer shows the lacquer pot")
	var/obj/item/weapon/material/kitchen/utensil/knife/steel = new(T)
	lacquer_check(finish_refusal(steel), "a steel knife takes no finish")
	var/obj/item/weapon/material/kitchen/rollingpin/R = new(T)
	lacquer_check(!finish_refusal(R), "a wooden rolling pin takes a finish")
	lacquer_check(!finish_refusal(new /obj/item/weapon/shield(T)), "a wooden shield takes a finish")
	lacquer_check(!finish_refusal(new /obj/item/clothing/head/helmet/leather(T)), "a leather helmet takes a finish")
	lacquer_check(!finish_refusal(new /obj/item/clothing/suit/armor/ancient/bronze_lamellar(T)), "lamellar takes a finish")
	H.a_intent = I_HARM
	F.resolve_attackby(R, H)
	H.a_intent = I_HELP
	lacquer_check(!R.finish && F.reagents.get_reagent_amount("lacquer") == 10, "harm intent brushes nothing")
	lacquer_wait_ok = FALSE
	F.resolve_attackby(R, H)
	lacquer_wait_ok = TRUE
	lacquer_check(!R.finish && F.reagents.get_reagent_amount("lacquer") == 10, "an interrupted coat uses nothing")
	F.resolve_attackby(R, H)
	lacquer_check(R.finish == "lacquer" && R.finish_left == 150 && F.reagents.get_reagent_amount("lacquer") == 5, "a coat of lacquer costs 5 units")
	F.resolve_attackby(R, H)
	lacquer_check(F.reagents.get_reagent_amount("lacquer") == 5, "a good coat is not brushed again")
	R.maxhealth = 100
	R.health = 100
	var/before = R.health
	R.apply_wear(4)
	lacquer_check(abs((before - R.health) - 3) < 0.01 && abs(R.finish_left - 147) < 0.01, "a finished item wears 25% slower and the coat wears down")
	R.finish_left = 1
	R.apply_wear(4)
	lacquer_check(!R.finish && R.finish_left == 0, "a worn-through coat is gone")
	before = R.health
	R.apply_wear(4)
	lacquer_check(abs((before - R.health) - 4) < 0.01, "without a coat wear is as before")
	F.reagents.clear_reagents()
	F.reagents.add_reagent("spirit_varnish", 5)
	lacquer_check(F.icon_state == "varnish_pot", "a pot of varnish shows the varnish pot")
	F.resolve_attackby(R, H)
	lacquer_check(R.finish == "spirit_varnish" && R.finish_left == 80, "varnish gives a shorter coat")

/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		movementMachine = new
		map = new /obj/map_metadata/lacquer_probe
		map.ordinal_age = 1
		populate_material_list()
		initialize_chemical_reactions()
		var/turf/T = locate(5, 5, 1)
		var/mob/living/human/lacquer_probe/H = new(locate(5, 6, 1))
		lacquer_check(!world.port, "fixture has no listening port")
		lacquer_checks(H, T)
	catch(var/exception/e)
		lacquer_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = lacquer_failures, "runtime_error" = lacquer_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)
