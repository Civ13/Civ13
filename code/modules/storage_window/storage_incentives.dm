// Reasons to build storage (storage overhaul PR 6, docs/storage-window.md).
//
// Fire: a wooden, woven or cloth container that burns away takes its flammable
// contents with it; metal, stone and glass things drop out scorched but whole.
// Clay jars and other non-flammable stores don't burn, and a broken jar spills
// what it held (stone_age_storage.dm) rather than destroying it.
//
// Home comfort: "a tidy room" is a comfort point for a room that has at least
// one container and no more than HOME_TIDY_LOOSE loose things on the floor.

// Burns a storage's contents as its container burns away. Mobs walk out.
/proc/storage_burn_contents(atom/movable/container, list/things, turf/T)
	for (var/atom/movable/A in things)
		if (ismob(A))
			A.forceMove(T)
			continue
		var/obj/O = A
		if (istype(O) && O.flammable)
			qdel(O)
		else
			A.forceMove(T)

/obj/structure/storage_container/fire_act(temperature)
	if (!flammable || QDELETED(src))
		return
	if (!prob(27))
		return
	var/turf/T = get_turf(src)
	visible_message(SPAN_WARNING("\The [src] is burned away, and what was inside burns with it."))
	if (storage)
		storage_burn_contents(src, storage.contents.Copy(), T)
	qdel(src)

/obj/structure/closet/fire_act(temperature)
	if (!flammable || QDELETED(src))
		return
	if (!prob(27))
		return
	var/turf/T = get_turf(src)
	visible_message(SPAN_WARNING("\The [src] is burned away, and what was inside burns with it."))
	storage_burn_contents(src, contents.Copy(), T)
	qdel(src)

// Does this hold things a player can put away?
/proc/home_is_container(atom/movable/A)
	if (istype(A, /obj/structure/storage_container))
		return TRUE
	if (istype(A, /obj/structure/closet))
		var/obj/structure/closet/C = A
		return C.item_window
	if (istype(A, /obj/structure) && ("storage" in A.vars) && istype(A.vars["storage"], /obj/item/weapon/storage/internal))
		return TRUE
	return FALSE

// Loose things lying about: not fixed down, not rubbish (that's the clean point).
/proc/home_is_loose_thing(atom/movable/A)
	if (!istype(A, /obj/item))
		return FALSE
	var/obj/item/I = A
	return !I.anchored && !istype(I, /obj/item/trash)
