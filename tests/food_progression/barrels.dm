// Isolated actual barrel ingredient handlers; no normal game startup/client.
/obj/map_metadata/barrel_fixture/New()
	return
/mob/living/human/barrel_fixture/New()
	return
/mob/living/human/barrel_fixture/update_inv_l_hand(update_icons = 1)
	return
/mob/living/human/barrel_fixture/update_inv_r_hand(update_icons = 1)
	return
/mob/living/human/barrel_fixture/update_action_buttons()
	return
/mob/living/human/barrel_fixture/update_icons()
	return
/obj/item/stack/ore/sulphur/barrel_fixture
	amount = 25

/proc/barrel_check(condition, message)
	if (!condition)
		text2file("FAIL: [message]", "food_result.txt")
		del(world)
		sleep(1)

/proc/barrel_clear(turf/site)
	for (var/obj/O in site)
		qdel(O)

/world
	hub = ""
	hub_password = ""
	maxx = 6
	maxy = 3
	maxz = 1
	fps = 20
	turf = /turf/floor/plating
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/world/Topic(T, addr, master, key)
	return "Barrel fixture has no remote operations."
/world/Error(exception/e, datum/e_src)
	world.log << "Runtime error: [e]"
	text2file("FAIL: runtime [e]", "food_result.txt")
	del(world)
	sleep(1)
/world/New()
	world.OpenPort("none")
	if (config) config.webhook_can_fire = FALSE
	GLOB.all_observable_events = list()
	GLOB.moved_event = new /decl/observ/moved
	GLOB.dir_set_event = new /decl/observ/dir_set
	GLOB.name_set_event = new /decl/observ/name_set
	GLOB.stat_set_event = new /decl/observ/stat_set
	initialize_chemical_reagents()
	initialize_chemical_reactions()
	map = new /obj/map_metadata/barrel_fixture
	map.ID = MAP_NOMADS_CONTINENTAL
	var/turf/site = locate(3,2,1)
	var/mob/living/human/barrel_fixture/H = new(locate(2,2,1))
	var/list/routes = json_decode(file2text("barrel-ingredient-routes.json"))
	for (var/list/route in routes)
		var/path = text2path("/obj/item/stack/ore/[route["input"]]")
		for (var/count in list(1, 2))
			var/obj/item/weapon/reagent_containers/glass/barrel/B = new(site)
			B.reagents.add_reagent("water", 247)
			var/obj/item/stack/S = new path(H)
			S.amount = count
			barrel_check(H.put_in_active_hand(S), "ore occupies a legal hand")
			B.attackby(S, H)
			barrel_check(B.reagents.get_reagent_amount(route["reagent"]) == route["dose"] && B.reagents.total_volume == 250, "exact final ore dose fills actual barrel capacity")
			if (count == 1)
				barrel_check(QDELETED(S) && !H.get_active_hand(), "last paid unit clears its actual hand")
			else
				barrel_check(!QDELETED(S) && S.amount == count - route["stock"], "multi-unit stock debited exactly once")
				H.remove_from_mob(S); qdel(S)
			qdel(B)
	// Preset subtype stays accepted; invalid stock/closed/full/saving cases pay nothing.
	for (var/change in list("subtype", "zero", "fraction", "closed", "capacity", "far", "save", "bound"))
		var/obj/item/weapon/reagent_containers/glass/barrel/B = new(site)
		var/obj/item/stack/ore/sulphur/barrel_fixture/S = new(H)
		barrel_check(H.put_in_active_hand(S), "rejection stock legal hand")
		switch (change)
			if ("zero") S.amount = 0
			if ("fraction") S.amount = 0.5
			if ("closed") B.flags &= ~OPENCONTAINER
			if ("capacity")
				B.reagents.maximum_volume = 8
				B.reagents.add_reagent("water", 6)
			if ("far") B.forceMove(locate(6,2,1))
			if ("save") persistence_save_in_progress = TRUE
			if ("bound") S.canremove = FALSE
		var/before = S.amount
		B.attackby(S, H)
		if (change == "subtype")
			barrel_check(S.amount == before - 1 && B.reagents.get_reagent_amount("sulfur") == 3, "stock subtype uses the same paid conversion")
		else
			barrel_check(!QDELETED(S) && S.amount == before && !B.reagents.get_reagent_amount("sulfur"), "rejected stock leaves inputs and output unchanged: [change]")
		persistence_save_in_progress = FALSE
		S.canremove = TRUE
		H.remove_from_mob(S); qdel(S); qdel(B)
	// A carried barrel uses legal inventory slots rather than a forged location.
	var/obj/item/weapon/reagent_containers/glass/barrel/carried = new(site)
	barrel_check(H.put_in_inactive_hand(carried), "carried barrel legal hand")
	var/obj/item/stack/ore/sulphur/carried_stock = new(H)
	barrel_check(H.put_in_active_hand(carried_stock), "carried-barrel stock legal hand")
	barrel_check(carried.ingredient_actor_ready(carried_stock, H), "carried barrel resolves its containing turf for admission")
	carried.attackby(carried_stock, H)
	barrel_check(QDELETED(carried_stock) && carried.reagents.get_reagent_amount("sulfur") == 3, "carried barrel receives one paid dose")
	H.remove_from_mob(carried); qdel(carried)
	// Whole manure payloads only: zero/partial transfers must never delete the item.
	for (var/change in list("whole", "animal", "fertilizer", "depleted", "trace", "trace exact room", "closed", "partial room", "oversized", "empty", "zero transfer"))
		var/obj/item/weapon/reagent_containers/glass/barrel/B = new(site)
		var/path = /obj/item/weapon/reagent_containers/food/snacks/poo
		if (change == "animal") path = /obj/item/weapon/reagent_containers/food/snacks/poo/animal
		if (change == "fertilizer") path = /obj/item/weapon/reagent_containers/food/snacks/poo/fertilizer
		var/obj/item/weapon/reagent_containers/food/snacks/poo/P = new path(H)
		barrel_check(H.put_in_active_hand(P), "manure occupies a legal hand")
		var/water = change == "trace" ? 239 : 240
		B.reagents.add_reagent("water", water)
		if (change == "depleted") P.reagents.remove_reagent("poo", 4)
		if (change == "trace" || change == "trace exact room")
			P.reagents.remove_reagent("poo", 0.01)
			P.reagents.add_reagent("cyanide", 0.01)
		if (change == "closed") B.flags &= ~OPENCONTAINER
		if (change == "partial room") B.reagents.add_reagent("water", 6.5)
		if (change == "oversized") P.reagents.add_reagent("cyanide", 0.01)
		if (change == "empty") P.reagents.clear_reagents()
		if (change == "zero transfer") B.simulated = FALSE
		var/paid = P.reagents.total_volume
		var/poison = P.reagents.get_reagent_amount("cyanide")
		var/recipient_water = B.reagents.get_reagent_amount("water")
		B.attackby(P, H)
		if (change in list("whole", "animal", "fertilizer", "depleted", "trace"))
			barrel_check(QDELETED(P) && !H.get_active_hand() && abs(B.reagents.total_volume - water - paid) < 0.00001 && abs(B.reagents.get_reagent_amount("cyanide") - poison) < 0.000001, "complete payload transferred once without losing its trace: [change]")
		else
			barrel_check(!QDELETED(P) && P.loc == H && P.reagents.total_volume == paid && P.reagents.get_reagent_amount("cyanide") == poison && B.reagents.get_reagent_amount("water") == recipient_water && B.reagents.total_volume == recipient_water, "rejected/zero transfer leaves source and recipient intact: [change]")
			H.remove_from_mob(P); qdel(P)
		qdel(B)
	// Real barrel reagent entry save/load keeps the paid dose and no ingredient item.
	var/obj/item/weapon/reagent_containers/glass/barrel/B = new(site)
	var/obj/item/stack/ore/sulphur/S = new(H)
	barrel_check(H.put_in_active_hand(S), "save stock legal hand")
	B.attackby(S, H)
	var/obj/item/weapon/reagent_containers/food/snacks/poo/P = new(H)
	barrel_check(H.put_in_active_hand(P), "save manure legal hand")
	B.attackby(P, H)
	var/savefile/F = new("barrel.sav")
	F["/format_version"] << 2
	map_storage.clear_bookkeeping()
	map_storage.saving_z = 1
	var/ref = map_storage.BuildVarDirectory(F, B, 1)
	barrel_check(ref && QDELETED(S) && QDELETED(P), "only paid results enter save")
	qdel(B)
	map_storage.clear_bookkeeping()
	B = map_storage.Load_Entry(F, ref, starting_loc = site)
	barrel_check(B && B.reagents.get_reagent_amount("sulfur") == 3 && B.reagents.get_reagent_amount("poo") == 10 && B.reagents.total_volume == 13, "actual barrel entry codec retains both paid doses")
	barrel_clear(site)
	text2file("PASS: barrel paid ore, exact capacity, subtype/stock/actor guards, complete manure/trace transfer, rejection and actual entry save/load", "food_result.txt")
	del(world)
