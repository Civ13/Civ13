// Native syrups probe (code/modules/1713/syrups.dm), included by
// tests/ecology_spawning/run_linux.py, never by the game DME. The procs run;
// only the do_after wait and the probe mob's hands are stood in for.
/world
	hub = ""
	hub_password = ""
	maxx = 12
	maxy = 12
	maxz = 1
	turf = /turf
	area = /area/syrup_probe
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/area/syrup_probe
	location = AREA_OUTSIDE
	climate = "temperate"
/obj/map_metadata/syrup_probe/New()
	return
/mob/living/human/syrup_probe
	var/obj/item/other_hand = null
/mob/living/human/syrup_probe/New()
	icon_update = FALSE // no species: skip body overlays when held items change
	return
/mob/living/human/syrup_probe/get_inactive_hand()
	return other_hand
/mob/living/human/syrup_probe/put_in_hands(obj/item/W)
	return FALSE
var/syrup_failures = 0
var/syrup_runtime_error = FALSE
var/syrup_wait_ok = TRUE
/proc/syrup_check(condition, label)
	if (!condition)
		syrup_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	syrup_runtime_error = TRUE
	world.log << "runtime error: [e] [e.file]:[e.line]"
/obj/structure/wild/tree/live_tree/sap_tap_wait(mob/living/human/H)
	return syrup_wait_ok

/proc/syrup_near(a, b)
	return abs(a - b) < 0.01

/proc/syrup_tap_checks(mob/living/human/syrup_probe/H)
	H.a_intent = I_HELP
	map.ID = MAP_NOMADS_GAIA
	season = SEASON_SPRING
	var/obj/structure/wild/tree/live_tree/L = new(locate(5, 7, 1))
	var/obj/item/weapon/reagent_containers/glass/bucket/B = new(H)
	var/obj/item/weapon/material/kitchen/utensil/knife/K = new(H)
	syrup_check(!sap_tap_attackby(L, B, H), "without a knife the tree is left alone")
	H.other_hand = K
	syrup_wait_ok = FALSE
	L.attackby(B, H)
	syrup_wait_ok = TRUE
	syrup_check(B.reagents.total_volume == 0, "an interrupted tap gives nothing")
	L.attackby(B, H)
	syrup_check(B.reagents.get_reagent_amount("tree_sap") == 10, "a knife and a bucket tap 10 sap in spring")
	L.attackby(B, H)
	syrup_check(B.reagents.get_reagent_amount("tree_sap") == 10, "a tapped tree waits before it runs again")
	L.sap_tapped_at = world.time - 13000
	season = SEASON_SUMMER
	L.attackby(B, H)
	syrup_check(B.reagents.get_reagent_amount("tree_sap") == 10, "no sap runs in summer")
	season = SEASON_WINTER
	L.attackby(B, H)
	syrup_check(B.reagents.get_reagent_amount("tree_sap") == 20, "the sap runs again at the end of winter")
	L.sap_tapped_at = null
	var/area/syrup_probe/A = get_area(L)
	A.climate = "desert"
	L.attackby(B, H)
	A.climate = "temperate"
	syrup_check(B.reagents.get_reagent_amount("tree_sap") == 20, "desert trees give no sap")
	var/obj/structure/wild/tree/live_tree/pine/P = new(locate(7, 7, 1))
	syrup_check(!P.sap_tree(), "a pine gives resin, not sap")
	map.ID = MAP_NOMADS_EARTH_ASIA
	syrup_check(L.lacquer_tree(), "in the silk lands the tree is a lacquer tree")
	L.attackby(B, H)
	syrup_check(B.reagents.get_reagent_amount("tree_sap") == 20 && B.reagents.get_reagent_amount("lacquer") == 5, "lacquer trees keep giving lacquer")
	map.ID = MAP_NOMADS_GAIA
	qdel(B)
	qdel(K)
	qdel(L)
	qdel(P)

/proc/syrup_boil_checks()
	var/obj/item/weapon/reagent_containers/glass/small_pot/P = new(locate(9, 9, 1))
	P.reagents.add_reagent("tree_sap", 40)
	var/list/done = P.reagents.boil_syrups()
	syrup_check(("maple_syrup" in done) && syrup_near(P.reagents.get_reagent_amount("maple_syrup"), 5) && !P.reagents.has_reagent("tree_sap"), "40 sap boils down to 5 maple syrup")
	done = P.reagents.boil_syrups()
	syrup_check(("maple_sugar" in done) && syrup_near(P.reagents.get_reagent_amount("sugar"), 2.5) && !P.reagents.has_reagent("maple_syrup"), "maple syrup boiled again sets into maple sugar")
	P.reagents.clear_reagents()
	P.reagents.add_reagent("sugar", 10)
	P.reagents.add_reagent("water", 15)
	done = P.reagents.boil_syrups()
	syrup_check(("sugar_syrup" in done) && syrup_near(P.reagents.get_reagent_amount("sugar_syrup"), 20) && syrup_near(P.reagents.get_reagent_amount("water"), 5) && !P.reagents.has_reagent("sugar"), "sugar and water boil into simple syrup, extra water stays")
	done = P.reagents.boil_syrups()
	syrup_check(!length(done) && syrup_near(P.reagents.get_reagent_amount("sugar_syrup"), 20), "water left in the pot keeps the syrup thin")
	P.reagents.del_reagent("water")
	done = P.reagents.boil_syrups()
	syrup_check(("molasses" in done) && syrup_near(P.reagents.get_reagent_amount("sugar"), 8) && syrup_near(P.reagents.get_reagent_amount("molasses"), 2), "simple syrup boiled again gives clean sugar and molasses")
	P.reagents.clear_reagents()
	P.reagents.add_reagent("water", 20)
	syrup_check(!length(P.reagents.boil_syrups()) && P.reagents.get_reagent_amount("water") == 20, "plain water is untouched")
	qdel(P)

/proc/syrup_mix(list/parts, list/catalyst = null)
	var/obj/item/weapon/reagent_containers/glass/bucket/B = new(locate(3, 3, 1))
	for (var/id in parts)
		B.reagents.add_reagent(id, parts[id])
	if (catalyst)
		for (var/id in catalyst)
			B.reagents.add_reagent(id, catalyst[id])
	for (var/i in 1 to 20) // the chemistry process would run these
		B.reagents.process_reactions()
	return B

/proc/syrup_use_checks()
	var/obj/item/weapon/reagent_containers/glass/bucket/B = syrup_mix(list("berryjuice" = 5, "sugar_syrup" = 10))
	syrup_check(syrup_near(B.reagents.get_reagent_amount("fruit_syrup"), 15), "berry juice and simple syrup make fruit syrup")
	qdel(B)
	B = syrup_mix(list("orangejuice" = 5, "sugar_syrup" = 10))
	syrup_check(syrup_near(B.reagents.get_reagent_amount("fruit_syrup"), 15), "orange juice and simple syrup make fruit syrup")
	qdel(B)
	B = syrup_mix(list("lemonjuice" = 5, "sugar_syrup" = 10))
	syrup_check(syrup_near(B.reagents.get_reagent_amount("lemonade"), 15) && !B.reagents.has_reagent("fruit_syrup"), "lemon juice and simple syrup make lemonade")
	qdel(B)
	B = syrup_mix(list("applejuice" = 10, "maple_syrup" = 5))
	syrup_check(syrup_near(B.reagents.get_reagent_amount("jam"), 10), "maple syrup sets apple jam")
	qdel(B)
	B = syrup_mix(list("molasses" = 4, "water" = 4), list("enzyme" = 5))
	syrup_check(syrup_near(B.reagents.get_reagent_amount("rum"), 4), "molasses and water ferment into rum")
	qdel(B)
	var/datum/reagent/nutriment/syrup/maple/M = new
	syrup_check(M.nutriment_factor > 0, "maple syrup is food")
	qdel(M)

/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		movementMachine = new
		map = new /obj/map_metadata/syrup_probe
		map.ordinal_age = 1
		populate_material_list()
		initialize_chemical_reactions()
		var/mob/living/human/syrup_probe/H = new(locate(5, 6, 1))
		syrup_check(!world.port, "fixture has no listening port")
		syrup_tap_checks(H)
		syrup_boil_checks()
		syrup_use_checks()
	catch(var/exception/e)
		syrup_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = syrup_failures, "runtime_error" = syrup_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)
