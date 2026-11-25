// Headless probe for the storage window's server side (code/modules/storage_window/storage_window.dm).
// Run: python3 tests/ecology_spawning/run_linux.py . tests/storage_window/probe.dm
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
/mob/living/human/storwin_probe/New()
	species = new /datum/species/human
	return
/mob/living/human/storwin_probe/update_icons()
	return
/mob/living/human/storwin_probe/var/storwin_window_ok = FALSE
/mob/living/human/storwin_probe/storage_window_possible()
	return storwin_window_ok

// A basket with a lock that never opens, standing in for the door thread's locks.
/obj/structure/storage_container/basket/storwin_locked/storage_access_allowed(mob/user)
	return FALSE

var/storwin_failures = 0
var/storwin_runtime_error = FALSE
/proc/storwin_check(condition, label)
	if (!condition)
		storwin_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	storwin_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"

/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		if (!GLOB.nanomanager)
			GLOB.nanomanager = new
		storwin_time_checks()
		storwin_window_checks()
		storwin_carried_move_checks()
		storwin_carried_hand_checks()
		storwin_search_checks()
		storwin_closet_checks()
		storwin_fire_checks()
		storwin_admin_checks()
		storwin_rack_checks()
		storwin_strip_checks()
		storwin_merge_checks()
	catch(var/exception/e)
		storwin_check(FALSE, "exception [e] [e.file]:[e.line] [e.desc]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = storwin_failures, "runtime_error" = storwin_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/storwin_item(turf/T, w_class, name)
	var/obj/item/I = new /obj/item(T)
	I.w_class = w_class
	I.name = name
	return I

/proc/storwin_time_checks()
	var/obj/item/I = storwin_item(null, ITEM_SIZE_NORMAL, "normal thing")
	storwin_check(storage_window_move_time(I, FALSE, FALSE, FALSE) == 9, "a normal thing takes 0.9 s between containers")
	storwin_check(storage_window_move_time(I, TRUE, FALSE, FALSE) == 5, "to or from hands, pockets and belt is about half")
	storwin_check(storage_window_move_time(I, FALSE, FALSE, TRUE) == 14, "out of a body's gear is half again as long")
	storwin_check(storage_window_move_time(I, FALSE, TRUE, TRUE) == 7, "the two multipliers multiply")
	I.w_class = ITEM_SIZE_TINY
	storwin_check(storage_window_move_time(I, TRUE, FALSE, FALSE) >= 2, "no move is shorter than 0.2 s")
	I.w_class = ITEM_SIZE_HUGE
	storwin_check(storage_window_move_time(I, FALSE, FALSE, FALSE) > storage_window_move_time(storwin_item(null, ITEM_SIZE_SMALL, "s"), FALSE, FALSE, FALSE), "bigger things take longer")
	qdel(I)

/proc/storwin_window_checks()
	var/turf/here = locate(5, 5, 1)
	var/mob/living/human/storwin_probe/H = new(here)
	storwin_check(!storage_window_open(H, null), "a character with no player keeps the old strip")

	var/obj/structure/storage_container/basket/B = new(locate(6, 5, 1))
	var/obj/item/weapon/storage/internal/IS = storage_window_structure_holder(B)
	storwin_check(istype(IS) && IS.loc == B, "a storage structure exposes its internal storage")
	var/obj/structure/storage_container/basket/far = new(locate(9, 9, 1))
	var/obj/structure/storage_container/basket/storwin_locked/L = new(locate(4, 5, 1))
	var/obj/item/weapon/storage/internal/LS = storage_window_structure_holder(L)

	var/datum/storage_window/W = new(H)
	storwin_check(W.lists_holder(IS), "a basket next to you is listed")
	storwin_check(!W.lists_holder(storage_window_structure_holder(far)), "a basket across the room is not")
	storwin_check(W.lists_holder(LS) && !storage_window_access(H, LS), "a locked basket is listed but its lock hook refuses")

	var/obj/item/hidden = storwin_item(null, ITEM_SIZE_SMALL, "hidden thing")
	LS.handle_item_insertion(hidden, TRUE)
	storwin_check(hidden.loc == LS, "the locked basket holds something")
	storwin_check(!W.reachable(hidden), "nothing can be taken out of a locked basket")
	var/list/data = W.build_data()
	var/locked_shown = FALSE
	var/hidden_named = FALSE
	for (var/list/G in data["near"])
		if (G["locked"])
			locked_shown = TRUE
			if (length(G["items"]) || !isnull(G["used"]))
				hidden_named = TRUE
	storwin_check(locked_shown && !hidden_named, "a locked container shows neither its things nor its fill")

	// Floor to basket, then basket to floor.
	var/obj/item/stone = storwin_item(locate(5, 6, 1), ITEM_SIZE_SMALL, "stone")
	storwin_check(W.reachable(stone), "a thing on the next tile is in reach")
	storwin_check(W.perform_move(stone, STORAGE_WINDOW_KIND_NEAR, IS) && stone.loc == IS, "a thing on the floor goes into the basket")
	storwin_check(W.perform_move(stone, STORAGE_WINDOW_KIND_FLOOR, null) && stone.loc == here, "and back out onto the floor under you")
	var/obj/item/log = storwin_item(here, ITEM_SIZE_LARGE, "log")
	storwin_check(!W.perform_move(log, STORAGE_WINDOW_KIND_NEAR, IS) && log.loc == here, "a basket refuses a large thing and it stays put")
	storwin_check(!W.perform_move(stone, STORAGE_WINDOW_KIND_NEAR, LS) && stone.loc == here, "nothing goes into a locked basket")

	// The queue: one move runs, the rest wait, and none is queued twice.
	var/obj/item/flint = storwin_item(here, ITEM_SIZE_TINY, "flint")
	storwin_check(W.enqueue(stone, STORAGE_WINDOW_KIND_NEAR, IS, FALSE), "a move is queued")
	storwin_check(W.current && W.current["item"] == stone, "the first move starts at once")
	storwin_check(!W.enqueue(stone, STORAGE_WINDOW_KIND_NEAR, IS, FALSE), "the same thing is not queued twice")
	storwin_check(W.enqueue(flint, STORAGE_WINDOW_KIND_NEAR, IS, FALSE) && W.queue.len == 1, "the next move waits")
	data = W.build_data()
	storwin_check(length(data["queue"]) == 2, "the window lists both moves")
	W.finish_move()
	storwin_check(stone.loc == IS, "the first move lands when its time is up")
	storwin_check(W.current && W.current["item"] == flint, "and the next one starts")
	W.start_turf = locate(5, 4, 1) // as if the character had stepped off
	W.finish_move()
	storwin_check(flint.loc == here && !W.current && !W.queue.len, "walking away cancels the moves")

	// Take All from the basket goes to the character; nothing is dropped when there is no room.
	var/list/target = W.auto_target(stone)
	storwin_check(target && target[1] == STORAGE_WINDOW_KIND_HANDS, "with no bag on, Take All goes to your hands")
	storwin_check(W.perform_move(stone, "auto", null) && (stone == H.l_hand || stone == H.r_hand), "a taken thing ends up in a hand")
	storwin_check(storage_window_in_group(stone, list(STORAGE_WINDOW_KIND_HANDS, H), H), "the hands group knows what is held")
	W.cancel_all(FALSE)
	qdel(W)

/proc/storwin_carried_move_checks()
	var/turf/start = locate(4, 1, 1)
	var/turf/next_tile = locate(5, 1, 1)
	var/mob/living/human/storwin_probe/H = new(start)
	var/obj/item/weapon/storage/backpack/source = new(H)
	var/obj/item/weapon/storage/backpack/target = new(H)
	H.l_hand = source
	H.r_hand = target
	var/datum/storage_window/W = new(H)
	storwin_check(W.lists_holder(source) && W.lists_holder(target), "both held bags are available in the window")
	var/obj/item/I = storwin_item(source, ITEM_SIZE_TINY, "held-bag item")
	storwin_check(W.enqueue(I, STORAGE_WINDOW_KIND_WORN, target, FALSE) && W.current && W.current["time"] > 0, "carried transfer still has a timer")
	// Set the real position without invoking the fixture's unstarted turf processors.
	H.loc = next_tile
	W.finish_move()
	storwin_check(I.loc == target && !W.current, "carried transfer completes after walking to the next tile")
	storwin_check(W.enqueue(I, STORAGE_WINDOW_KIND_WORN, source, FALSE), "the return transfer starts")
	source.loc = next_tile
	H.l_hand = null
	H.loc = start
	W.finish_move()
	storwin_check(I.loc == target, "dropping the destination cancels the transfer even when it is still nearby")
	source.loc = H
	H.l_hand = source
	storwin_check(W.enqueue(I, STORAGE_WINDOW_KIND_WORN, source, FALSE), "another transfer starts")
	target.loc = start
	H.r_hand = null
	H.loc = next_tile
	W.finish_move()
	storwin_check(I.loc == target, "dropping the source cancels the transfer even when it is still nearby")
	target.loc = H
	H.r_hand = target
	storwin_check(W.enqueue(I, STORAGE_WINDOW_KIND_WORN, source, FALSE), "the final transfer starts")
	H.stat = UNCONSCIOUS
	W.finish_move()
	storwin_check(I.loc == target && !W.current && !W.queue.len, "incapacitation cancels even a carried transfer")
	qdel(W)

/obj/item/organ/external/storwin_hand/New()
	return

/obj/item/organ/external/storwin_hand/is_usable()
	return TRUE

/proc/storwin_carried_hand_checks()
	var/turf/start = locate(1, 1, 1)
	var/mob/living/human/storwin_probe/H = new(start)
	H.organs_by_name = list("l_hand" = new /obj/item/organ/external/storwin_hand, "r_hand" = new /obj/item/organ/external/storwin_hand)
	var/obj/item/weapon/storage/backpack/source = new(H)
	H.back = source
	var/datum/storage_window/W = new(H)
	var/obj/item/I = storwin_item(source, ITEM_SIZE_TINY, "item for right hand")
	H.hand = 0
	storwin_check(W.enqueue(I, STORAGE_WINDOW_KIND_HANDS, H, TRUE) && W.current["hand_slot"] == slot_r_hand, "carried move picks the initially free active hand")
	H.hand = 1
	W.finish_move()
	storwin_check(H.r_hand == I && !H.l_hand && I.loc == H, "switching active hands does not redirect or cancel the move")
	var/obj/item/J = storwin_item(source, ITEM_SIZE_TINY, "item for left hand")
	storwin_check(W.enqueue(J, STORAGE_WINDOW_KIND_HANDS, H, TRUE) && W.current["hand_slot"] == slot_l_hand, "second move picks the left hand")
	H.r_hand = null
	I.loc = source
	H.l_hand = storwin_item(H, ITEM_SIZE_TINY, "other held item")
	H.hand = 0
	W.finish_move()
	storwin_check(J.loc == source && !H.r_hand, "a filled destination leaves the item in its bag instead of using the other hand")
	qdel(W)

/proc/storwin_search_checks()
	var/turf/here = locate(8, 8, 1)
	var/mob/living/human/storwin_probe/H = new(here)
	var/mob/living/human/storwin_probe/other = new(locate(8, 9, 1))
	var/obj/structure/storage_container/basket/B = new(locate(9, 8, 1))
	var/obj/item/weapon/storage/internal/IS = storage_window_structure_holder(B)
	var/obj/item/knife = storwin_item(null, ITEM_SIZE_SMALL, "knife")
	var/obj/item/axe = storwin_item(null, ITEM_SIZE_NORMAL, "axe")
	usr = other
	IS.handle_item_insertion(knife, TRUE)
	IS.handle_item_insertion(axe, TRUE)
	usr = null
	storwin_check(storage_item_seen(knife, other) && !storage_item_seen(knife, H), "only the one who put a thing in knows it")
	var/datum/storage_window/W = new(H)
	var/list/data = W.build_data()
	var/list/basket
	for (var/list/G in data["near"])
		if (G["id"] == "near:[ref(IS)]")
			basket = G
	storwin_check(basket && !length(basket["items"]) && length(basket["unseen"]) == 2 && !basket["can_dump"], "someone else's basket shows two unseen things and can't be dumped")
	storwin_check(basket && basket["total"] == 2, "item storage still includes a total count without naming unseen items")
	storwin_check(!W.served_items.len || !(knife in W.served_items_values()), "unseen things are never named to the window")
	storwin_check(storage_search_time(knife) == 7 && storage_search_time(axe) == 10, "looking takes 0.7 s for a small thing, 1.0 s for a normal one")
	storwin_check(W.begin_search(IS) && W.search_item == knife, "searching starts with the top thing")
	W.finish_look()
	storwin_check(storage_item_seen(knife, H) && W.search_item == axe, "the knife is seen and the axe is next")
	data = W.build_data()
	for (var/list/G in data["near"])
		if (G["id"] == "near:[ref(IS)]")
			basket = G
	storwin_check(length(basket["items"]) == 1 && basket["search"], "the seen knife is listed while the axe is looked at")
	W.search_turf = locate(8, 7, 1) // as if the character had stepped off
	W.finish_look()
	storwin_check(!W.search_holder && !storage_item_seen(axe, H), "walking away stops the search")
	W.begin_search(IS)
	W.finish_look()
	storwin_check(storage_item_seen(axe, H) && !W.search_holder, "searching again finishes the basket")
	storwin_check(!W.begin_search(IS), "a searched container has nothing left to search")
	usr = other
	IS.remove_from_storage(knife, here)
	IS.handle_item_insertion(knife, TRUE)
	usr = null
	storwin_check(!storage_item_seen(knife, H), "a thing someone else puts back is unknown again")
	other.civilization = "Dawnward"
	H.civilization = "Dawnward"
	usr = other
	IS.remove_from_storage(knife, here)
	IS.handle_item_insertion(knife, TRUE)
	usr = null
	storwin_check(storage_item_seen(knife, H), "a thing your own faction put in needs no searching")
	H.civilization = "Ash Company"
	storwin_check(!storage_item_seen(knife, H), "a thing another faction put in still does")
	H.civilization = "none"
	other.civilization = "none"
	storwin_check(!storage_item_seen(knife, H), "people in no faction don't count as one faction")
	storwin_check(W.knows(knife, STORAGE_WINDOW_KIND_WORN) && W.knows(knife, STORAGE_WINDOW_KIND_FLOOR), "your own gear and the floor are always known")
	qdel(W)

/datum/storage_window/proc/served_items_values()
	. = list()
	for (var/id in served_items)
		. += served_items[id]

/proc/storwin_closet_checks()
	var/turf/here = locate(2, 10, 1)
	var/mob/living/human/storwin_probe/H = new(here)
	var/obj/structure/closet/crate/C = new(locate(3, 10, 1))
	C.storagecap = 2
	var/obj/item/packed = storwin_item(C, ITEM_SIZE_SMALL, "packed cloth")
	storwin_check(!storage_window_structure_holder(C), "a shut crate lists nothing")
	C.keep_items = TRUE
	C.open()
	C.keep_items = FALSE
	storwin_check(C.opened && packed.loc == C, "opened through the window, the crate keeps its things inside")
	storwin_check(storage_window_structure_holder(C) == C, "an open crate is its own holder")
	var/datum/storage_window/W = new(H)
	storwin_check(W.lists_holder(C) && storage_window_access(H, C), "the open crate next to you is listed and open to you")
	storwin_check(!W.knows(packed, "near"), "what was packed before you came must be searched")
	var/obj/structure/closet/cupboard = new(locate(2, 11, 1))
	cupboard.opened = TRUE
	var/obj/item/unseen = storwin_item(cupboard, ITEM_SIZE_SMALL, "unseen parcel")
	var/obj/item/weapon/storage/backpack/bag = new(locate(2, 9, 1))
	storwin_item(bag, ITEM_SIZE_TINY, "outside compartment")
	var/obj/false_bottom/compartment = new(bag)
	var/obj/item/private = storwin_item(compartment, ITEM_SIZE_TINY, "inside compartment")
	var/list/data = W.build_data()
	var/list/crate
	var/list/closet
	var/list/backpack
	for (var/list/G in data["near"])
		if (G["id"] == "near:[ref(C)]")
			crate = G
		else if (G["id"] == "near:[ref(cupboard)]")
			closet = G
		else if (G["id"] == "near:[ref(bag)]")
			backpack = G
	storwin_check(crate && !length(crate["items"]) && length(crate["unseen"]) == 1 && isnull(crate["total"]) && !(packed in W.served_items_values()), "an unsearched crate shows no item name or extra item-storage total")
	storwin_check(closet && !length(closet["items"]) && length(closet["unseen"]) == 1 && isnull(closet["total"]) && !(unseen in W.served_items_values()), "an open closet shows only known items and no item-storage total")
	storwin_check(backpack && backpack["total"] == 1 && !(private in W.served_items_values()), "item-storage totals still exclude false bottoms and their contents")
	storwin_check(W.begin_search(C), "searching the crate starts")
	W.finish_look()
	storwin_check(W.knows(packed, "near") && W.reachable(packed), "once seen it is in reach")
	var/obj/item/stone = storwin_item(here, ITEM_SIZE_SMALL, "stone")
	storwin_check(W.perform_move(stone, "near", C) && stone.loc == C, "a thing goes into the crate")
	var/obj/item/third = storwin_item(here, ITEM_SIZE_TINY, "flint")
	storwin_check(!W.perform_move(third, "near", C) && third.loc == here, "a crate refuses more things than it takes")
	storwin_check(W.perform_move(packed, STORAGE_WINDOW_KIND_FLOOR, null) && packed.loc == here, "and gives them back to the floor")
	data = W.build_data()
	crate = null
	for (var/list/G in data["near"])
		if (G["id"] == "near:[ref(C)]")
			crate = G
	storwin_check(crate && crate["unit"] == "things" && crate["slots"] == 2 && crate["used"] == 1 && length(crate["items"]) == 1, "the window counts the crate in things and lists the known item")
	C.locked = TRUE
	storwin_check(!storage_window_access(H, C) && !W.reachable(stone), "a locked crate keeps its things")
	C.locked = FALSE
	C.close()
	storwin_check(!C.opened && stone.loc == C, "closing the lid for someone without the window still works")
	C.open()
	storwin_check(stone.loc == get_turf(C), "and opening it the old way tips things out as before")
	var/obj/structure/closet/crate/dumpster/D = new(locate(1, 10, 1))
	D.opened = TRUE
	storwin_check(!storage_window_structure_holder(D), "a dumpster keeps its own rummaging")
	qdel(W)

// A wooden or woven store that burns away takes its flammable things with it.
/proc/storwin_fire_checks()
	var/obj/structure/storage_container/basket/B = new(locate(5, 12, 1))
	var/obj/item/cloth = storwin_item(B.storage, ITEM_SIZE_SMALL, "burning cloth")
	cloth.flammable = TRUE
	var/obj/item/blade = storwin_item(B.storage, ITEM_SIZE_SMALL, "iron blade")
	blade.flammable = FALSE
	for (var/i = 1, i <= 200 && !QDELETED(B), i++)
		B.fire_act(1000)
	storwin_check(QDELETED(B), "a basket in a fire burns away")
	storwin_check(QDELETED(cloth), "the cloth in it burns too")
	storwin_check(!QDELETED(blade) && blade.loc == locate(5, 12, 1), "the iron blade drops out whole")
	var/obj/structure/storage_container/storage_jar/J = new(locate(6, 12, 1))
	var/obj/item/grain = storwin_item(J.storage, ITEM_SIZE_SMALL, "grain")
	for (var/i = 1, i <= 50, i++)
		J.fire_act(1000)
	storwin_check(!QDELETED(J) && grain.loc == J.storage, "a clay jar keeps its things through a fire")
	var/obj/structure/closet/crate/wood/W = new(locate(7, 12, 1))
	W.flammable = TRUE
	var/obj/item/rag = storwin_item(W, ITEM_SIZE_SMALL, "rag")
	rag.flammable = TRUE
	for (var/i = 1, i <= 200 && !QDELETED(W), i++)
		W.fire_act(1000)
	storwin_check(QDELETED(W) && QDELETED(rag), "a burning crate takes its rag with it")

// Admin > View Storage lists nested things without marking them seen.
/proc/storwin_admin_checks()
	var/obj/structure/storage_container/basket/B = new(locate(5, 14, 1))
	var/obj/item/weapon/storage/box/inner = new(B.storage)
	for (var/obj/item/O in inner.contents)
		qdel(O)
	var/obj/item/coin = storwin_item(inner, ITEM_SIZE_TINY, "hidden coin")
	coin.storage_seen_by = list("someone")
	storwin_item(B.storage, ITEM_SIZE_SMALL, "loose cloth")
	var/list/lines = list()
	var/count = storage_admin_list(B, lines, 0)
	storwin_check(count == 3 && lines.len == 3, "the admin view lists the box, the coin inside it and the cloth ([count])")
	storwin_check(findtext(jointext(lines, ""), "someone"), "it shows who has searched a thing")
	storwin_check(coin.storage_seen_by.len == 1, "looking marks nothing as seen")

// Racks hold one kind of thing each and show what hangs on them.
/proc/storwin_rack_checks()
	var/obj/structure/storage_container/rack/peg_post/P = new(locate(10, 12, 1))
	var/obj/item/clothing/hat = new(locate(10, 12, 1))
	hat.icon_state = "hat"
	var/obj/item/pebble = storwin_item(locate(10, 12, 1), ITEM_SIZE_SMALL, "pebble")
	storwin_check(P.storage.can_be_inserted(hat, TRUE), "a peg post takes a hat")
	storwin_check(!P.storage.can_be_inserted(pebble, TRUE), "but not a pebble")
	P.storage.handle_item_insertion(hat, TRUE)
	P.update_icon()
	storwin_check(hat.loc == P.storage && P.overlays.len == 1, "the hat hangs on it and shows ([P.overlays.len])")
	storwin_check(home_is_container(P), "a rack counts as a container for a tidy room")
	var/obj/structure/storage_container/rack/tool_rack/T = new(locate(11, 12, 1))
	var/obj/item/weapon/material/hatchet/axe = new(locate(11, 12, 1))
	storwin_check(T.storage.can_be_inserted(axe, TRUE), "a tool rack takes a hatchet")
	storwin_check(!T.storage.can_be_inserted(hat, TRUE), "but not a hat")
	var/obj/structure/storage_container/rack/weapon_rack/W = new(locate(12, 12, 1))
	var/obj/item/weapon/material/spear/spear = new(locate(12, 12, 1))
	storwin_check(W.storage.can_be_inserted(spear, TRUE), "a weapon rack takes a spear")
	storwin_check(!W.storage.can_be_inserted(pebble, TRUE), "but not a pebble")
	var/obj/structure/storage_container/rack/clothes_rail/C = new(locate(13, 12, 1))
	storwin_check(!C.storage.can_be_inserted(axe, TRUE), "a clothes rail refuses a hatchet")
	P.empty_out(locate(10, 12, 1))
	storwin_check(hat.loc == locate(10, 12, 1) && !P.overlays.len, "emptied, the peg post is bare again")

// The classic strip (the default) keeps the window's timing and searching.
/proc/storwin_strip_checks()
	var/datum/client_preference/storage_window/pref = new
	storwin_check(pref.key == "STORAGE_WINDOW" && !pref.enabled_by_default, "the storage window is opt-in; the strip is the default")
	var/turf/here = locate(2, 2, 1)
	var/mob/living/human/storwin_probe/H = new(here)
	var/mob/living/human/storwin_probe/other = new(locate(2, 3, 1))
	storwin_check(!H.storage_window_wanted(), "with no choice made, bags open in the strip")
	var/obj/item/weapon/storage/internal/shown = storage_window_structure_holder(new /obj/structure/storage_container/basket(locate(1, 2, 1)))
	H.s_active = shown
	storwin_check(!storage_window_open(H, shown), "a character with no player keeps the strip it clicks")
	H.s_active = null
	storwin_click_checks(H, shown)
	var/obj/structure/storage_container/basket/B = new(locate(3, 2, 1))
	var/obj/item/weapon/storage/internal/IS = storage_window_structure_holder(B)
	var/obj/item/knife = storwin_item(null, ITEM_SIZE_SMALL, "knife")
	var/obj/item/axe = storwin_item(null, ITEM_SIZE_NORMAL, "axe")
	usr = other
	IS.handle_item_insertion(knife, TRUE)
	IS.handle_item_insertion(axe, TRUE)
	usr = null
	var/list/unseen = storage_strip_unseen(H, IS)
	storwin_check(unseen.len == 2, "someone else's basket shows the strip two unseen things")
	storwin_check(!length(storage_strip_unseen(other, IS)), "the one who filled it sees everything")
	storwin_check(storage_strip_take_time(H, knife) == storage_window_move_time(knife, FALSE, TRUE, FALSE), "taking out through the strip costs the window's move time to a hand")
	var/datum/strip_search/SS = new(H)
	H.strip_search = SS
	H.s_active = IS
	SS.begin(IS)
	storwin_check(SS.looking == knife && SS.timer, "the strip searches top first")
	SS.finish_look()
	storwin_check(storage_item_seen(knife, H), "a finished look reveals the thing")
	storwin_check(storage_strip_unseen(H, IS).len == 1, "and only the axe stays hidden")
	SS.begin(IS)
	SS.start_turf = locate(5, 2, 1) // as if the character had stepped off
	SS.finish_look()
	storwin_check(!storage_item_seen(axe, H) && !SS.holder, "walking away stops the strip's search")
	H.s_active = null
	qdel(SS)

	var/obj/structure/closet/crate/C = new(locate(6, 2, 1))
	var/obj/item/cloth = storwin_item(C, ITEM_SIZE_SMALL, "cloth")
	storwin_check(storage_strip_closet_search_time(C, H) == storage_search_time(cloth), "a shut crate's unseen things cost their search time to open")
	storage_mark_seen(cloth, H)
	storwin_check(storage_strip_closet_search_time(C, H) == 0, "a searched crate opens at once")

/obj/item/stack/storwin_bones
	name = "bones"
	max_amount = 10
	w_class = ITEM_SIZE_SMALL

// A stack put into a bag tops up the same stack already inside.
/proc/storwin_merge_checks()
	var/turf/here = locate(10, 2, 1)
	var/mob/living/human/storwin_probe/H = new(here)
	var/mob/living/human/storwin_probe/other = new(locate(10, 3, 1))
	var/obj/item/weapon/storage/backpack/bag = new(here)
	bag.storage_slots = 1
	bag.max_storage_space = 100
	var/obj/item/stack/storwin_bones/inside = new(here, 4)
	usr = H
	storwin_check(bag.handle_item_insertion(inside, TRUE) && inside.loc == bag, "a first stack of bones goes in")
	// Examine says how full a bag is (storage_fullness.dm).
	storwin_check(bag.fullness() == 1 && storage_fullness_text(1) == "It is full.", "a bag with every slot taken reads as full")
	bag.storage_slots = 4
	storwin_check(bag.fullness() == 0.25 && storage_fullness_text(0.25) == "It has plenty of room left." && storage_fullness_text(0) == "It is empty." && storage_fullness_text(0.9) == "It is nearly full.", "fullness follows the slots used")
	bag.storage_slots = 1
	var/obj/item/stack/storwin_bones/more = new(here, 3)
	storwin_check(bag.can_be_inserted(more, TRUE), "a full bag still takes bones that fit onto its stack")
	storwin_check(bag.handle_item_insertion(more, TRUE) && inside.amount == 7 && QDELETED(more), "the new bones join the stack inside")
	var/obj/item/stack/storwin_bones/big = new(here, 6)
	storwin_check(!bag.can_be_inserted(big, TRUE) && bag.stack_merge_room(big, H) == 3, "a stack too big to join whole is refused by a full bag, but 3 would fit")
	bag.merge_stack_in(big, H, TRUE)
	storwin_check(inside.amount == 10 && big.amount == 3 && big.loc == here, "topping up fills the stack inside and leaves the rest out")
	var/obj/item/stack/storwin_bones/fresh = new(here, 2)
	storwin_check(!bag.stack_merge_room(fresh, H), "a full stack takes no more")
	usr = null
	// Someone else's unsearched bag: no merging into what you haven't seen.
	var/obj/item/weapon/storage/backpack/theirs = new(here)
	var/obj/item/stack/storwin_bones/hidden = new(here, 1)
	usr = other
	theirs.handle_item_insertion(hidden, TRUE)
	usr = H
	var/obj/item/stack/storwin_bones/mine = new(here, 1)
	storwin_check(!theirs.stack_merge_room(mine, H), "bones never join a stack you haven't seen")
	storage_mark_seen(hidden, H)
	storwin_check(theirs.stack_merge_room(mine, H) == 9, "once seen, they can")
	usr = null

// One click opens the strip, the next click closes it, a double-click opens the window.
/proc/storwin_click_checks(mob/living/human/storwin_probe/H, obj/item/weapon/storage/S)
	H.storwin_window_ok = TRUE
	H.storage_click_last = null
	storwin_check(H.storage_click(S) == STORAGE_CLICK_OPEN, "a click on a shut bag opens its strip")
	H.s_active = S
	H.storage_click_time = world.time - STORAGE_DOUBLE_CLICK_TIME - 1
	storwin_check(H.storage_click(S) == STORAGE_CLICK_CLOSE, "a later click on a showing strip closes it")
	H.s_active = null
	storwin_check(H.storage_click(S) == STORAGE_CLICK_WINDOW, "a quick second click opens the window")
	storwin_check(H.storage_click(S) == STORAGE_CLICK_IGNORE, "the rest of that double-click does nothing more")
	H.storage_click_time = world.time - STORAGE_DOUBLE_CLICK_TIME - 1
	storwin_check(H.storage_click(S) == STORAGE_CLICK_OPEN, "after the double-click time a click opens the strip again")
	var/obj/item/weapon/storage/internal/other = new
	storwin_check(H.storage_click(other) == STORAGE_CLICK_OPEN, "a quick click on another bag is a new click, not a double-click")
	H.storwin_window_ok = FALSE
	H.storage_click_last = null
	H.storage_click(S)
	storwin_check(H.storage_click(S) == STORAGE_CLICK_IGNORE, "with no window, a double-click leaves the strip as the first click left it")
	H.storage_click_last = null
	storwin_check(hascall(other, "open_storage_window"), "every bag has the Open Storage Window right-click option")
	storwin_check(hascall(H, "open_storage_window_here"), "the window opens with no bag, from the IC tab")
	qdel(other)
