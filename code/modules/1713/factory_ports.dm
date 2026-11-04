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

// Same item kind for merging: identical type, stack kind and colour, so no
// per-stack identity is lost.
/proc/factory_stack_matches(obj/item/stack/A, obj/item/stack/B)
	return istype(A) && istype(B) && A.type == B.type && A.stacktype == B.stacktype && A.color == B.color

// Move amount units of I into container, merging into matching stacks there
// first. Returns the amount moved.
/proc/factory_move_units(obj/item/I, atom/container, amount)
	if (!factory_movable_item(I) || !container || amount <= 0)
		return 0
	if (!istype(I, /obj/item/stack))
		I.forceMove(container)
		return 1
	var/obj/item/stack/S = I
	amount = min(amount, S.amount)
	var/remaining = amount
	for (var/obj/item/stack/existing in container)
		if (existing == S || !factory_stack_matches(existing, S))
			continue
		var/space = max(0, existing.max_amount - existing.amount)
		var/moved = min(space, remaining)
		if (moved <= 0)
			continue
		existing.amount += moved
		existing.update_icon()
		remaining -= moved
		if (!remaining)
			break
	if (remaining && remaining == S.amount)
		// The rest of the stack fits as it is.
		S.forceMove(container)
		return amount
	if (remaining)
		var/obj/item/stack/part = new S.type(container, remaining, FALSE)
		part.color = S.color
	S.amount -= amount
	if (S.amount <= 0)
		qdel(S)
	else
		S.update_icon()
	return amount

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
