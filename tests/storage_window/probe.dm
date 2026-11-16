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
		storwin_search_checks()
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
	storwin_check(W.knows(knife, STORAGE_WINDOW_KIND_WORN) && W.knows(knife, STORAGE_WINDOW_KIND_FLOOR), "your own gear and the floor are always known")
	qdel(W)

/datum/storage_window/proc/served_items_values()
	. = list()
	for (var/id in served_items)
		. += served_items[id]
