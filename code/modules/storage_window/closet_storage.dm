// Crates, chests, closets, cabinets and fridges in the storage window.
//
// Their things stay in the closet's own contents, as before, so freight, region
// travel, safehouses and every other system that reads closet contents keeps
// working. What changes is how a player with the storage window uses them:
// opening the lid no longer tips everything onto the floor, closing it no longer
// sweeps the tile, and the window lists what is inside while the lid is open.
// Players without the window (agent characters, the old strip by choice) keep
// the old lid behaviour. Gather sweeps loose things on the tile in as timed
// moves; Dump Out tips them out. Mobs go in and out the old way.

/obj/structure/closet
	// FALSE for closets that work some other way (mailboxes, coffins, strongboxes...).
	var/item_window = TRUE
	// Set while a storage-window player opens or closes the lid.
	var/tmp/keep_items = FALSE

/obj/structure/closet/persistence_runtime_var(key)
	return key == "keep_items" || ..()

/obj/structure/closet/crate/wall_mailbox
	item_window = FALSE
/obj/structure/closet/crate/money_changer
	item_window = FALSE
/obj/structure/closet/crate/faction_strongbox
	item_window = FALSE
/obj/structure/closet/crate/sandbags
	item_window = FALSE
/obj/structure/closet/crate/dumpster
	item_window = FALSE
/obj/structure/closet/body_bag
	item_window = FALSE
/obj/structure/closet/coffin
	item_window = FALSE
/obj/structure/closet/old_coffin
	item_window = FALSE
/obj/structure/closet/hideout
	item_window = FALSE
/obj/structure/closet/cabinet/extinguisher_cabinet
	item_window = FALSE

// dump_contents() for a window opening: people and other objects come out, things stay.
/proc/closet_release_all_but_items(obj/structure/closet/C)
	for (var/obj/O in C)
		if (!istype(O, /obj/item))
			O.forceMove(C.loc)
	for (var/mob/M in C)
		M.forceMove(C.loc)
		if (M.client)
			M.client.eye = M.client.mob
			M.client.perspective = MOB_PERSPECTIVE

/proc/closet_window_user(obj/structure/closet/C, mob/user)
	var/mob/living/human/H = user
	return istype(C) && C.item_window && istype(H) && H.storage_window_wanted()

// Who may reach into it now: the lid is open, it isn't welded, no lock bars the way.
/proc/closet_window_access(mob/user, obj/structure/closet/C)
	if (!C.opened || C.welded || C.locked)
		return FALSE
	if (C.fitted_lock && !lock_hand_access(C, user))
		return FALSE
	return TRUE

// Lid toggling for a window player. TRUE when handled here.
/proc/closet_window_toggle(obj/structure/closet/C, mob/user)
	if (!closet_window_user(C, user))
		return FALSE
	C.keep_items = TRUE
	if (C.opened)
		C.toggle(user)
		C.keep_items = FALSE
		return TRUE
	C.toggle(user)
	C.keep_items = FALSE
	if (C.opened)
		closet_window_show(user, C)
	return TRUE

/proc/closet_window_show(mob/living/human/H, obj/structure/closet/C)
	var/datum/storage_window/W = H.storage_window
	if (!W)
		W = new /datum/storage_window(H)
		H.storage_window = W
	if (H.s_active)
		H.s_active.close(H)
	W.focus = C
	W.focus_seq++
	W.begin_search(C)
	W.ui_interact(H)

// Room for one more: crates count things (storagecap), closets count size units.
/proc/closet_has_room(obj/structure/closet/C, obj/item/I, mob/user, quiet = FALSE)
	if (!istype(I) || I.anchored || istype(I, /obj/item/weapon/grab))
		return FALSE
	var/full = FALSE
	if (istype(C, /obj/structure/closet/crate))
		var/obj/structure/closet/crate/CR = C
		var/count = 0
		for (var/obj/item/other in C.contents)
			count++
		full = count >= CR.storagecap
	else
		var/units = 0
		for (var/obj/item/other in C.contents)
			units += ceil(other.w_class / 2)
		full = units + ceil(I.w_class / 2) > C.storage_capacity
	if (full && !quiet && user)
		to_chat(user, SPAN_NOTICE("\The [C] is full."))
	return !full

/proc/closet_item_count(obj/structure/closet/C)
	. = 0
	for (var/obj/item/I in C.contents)
		.++

// An item used on an open closet goes inside for window players. TRUE when handled.
/proc/closet_window_put(obj/structure/closet/C, obj/item/I, mob/user)
	if (!closet_window_user(C, user) || !closet_window_access(user, C))
		return FALSE
	if (!closet_has_room(C, I, user))
		return TRUE
	if (!user.remove_from_mob(I))
		return TRUE
	I.forceMove(C)
	storage_note_inserted(I, user)
	to_chat(user, SPAN_NOTICE("You put \the [I] into \the [C]."))
	return TRUE

/obj/structure/closet/verb/closet_dump_out()
	set name = "Dump Out"
	set category = null
	set src in oview(1)
	var/mob/living/human/H = usr
	if (!istype(H) || H.stat || H.restrained() || !item_window)
		return
	if (!closet_window_access(H, src))
		to_chat(H, SPAN_WARNING("Open \the [src] first."))
		return
	if (!closet_item_count(src))
		to_chat(H, SPAN_NOTICE("\The [src] is empty."))
		return
	var/wait = istype(src, /obj/structure/closet/crate/large) ? 30 : 15
	H.visible_message(SPAN_NOTICE("[H] starts tipping out \the [src]."))
	if (!do_after(H, wait, src) || !closet_window_access(H, src))
		return
	var/turf/T = get_turf(src)
	for (var/obj/item/I in contents)
		I.forceMove(T)
	H.visible_message(SPAN_NOTICE("[H] tips out everything in \the [src]."))
	update_icon()

/obj/structure/closet/verb/closet_gather()
	set name = "Gather"
	set category = null
	set src in oview(1)
	var/mob/living/human/H = usr
	if (!istype(H) || H.stat || H.restrained() || !item_window)
		return
	if (!closet_window_access(H, src))
		to_chat(H, SPAN_WARNING("Open \the [src] first."))
		return
	if (!closet_window_user(src, H))
		// Without the window: the old quick sweep of the tile.
		var/swept = 0
		for (var/obj/item/I in get_turf(src))
			if (I.anchored || !closet_has_room(src, I, H, TRUE))
				continue
			I.forceMove(src)
			storage_note_inserted(I, H)
			swept++
		to_chat(H, SPAN_NOTICE(swept ? "You gather [swept] thing\s into \the [src]." : "There is nothing here to gather."))
		return
	closet_window_show(H, src)
	var/datum/storage_window/W = H.storage_window
	var/queued = 0
	for (var/obj/item/I in get_turf(src))
		if (I.anchored)
			continue
		if (W.enqueue(I, "near", src, FALSE))
			queued++
	to_chat(H, SPAN_NOTICE(queued ? "You start gathering [queued] thing\s into \the [src]." : "There is nothing here to gather."))
