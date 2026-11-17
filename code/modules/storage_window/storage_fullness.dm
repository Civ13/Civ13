// How full a container is, in words, on examine. The storage window shows a
// bar, but the classic strip and a closed bag showed nothing until an item was
// refused. See docs/storage-window.md.

// 0-1: the tighter of the slot count and the space budget.
/obj/item/weapon/storage/proc/fullness()
	var/share = 0
	if (storage_slots)
		share = contents.len / storage_slots
	if (max_storage_space)
		var/used = 0
		for (var/obj/item/I in contents)
			used += I.get_storage_cost()
		share = max(share, used / max_storage_space)
	return min(1, share)

/proc/storage_fullness_text(share)
	if (share <= 0)
		return "It is empty."
	if (share >= 1)
		return "It is full."
	if (share >= 0.85)
		return "It is nearly full."
	if (share >= 0.6)
		return "It is more than half full."
	if (share >= 0.4)
		return "It is about half full."
	return "It has plenty of room left."

// Internal holders (vehicles, racks, worn pockets) speak through their owner.
/obj/item/weapon/storage/examine(mob/user, distance = -1)
	. = ..()
	if (istype(src, /obj/item/weapon/storage/internal) || !user)
		return
	if (loc != user && get_dist(user, src) > 1)
		return
	to_chat(user, SPAN_NOTICE(storage_fullness_text(fullness())))
