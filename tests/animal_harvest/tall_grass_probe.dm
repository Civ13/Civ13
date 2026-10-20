// Included by the existing animal-harvest fixture, never by the game DME.
// These use production attackby/validation/material handlers; client and
// wait adapters inject adverse state without normal UI/startup.
/proc/harvest_tall_grass_regressions(turf/site, mob/living/harvest_tester/U, obj/item/weapon/material/kitchen/utensil/knife/K)
	// Both scenery variants enter through the actual player attackby handler.
	for (var/path in list(/obj/structure/wild/tallgrass/twine_tester, /obj/structure/wild/tallgrass2/twine_tester))
		for (var/action in list("complete", "concurrent", "cancel", "drop", "unsharpen", "move", "actor_move", "adjacent_move", "delete", "disconnect", "disconnect_after", "unconscious", "stunned_entry", "stunned", "hand_entry", "hand_switch", "inventory_entry", "inventory", "nested_entry", "nested", "far_entry", "realwait_move", "realwait_complete", "realwait_stunned", "realwait_hand_switch"))
			var/obj/structure/wild/G = new path(site)
			var/obj/item/weapon/flint/sharpened/H = new(U)
			// Setup seam only: exercise real get_active_hand and inventory guards.
			U.hand = TRUE
			U.l_hand = H
			var/obj/item/weapon/storage/backpack/bag = new(U)
			if (action == "inventory_entry")
				U.l_hand = null
			if (action == "hand_entry")
				U.hand = FALSE
			if (action == "nested_entry")
				H.loc = bag
				U.l_hand = bag
			if (action == "stunned_entry")
				U.stunned = TRUE
			if (action == "far_entry")
				U.loc = locate(7,7,1)
			G.vars["test_action"] = action
			var/turf/original_floor = site
			harvest_duplicate_result = null
			var/result = G.attackby(H, U)
			var/obj/item/stack/grass_cuttings/cuttings = locate() in site
			if (action == "complete" || action == "concurrent" || action == "realwait_complete")
				harvest_assert(result && QDELETED(G) && cuttings && cuttings.amount == 2, "Tall grass yield/removal: [path] [action]")
				if (action == "concurrent")
					harvest_assert(harvest_duplicate_result == FALSE, "Competing tall grass cut accepted")
				G.gather_grass_cuttings(U, H)
				harvest_assert(cuttings.amount == 2, "Removed tall grass reused")
				cuttings.loc = U
				cuttings.attack_self(U)
				var/obj/item/stack/crude_twine/cord = locate() in U
				if (!cord)
					cord = locate() in site
				harvest_assert(!cuttings.loc && cord && cord.amount == 1, "Tall grass to existing twine conservation")
				qdel(cord)
			else
				harvest_assert(!result && !cuttings && (QDELETED(G) || !G.cutting_grass), "Interrupted tall grass cut: [path] [action]")
				if (action in list("hand_entry", "inventory_entry", "nested_entry", "stunned_entry", "far_entry", "disconnect"))
					harvest_assert(G.vars["test_wait_calls"] == 0, "Invalid entry reached tall grass wait: [action]")
			harvest_assert(locate(3,3,1) == original_floor, "Tall grass cutting replaced underlying floor")
			U.loc = site
			U.stat = CONSCIOUS
			U.stunned = FALSE
			U.hand = TRUE
			U.l_hand = null
			qdel(G)
			qdel(H)
			qdel(bag)
			harvest_clear(site)
		var/obj/structure/wild/G = new path(site)
		var/obj/item/weapon/flint/raw = new(U)
		U.l_hand = raw
		G.attackby(raw, U)
		harvest_assert(!QDELETED(G) && !harvest_count(site, /obj/item/stack/grass_cuttings), "Unsharpened flint harvested tall grass")
		G.cutting_grass = TRUE
		harvest_assert(G.persistence_runtime_var("cutting_grass") && !("cutting_grass" in G.get_saved_vars()), "Tall grass cutting lock exported")
		G.cutting_grass = FALSE
		K.loc = U
		U.l_hand = K
		harvest_assert(G.attackby(K, U) && QDELETED(G) && harvest_count(site, /obj/item/stack/grass_cuttings) == 1, "Knife did not use tall grass cutting handler")
		qdel(raw)
		harvest_clear(site)
	var/obj/structure/wild/bush/ordinary_bush = new(site)
	harvest_assert(!ordinary_bush.gather_grass_cuttings(U, K) && !harvest_count(site, /obj/item/stack/grass_cuttings), "Non-grass vegetation gained fibre yield")
	qdel(ordinary_bush)
	U.l_hand = null

/obj/structure/wild/tallgrass/twine_tester
	var/test_action = "complete"
	var/test_wait_calls = 0

/obj/structure/wild/tallgrass2/twine_tester
	var/test_action = "complete"
	var/test_wait_calls = 0

/obj/structure/wild/tallgrass/twine_tester/grass_cutting_actor_connected(mob/user)
	return user && test_action != "disconnect"

/obj/structure/wild/tallgrass2/twine_tester/grass_cutting_actor_connected(mob/user)
	return user && test_action != "disconnect"

/obj/structure/wild/tallgrass/twine_tester/grass_cutting_wait(mob/user)
	test_wait_calls++
	return tallgrass_fixture_wait(user, test_action)

/obj/structure/wild/tallgrass2/twine_tester/grass_cutting_wait(mob/user)
	test_wait_calls++
	return tallgrass_fixture_wait(user, test_action)

/obj/structure/wild/proc/tallgrass_fixture_wait(mob/user, action)
	var/obj/item/weapon/flint/tool = locate() in user
	if (action == "realwait_complete")
		return do_after(user, 2, src, progress = FALSE)
	if (action == "realwait_move")
		spawn(1)
			user.loc = locate(7,7,1)
		return do_after(user, 3, src, progress = FALSE)
	if (action == "realwait_stunned")
		spawn(1)
			user.stunned = TRUE
		return do_after(user, 3, src, progress = FALSE)
	if (action == "realwait_hand_switch")
		spawn(1)
			user.hand = !user.hand
		return do_after(user, 3, src, progress = FALSE)
	if (action == "cancel")
		return FALSE
	if (action == "drop")
		tool.loc = get_turf(user)
	if (action == "unsharpen")
		tool.sharp = FALSE
	if (action == "move")
		loc = locate(7,7,1)
	if (action == "actor_move")
		user.loc = locate(7,7,1)
	if (action == "adjacent_move")
		user.loc = locate(4,3,1)
	if (action == "delete")
		qdel(src)
	if (action == "disconnect_after")
		vars["test_action"] = "disconnect"
	if (action == "unconscious")
		user.stat = UNCONSCIOUS
	if (action == "stunned")
		user.stunned = TRUE
	if (action == "hand_switch")
		user.hand = !user.hand
	if (action == "inventory")
		user.l_hand = null
	if (action == "nested")
		var/obj/item/weapon/storage/backpack/bag = locate() in user
		tool.loc = bag
		user.l_hand = bag
	if (action == "concurrent")
		harvest_duplicate_result = attackby(tool, user)
	return TRUE
