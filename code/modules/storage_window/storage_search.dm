// Searching (Escape From Tarkov style mechanics, Civ13 look): things in a
// container that someone else filled show as "?" boxes of their real size until
// you have looked at each one. Looking takes 0.4 s for a tiny thing up to 1.5 s
// for a bulky one, top first, while the window is open and you stay put.
//
// What a character has seen is kept per item and never saved: after a restart
// other people's containers must be searched again. Your hands, pockets, worn
// gear and the floor are always known, and so is anything you put in yourself.
// Putting a thing into a container makes it unknown to everyone else.

/obj/item
	// Players (by key) who have seen this item where it lies now.
	var/tmp/list/storage_seen_by

/obj/item/persistence_runtime_var(key)
	return key == "storage_seen_by" || ..()

/proc/storage_seer_key(mob/M)
	if (!M)
		return null
	return M.ckey ? M.ckey : "\ref[M]"

// Called when an item goes into a storage: only the one who put it there knows it.
/proc/storage_note_inserted(obj/item/I, mob/by)
	if (!istype(I))
		return
	var/key = storage_seer_key(by)
	I.storage_seen_by = key ? list(key) : null

/proc/storage_item_seen(obj/item/I, mob/M)
	var/key = storage_seer_key(M)
	return key && I.storage_seen_by && (key in I.storage_seen_by)

/proc/storage_mark_seen(obj/item/I, mob/M)
	var/key = storage_seer_key(M)
	if (!key)
		return
	if (!I.storage_seen_by)
		I.storage_seen_by = list()
	I.storage_seen_by |= key

// Deciseconds to look at one thing: 0.4 s tiny, 0.7 small, 1.0 normal, 1.2 large, 1.5 bulky.
/proc/storage_search_time(obj/item/I)
	return 4 + round((clamp(I.w_class, 1, 5) - 1) * 2.75, 1)

/datum/storage_window
	// The container being searched, the thing being looked at and since when.
	var/obj/item/weapon/storage/search_holder
	var/obj/item/search_item
	var/search_started = 0
	var/turf/search_turf
	var/search_timer

// Groups you never search: your own things and what lies in the open.
/proc/storage_window_kind_known(kind)
	return kind == STORAGE_WINDOW_KIND_HANDS || kind == STORAGE_WINDOW_KIND_POCKETS || kind == STORAGE_WINDOW_KIND_WORN || kind == STORAGE_WINDOW_KIND_FLOOR

/datum/storage_window/proc/knows(obj/item/I, kind)
	if (storage_window_kind_known(kind))
		return TRUE
	return storage_item_seen(I, viewer)

/datum/storage_window/proc/first_unseen(obj/item/weapon/storage/S)
	for (var/obj/item/I in S.contents)
		if (!storage_item_seen(I, viewer))
			return I
	return null

// Start (or move) the search to a container the window lists.
/datum/storage_window/proc/begin_search(obj/item/weapon/storage/S)
	if (!S || !lists_holder(S) || !storage_window_access(viewer, S))
		return FALSE
	if (S == search_holder && search_item)
		return TRUE
	stop_search()
	if (!first_unseen(S))
		return FALSE
	search_holder = S
	search_turf = get_turf(viewer)
	search_next()
	return TRUE

/datum/storage_window/proc/search_next()
	search_item = null
	if (!search_holder || QDELETED(search_holder) || !viewer || QDELETED(viewer))
		stop_search()
		return
	search_item = first_unseen(search_holder)
	if (!search_item)
		search_holder = null
		refresh()
		return
	search_started = world.time
	search_timer = addtimer(CALLBACK(src, PROC_REF(finish_look)), storage_search_time(search_item), TIMER_STOPPABLE)
	refresh()

/datum/storage_window/proc/stop_search()
	if (search_timer)
		deltimer(search_timer)
	search_timer = null
	search_holder = null
	search_item = null

/datum/storage_window/proc/finish_look()
	search_timer = null
	var/mob/living/human/H = viewer
	if (!H || QDELETED(H) || !search_holder)
		return
	if (get_turf(H) != search_turf || H.stat || H.restrained() || H.incapacitated() || !lists_holder(search_holder) || !storage_window_access(H, search_holder))
		stop_search()
		refresh()
		return
	if (search_item && search_item.loc == search_holder)
		storage_mark_seen(search_item, H)
	search_next()
