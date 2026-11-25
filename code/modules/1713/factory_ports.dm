// Factory ports: a mob-free way for automation (belts, transfer arms) to hand
// items to machines and storage and to take items back out. See
// docs/factory-automation-design.md. A port never reads a user, never prints
// to chat and never waits; mob-facing attackby code stays a separate wrapper.
//
// Amounts are stack units for stacks and 1 for any other item. Every proc is
// side-effect free except factory_insert and factory_take.

// How much of I this object would take right now, from direction from_dir.
/obj/proc/factory_accepts(obj/item/I, from_dir = 0)
	return 0

// Take up to factory_accepts() of I. A stack may be split; the remainder stays
// where it was. Returns the amount taken.
/obj/proc/factory_insert(obj/item/I, from_dir = 0)
	return 0

// The next item automation may take out toward to_dir, optionally limited to
// filter_type. Returns null when there is nothing to offer.
/obj/proc/factory_offer(to_dir = 0, filter_type = null)
	return null

// Move an offered item to destination. Returns TRUE when it moved.
/obj/proc/factory_take(obj/item/I, atom/destination)
	return FALSE

/proc/factory_item_amount(obj/item/I)
	if (istype(I, /obj/item/stack))
		var/obj/item/stack/S = I
		return max(0, S.amount)
	return 1

// An item automation may move: real, loose, not deleted and not held by a mob.
/proc/factory_movable_item(obj/item/I)
	if (!istype(I) || QDELETED(I) || I.anchored || I.abstract)
		return FALSE
	if (ismob(I.loc))
		return FALSE
	return TRUE

// Keep each stack subtype's identity contract, including issued currency.
/proc/factory_stack_matches(obj/item/stack/A, obj/item/stack/B)
	return istype(A) && istype(B) && A.type == B.type && A.stacktype == B.stacktype && A.color == B.color && A.stack_compatible(B) && B.stack_compatible(A)

// Move amount units of I into container, merging into matching stacks there
// first. Returns only the amount actually moved.
/proc/factory_move_units(obj/item/I, atom/container, amount)
	if (!factory_movable_item(I) || !container || container == I.loc || amount <= 0 || !persistence_movement_allowed(I, container))
		return 0
	if (!istype(I, /obj/item/stack))
		if (I.forceMove(container) && I.loc == container)
			return 1
		return 0

	var/obj/item/stack/S = I
	amount = min(amount, S.amount)
	if (amount <= 0)
		return 0
	var/remaining = amount
	for (var/obj/item/stack/existing in container)
		if (!factory_stack_matches(existing, S))
			continue
		var/space = max(0, existing.max_amount - existing.amount)
		var/moved = min(space, remaining)
		if (moved <= 0 || !S.transfer_to(existing, moved))
			continue
		existing.update_icon()
		remaining -= moved
		if (!remaining)
			if (!QDELETED(S))
				S.update_icon()
			return amount

	if (remaining == S.amount)
		// All unmerged units fit as the original stack; do not reconstruct it.
		if (S.forceMove(container) && S.loc == container)
			S.update_icon()
			S.update_slot_count()
			return amount
	else if (remaining > 0 && S.amount <= S.max_amount)
		// A real split delegates identity and other per-stack state to its subtype.
		// Don't split an overfilled stack: a refused move could not be fully rolled back.
		var/obj/item/stack/part = S.split(remaining)
		if (part && !QDELETED(part))
			if (part.forceMove(container) && part.loc == container)
				part.update_icon()
				part.update_slot_count()
				S.update_icon()
				return amount
			// The source still holds units, so there is room to put the split back.
			part.transfer_to(S, part.amount)
	S.update_icon()
	return amount - remaining

//////////////////////////////////////////////////////////////////////////////
// Closets and crates: closed storage accepts anything that fits its capacity
// and offers its contents. Open storage has its items on the floor instead.

/obj/structure/closet/proc/factory_used_capacity()
	var/used = 0
	for (var/obj/item/I in contents)
		used += ceil(I.w_class / 2)
	for (var/mob/living/M in contents)
		used += M.mob_size
	return used

/obj/structure/closet/proc/factory_merge_space(obj/item/stack/S)
	var/space = 0
	for (var/obj/item/stack/existing in contents)
		if (existing != S && factory_stack_matches(existing, S))
			space += max(0, existing.max_amount - existing.amount)
	return space

/obj/structure/closet/factory_accepts(obj/item/I, from_dir = 0)
	if (opened || !factory_movable_item(I) || I.loc == src)
		return 0
	var/amount = factory_item_amount(I)
	var/free = storage_capacity - factory_used_capacity()
	if (free >= ceil(I.w_class / 2))
		return amount
	// Without a free slot a stack can still top up matching stacks inside.
	if (istype(I, /obj/item/stack))
		return min(amount, factory_merge_space(I))
	return 0

/obj/structure/closet/factory_insert(obj/item/I, from_dir = 0)
	var/amount = factory_accepts(I, from_dir)
	if (amount <= 0)
		return 0
	return factory_move_units(I, src, amount)

/obj/structure/closet/factory_offer(to_dir = 0, filter_type = null)
	if (opened)
		return null
	for (var/obj/item/I in contents)
		if (filter_type && !istype(I, filter_type))
			continue
		if (factory_movable_item(I))
			return I
	return null

/obj/structure/closet/factory_take(obj/item/I, atom/destination)
	if (opened || !destination || I.loc != src || !factory_movable_item(I))
		return FALSE
	I.forceMove(destination)
	return I.loc == destination

//////////////////////////////////////////////////////////////////////////////
// Drills, sifters and the stamp mill deposit their output on their own tile.
// They offer those stacks, so an arm behind the machine can carry them off.

/obj/structure/drill/factory_offer(to_dir = 0, filter_type = null)
	var/turf/T = get_turf(src)
	if (!T)
		return null
	for (var/obj/item/stack/S in T)
		if (filter_type && !istype(S, filter_type))
			continue
		if (factory_movable_item(S))
			return S
	return null

/obj/structure/drill/factory_take(obj/item/I, atom/destination)
	if (!destination || I.loc != get_turf(src) || !factory_movable_item(I))
		return FALSE
	I.forceMove(destination)
	return I.loc == destination
