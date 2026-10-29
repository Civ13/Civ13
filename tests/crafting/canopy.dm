// Real canopy/roof/area constructors and real waits; inert existing human startup.
/world
	maxx = 4
	maxy = 3

/proc/canopy_ci_count(turf/site, path)
	var/count = 0
	for (var/obj/O in site)
		if (!QDELETED(O) && istype(O, path))
			count++
	return count

/proc/canopy_ci_area(turf/site, expected)
	var/area/A = get_area(site)
	return A && A.location == expected

/proc/canopy_ci_clear(turf/site)
	// Remove an independent roof first, restoring its previous canopy-covered area.
	for (var/obj/roof/R in site)
		if (!istype(R, /obj/roof/canopy))
			qdel(R)
	for (var/obj/roof/canopy/R in site)
		qdel(R)
	for (var/obj/O in site)
		qdel(O)

/proc/recipe_ci_canopy()
	map.ordinal_age = 0
	var/turf/site = locate(3,2,1)
	var/turf/neighbor = locate(4,2,1)
	var/mob/living/human/handle_ci/H = new(site)
	H.civilization = "recipe_ci"
	// Preserve both paid ways to make the same existing portable item.
	for (var/material_path in list(/material/cloth, /material/leather))
		var/stock_path = material_path == /material/cloth ? /obj/item/stack/material/cloth : /obj/item/stack/material/leather
		var/cost = material_path == /material/cloth ? 4 : 5
		var/datum/stack_recipe/R = recipe_ci_food_recipe(material_path, /obj/item/weapon/tent, H.civilization)
		joinery_ci_expect(R && R.req_amount == cost, "existing paid canopy route: [material_path]")
		if (!R)
			continue
		R.time = 0 // Only bound recipe crafting delay; canopy actions retain real waits.
		var/obj/item/stack/stock = new stock_path(H, cost + 2, FALSE)
		var/obj/item/weapon/flint/blocker = new(H)
		joinery_ci_expect(H.put_in_active_hand(stock) && H.put_in_hands(blocker), "paid canopy fixture fills legal hands")
		stock.produce_recipe(R, 1, H)
		joinery_ci_expect(stock.amount == 2 && canopy_ci_count(site, /obj/item/weapon/tent) == 1, "canopy pays original material cost")
		H.remove_from_mob(stock); qdel(stock)
		H.remove_from_mob(blocker); qdel(blocker)
		canopy_ci_clear(site)
	var/obj/item/weapon/tent/item = new(H)
	joinery_ci_expect(H.put_in_active_hand(item), "unfold fixture legal hand")
	item.attack_self(H)
	var/obj/structure/tent/tent = locate() in site
	joinery_ci_expect(QDELETED(item) && tent && canopy_ci_count(site, /obj/roof/canopy) == 1 && canopy_ci_area(site, AREA_INSIDE), "unfold creates one canopy with real covered area")
	// Two actors folding the same instance yield only one portable item.
	var/mob/living/human/handle_ci/other = new(site)
	if (tent)
		spawn(0)
			tent.fold_up(other)
		tent.fold_up(H)
		sleep(1)
	joinery_ci_expect(canopy_ci_count(site, /obj/item/weapon/tent) == 1 && !canopy_ci_count(site, /obj/structure/tent) && !canopy_ci_count(site, /obj/roof/canopy) && canopy_ci_area(site, AREA_OUTSIDE), "concurrent fold refunds exactly one item and removes its cover")
	canopy_ci_clear(site)
	// A held item must inspect its destination, not the human's contents.
	tent = new(site)
	item = new(H)
	joinery_ci_expect(H.put_in_active_hand(item), "occupied canopy fixture legal hand")
	item.attack_self(H)
	joinery_ci_expect(!QDELETED(item) && canopy_ci_count(site, /obj/structure/tent) == 1, "existing destination canopy refuses unfolding")
	H.remove_from_mob(item); qdel(item)
	canopy_ci_clear(site)
	// A competitor completing during the real wait preserves the losing input.
	item = new(H)
	joinery_ci_expect(H.put_in_active_hand(item), "late occupancy fixture legal hand")
	spawn(1)
		new /obj/structure/tent(site)
	item.attack_self(H)
	joinery_ci_expect(!QDELETED(item) && canopy_ci_count(site, /obj/structure/tent) == 1 && canopy_ci_count(site, /obj/roof/canopy) == 1, "late destination occupancy produces no duplicate or debit")
	H.remove_from_mob(item); qdel(item)
	canopy_ci_clear(site)
	// Concurrent separate items occupy the tile only once.
	item = new(H)
	var/obj/item/weapon/tent/second = new(other)
	joinery_ci_expect(H.put_in_active_hand(item) && other.put_in_active_hand(second), "competing unfolds use legal hands")
	spawn(0)
		second.attack_self(other)
	item.attack_self(H)
	sleep(1)
	joinery_ci_expect((QDELETED(item) ? 1 : 0) + (QDELETED(second) ? 1 : 0) == 1 && canopy_ci_count(site, /obj/structure/tent) == 1 && canopy_ci_count(site, /obj/roof/canopy) == 1, "concurrent unfolds consume exactly one item")
	if (!QDELETED(item)) H.remove_from_mob(item)
	if (!QDELETED(second)) other.remove_from_mob(second)
	qdel(item); qdel(second)
	canopy_ci_clear(site)
	// An unrelated roof arriving during folding survives with the original canopy.
	tent = new(site)
	spawn(1)
		new /obj/roof/wood(site)
	tent.fold_up(H)
	joinery_ci_expect(!QDELETED(tent) && !canopy_ci_count(site, /obj/item/weapon/tent) && canopy_ci_count(site, /obj/roof/wood) == 1 && canopy_ci_count(site, /obj/roof/canopy) == 1 && canopy_ci_area(site, AREA_INSIDE), "late independent roof refuses folding and retains covered area")
	joinery_ci_expect(!tent.fold_up(H) && !QDELETED(tent), "independent roof also refuses folding before the wait")
	canopy_ci_clear(site)
	// Legacy duplicate structures share the one existing canopy roof until last fold.
	tent = new(site)
	var/obj/structure/tent/legacy = new(site)
	tent.fold_up(H)
	joinery_ci_expect(canopy_ci_count(site, /obj/roof/canopy) == 1 && canopy_ci_area(site, AREA_INSIDE), "remaining legacy canopy retains its cover")
	legacy.fold_up(H)
	joinery_ci_expect(canopy_ci_count(site, /obj/item/weapon/tent) == 2 && !canopy_ci_count(site, /obj/roof/canopy) && canopy_ci_area(site, AREA_OUTSIDE), "last legacy canopy removes only its shared cover")
	canopy_ci_clear(site)
	// Neighbor state is recomputed after retirement rather than retaining stale seams.
	tent = new(site)
	legacy = new(neighbor)
	joinery_ci_expect(legacy.icon_state == "tent_w", "adjacent canopy uses existing west seam state")
	tent.fold_up(H)
	joinery_ci_expect(legacy.icon_state == "tent_o" && canopy_ci_count(neighbor, /obj/roof/canopy) == 1, "remaining canopy returns to the solo state and keeps its roof")
	canopy_ci_clear(site); canopy_ci_clear(neighbor)
	qdel(H); qdel(other)
