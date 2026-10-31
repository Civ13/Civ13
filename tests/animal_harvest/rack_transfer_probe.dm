// Human startup/connection adapters only. Inventory, slot updates, movement,
// Crossed/merge, rack admission and drying below use production code.
/mob/living/human/rack_transfer_tester/New()
	species = new /datum/species/human
	body_build = new /datum/body_build
	defaultHUD = "1713Style"
	if (!HUDdatums[defaultHUD])
		makeDatumRefLists()
	create_HUDinventory()

/mob/living/human/rack_transfer_tester/hide_worker_connected()
	return TRUE

// Explicit historical wrapper adapter: reproduce #3286's discarded return
// without requiring the production human to retain the defect fixed by #3322.
/mob/living/human/rack_transfer_tester/legacy_return/drop_from_inventory(var/obj/item/W, var/atom/Target = null)
	..()

// Failure injection at the movement seam; not a claim about the live trigger.
/obj/item/stack/material/wethide/rack_blocked/forceMove(atom/destination, special_event)
	if (istype(destination, /obj/structure/converter/tanning))
		return FALSE
	return ..()

/obj/structure/converter/tanning/rack_redirect/Entered(atom/movable/AM, atom/old_loc, special_event)
	AM.forceMove(loc)
	return CANCEL_MOVE_EVENT

/proc/tanning_rack_transfer_regressions(turf/site)
	var/mob/living/human/rack_transfer_tester/worker = new(site)
	var/turf/rack_site = locate(4,3,1)
	// Production human now forwards success; physical floor ownership is unchanged.
	var/obj/structure/converter/tanning/clear_rack = new(rack_site)
	var/obj/item/stack/material/wethide/clear_batch = new(worker, 3, FALSE)
	worker.r_hand = clear_batch
	var/drop_result = worker.drop_from_inventory(clear_batch)
	harvest_assert(drop_result && clear_batch.loc == site && !worker.item_is_in_hands(clear_batch), "Human drop did not report successful floor transfer")
	harvest_assert(clear_batch.forceMove(clear_rack) && clear_batch.loc == clear_rack, "Storage transfer after human drop failed")
	qdel(clear_batch)
	qdel(clear_rack)
	// Retain the old false-result/real-drop causal control under its named adapter.
	var/mob/living/human/rack_transfer_tester/legacy_return/legacy_worker = new(site)
	clear_batch = new(legacy_worker, 3, FALSE)
	legacy_worker.r_hand = clear_batch
	drop_result = legacy_worker.drop_from_inventory(clear_batch)
	harvest_assert(!drop_result && clear_batch.loc == site && !legacy_worker.item_is_in_hands(clear_batch), "Legacy wrapper control did not reproduce false result after floor drop")
	qdel(clear_batch)
	qdel(legacy_worker)
	// Source control: old floor staging changes the held batch via real Crossed().
	var/obj/item/stack/material/wethide/floor_hide = new(site, 2, FALSE)
	var/obj/item/stack/material/wethide/held = new(worker, 3, FALSE)
	worker.r_hand = held
	worker.drop_from_inventory(held)
	harvest_assert(held.amount == 5 && QDELETED(floor_hide), "Floor-drop control did not reproduce Crossed batch contamination")
	qdel(held)
	// Adjacent and same-tile racks, both hands, occupied/full floor stacks.
	for (var/same_tile in list(FALSE, TRUE))
		for (var/left_hand in list(FALSE, TRUE))
			for (var/floor_count in list(2, 49, 50))
				var/obj/structure/converter/tanning/rack = new(same_tile ? site : rack_site)
				floor_hide = new(site, floor_count, FALSE)
				held = new(worker, 3, FALSE)
				if (left_hand)
					harvest_assert(worker.put_in_l_hand(held), "Production left-hand rack pickup failed")
				else
					harvest_assert(worker.put_in_r_hand(held), "Production right-hand rack pickup failed")
				harvest_assert(held.screen_loc && held.plane == HUD_PLANE, "Rack input was not in production HUD item state")
				harvest_assert(held.resolve_attackby(rack, worker), "Rack click did not resolve")
				harvest_assert(held.loc == rack && held.amount == 3 && rack.filled && !worker.item_is_in_hands(held), "Rack did not own exact held batch")
				harvest_assert(!held.screen_loc && held.plane == GAME_PLANE, "Rack transfer retained stale HUD item state")
				if (worker.client)
					harvest_assert(!(held in worker.client.screen), "Rack transfer retained actual client screen membership")
				harvest_assert(!QDELETED(floor_hide) && floor_hide.loc == site && floor_hide.amount == floor_count, "Rack touched unrelated floor hides")
				harvest_assert(rack.finish_hide_drying(held, 3, rack.drying_epoch, get_turf(rack)) && tanning_amount(rack, /obj/item/stack/material/dryhide) == 3, "Transferred batch lost drying yield")
				qdel(rack)
				harvest_clear(rack_site)
				harvest_clear(site)
	// An actual storage bag is not a held wet-hide stack; never empty it implicitly.
	var/obj/item/weapon/storage/backpack/bag = new(worker)
	worker.r_hand = bag
	held = new(bag, 3, FALSE)
	var/obj/structure/converter/tanning/rack = new(rack_site)
	harvest_assert(bag.resolve_attackby(rack, worker), "Bag/rack click did not resolve")
	harvest_assert(bag.loc == worker && held.loc == bag && held.amount == 3 && !rack.contents.len, "Rack silently unpacked/dropped storage contents")
	qdel(bag)
	// Old sequence loses inventory ownership before destination rejection.
	var/obj/item/stack/material/wethide/rack_blocked/blocked = new(worker, 4, FALSE)
	worker.r_hand = blocked
	worker.drop_from_inventory(blocked)
	harvest_assert(!blocked.forceMove(rack) && blocked.loc == site, "Legacy rejected-transfer control did not reproduce floor stranding")
	blocked.forceMove(worker)
	worker.r_hand = blocked
	blocked.resolve_attackby(rack, worker)
	harvest_assert(blocked.loc == worker && worker.r_hand == blocked && blocked.amount == 4 && !rack.contents.len && !rack.filled, "Rejected rack transfer did not retain held ownership")
	qdel(blocked)
	// A redirecting Entered callback must roll back the actual location, not trust TRUE.
	var/obj/structure/converter/tanning/rack_redirect/redirect = new(rack_site)
	held = new(worker, 5, FALSE)
	worker.r_hand = held
	held.resolve_attackby(redirect, worker)
	harvest_assert(held.loc == worker && worker.r_hand == held && held.amount == 5 && !redirect.contents.len && !redirect.filled, "Redirected transfer did not roll back safely")
	qdel(held)
	qdel(redirect)
	qdel(rack)
	qdel(worker)
	harvest_clear(site)
	harvest_clear(rack_site)
	world.log << "PASS: production human rack transfer, floor-merge control, storage rejection and denied/redirected move recovery"
