/////////////////////////////// Item heaps ///////////////////////////////
// A heap is one item standing for several identical loose items on a tile,
// such as the spent casings a machine gun throws out. heap_count says how many
// it holds and overlays draw a few of the extras, so a tile of brass costs one
// object, one abandonment entry and one save record instead of one per item.
// Picking the heap up takes one item and leaves the rest as a heap.
//
// A type opts in by returning TRUE from heap_matches() for an item it can
// absorb and by building a copy of itself in heap_copy(). Item piles
// (item_piles.dm) still decide which item on a tile is clickable.

/obj/item/var/heap_count = 1

// TRUE when other can be folded into this heap. Off unless a type opts in.
/obj/item/proc/heap_matches(obj/item/other)
	return FALSE

// A new single item identical to this one, at where. Types that heap supply it.
/obj/item/proc/heap_copy(atom/where)
	return null

// The heap on T that item could join, or null.
/obj/item/proc/heap_find(turf/T)
	for (var/obj/item/H in T)
		if (H != src && !QDELETED(H) && H.heap_matches(src))
			return H
	return null

/obj/item/proc/heap_add(n)
	heap_count = max(1, heap_count + n)
	heap_update_overlays()

// Extra items drawn around the first one, at fixed offsets so heaps of the
// same size share their appearances.
/obj/item/proc/heap_update_overlays()
	overlays.Cut()
	var/shown = min(heap_count - 1, ITEM_HEAP_VISIBLE_MAX)
	for (var/i = 1, i <= shown, i++)
		var/image/I = image(icon, icon_state)
		I.pixel_x = ((i * 7) % 15) - 7
		I.pixel_y = ((i * 11) % 13) - 6
		I.transform = matrixangle((i * 67) % 360)
		overlays += I

// Leaves all but one item of the heap on its tile, as a new heap.
/obj/item/proc/heap_split_one()
	if (heap_count <= 1 || !isturf(loc))
		return null
	var/obj/item/rest = heap_copy(loc)
	if (!rest)
		return null
	rest.heap_count = heap_count - 1
	rest.heap_update_overlays()
	heap_count = 1
	heap_update_overlays()
	return rest

// Examine text for a heap; items.dm's examine calls it.
/obj/item/proc/heap_examine(mob/user)
	if (heap_count > 1)
		to_chat(user, "There are [heap_count] of them in this heap.")
