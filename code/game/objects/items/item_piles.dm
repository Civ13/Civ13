/////////////////////////////// Item piles ///////////////////////////////
// BYOND's right-click menu lists every clickable object under the mouse, so a
// tile holding 70 identical items showed 70 identical entries. Items on a tile
// that look the same (type, name, icon state) form a pile: only the top one
// stays clickable, the rest are mouse-transparent until the top one leaves.
// They still draw as before. Leaving the tile always makes an item clickable.

// The item is hidden under an identical one on its tile; pile_opacity holds
// the mouse_opacity it had. Both save with the item so a loaded pile stays
// consistent (mouse_opacity itself is saved when it differs from the default).
/obj/item/var/pile_hidden = FALSE
/obj/item/var/pile_opacity = 1

var/global/list/item_pile_dirty_turfs = list()
var/global/item_pile_flush_pending = FALSE

#define ITEM_PILE_BATCH 500

/proc/item_pile_mark(turf/T)
	if (!isturf(T))
		return
	item_pile_dirty_turfs[T] = TRUE
	if (item_pile_flush_pending)
		return
	item_pile_flush_pending = TRUE
	addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(item_pile_flush)), 1)

// Refreshes marked tiles a batch at a time (map loading marks thousands).
/proc/item_pile_flush(limit = ITEM_PILE_BATCH)
	item_pile_flush_pending = FALSE
	var/done = 0
	while (item_pile_dirty_turfs.len && (!limit || done < limit))
		var/turf/T = item_pile_dirty_turfs[item_pile_dirty_turfs.len]
		item_pile_dirty_turfs.len--
		item_pile_refresh(T)
		done++
	if (item_pile_dirty_turfs.len && !item_pile_flush_pending)
		item_pile_flush_pending = TRUE
		addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(item_pile_flush)), 1)

/proc/item_pile_key(obj/item/I)
	return "[I.type]|[I.name]|[I.icon_state]"

// Recomputes which item of each identical group on T stays clickable: the
// last one in the tile's contents, which is drawn on top of the others.
/proc/item_pile_refresh(turf/T)
	if (!isturf(T))
		return
	var/list/top = list()
	for (var/obj/item/I in T)
		if (QDELETED(I))
			continue
		if (!I.pile_hidden && !I.mouse_opacity)
			continue // made unclickable on purpose by its own code; not ours to manage
		top[item_pile_key(I)] = I
	for (var/obj/item/I in T)
		if (QDELETED(I) || (!I.pile_hidden && !I.mouse_opacity))
			continue
		if (top[item_pile_key(I)] == I)
			I.pile_reveal()
		else
			I.pile_hide()

/obj/item/proc/pile_hide()
	if (pile_hidden)
		return
	pile_opacity = mouse_opacity
	pile_hidden = TRUE
	mouse_opacity = 0

/obj/item/proc/pile_reveal()
	if (!pile_hidden)
		return
	pile_hidden = FALSE
	mouse_opacity = pile_opacity || 1
	pile_opacity = initial(pile_opacity)

/obj/item/New()
	..()
	if (isturf(loc))
		item_pile_mark(loc)

/turf/Entered(atom/movable/AM, atom/old_loc)
	. = ..()
	if (istype(AM, /obj/item))
		item_pile_mark(src)

/turf/Exited(atom/movable/AM, atom/new_loc)
	. = ..()
	if (istype(AM, /obj/item))
		var/obj/item/I = AM
		I.pile_reveal() // clickable at once in a hand, bag or another tile
		item_pile_mark(src)

/proc/item_pile_moved(atom/movable/AM, atom/origin, atom/destination)
	if (!istype(AM, /obj/item) || !(isturf(origin) || isturf(destination)))
		return
	var/obj/item/I = AM
	if (!isturf(destination))
		I.pile_reveal()
	item_pile_mark(origin)
	item_pile_mark(destination)

// Other raw loc changes (legacy teleports) skip Exited too.
/obj/item/pickup(mob/user)
	pile_reveal()
	..()

/obj/item/equipped(var/mob/user, var/slot)
	pile_reveal()
	..()

/obj/item/on_enter_storage(obj/item/weapon/storage/S as obj)
	pile_reveal()
	..()

// Safety net for a pile whose top item left by a raw loc change: clicking the
// tile (all its items hidden, so the click lands on the turf) re-checks it.
/turf/Click(var/location, var/control, var/params)
	item_pile_mark(src)
	return ..()
