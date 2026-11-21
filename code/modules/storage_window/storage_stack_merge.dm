// A stack put into a bag that already holds the same kind of stack tops that
// stack up first (bones onto bones, planks onto planks), through the strip, the
// storage window, a click or a gather. Whatever doesn't fit goes in as its own
// stack when the bag has room. Merging only goes into stacks the person putting
// it in knows about (their own worn gear, or things they have seen), so it never
// reveals what is in a container they haven't searched.

// FALSE for storage that must keep each item separate (a drying rack keeps one
// leaf bundle per slot, with its progress written into that bundle's name).
/obj/item/weapon/storage/var/merges_stacks = TRUE

// The stacks in S that W may top up for user.
/obj/item/weapon/storage/proc/stack_merge_targets(obj/item/W, mob/user)
	. = list()
	if (!merges_stacks)
		return
	var/obj/item/stack/ST = W
	if (!istype(ST) || ST.amount <= 0)
		return
	var/known = FALSE
	if (!user)
		known = TRUE
	else if (ishuman(user))
		var/mob/living/human/H = user
		known = (src in H.worn_storage_group("all"))
	for (var/obj/item/stack/other in contents)
		if (other == ST || other.amount >= other.max_amount)
			continue
		if (other.stacktype != ST.stacktype || !other.stack_compatible(ST) || !ST.stack_compatible(other))
			continue
		if (istype(other, /obj/item/stack/material))
			var/obj/item/stack/material/M1 = other
			var/obj/item/stack/material/M2 = ST
			if (!istype(M2) || !M1.material || !M2.material || M1.material.name != M2.material.name)
				continue
		if (!known && !storage_item_seen(other, user))
			continue
		. += other

// TRUE when the whole of W fits onto stacks already in S.
/proc/storage_stack_fits(obj/item/weapon/storage/S, obj/item/W, mob/user)
	var/obj/item/stack/ST = W
	if (!istype(S) || !istype(ST) || ST.anchored)
		return FALSE
	return S.stack_merge_room(ST, user) >= ST.amount

// How many of W the stacks already in S can take.
/obj/item/weapon/storage/proc/stack_merge_room(obj/item/W, mob/user)
	. = 0
	for (var/obj/item/stack/other in stack_merge_targets(W, user))
		. += other.max_amount - other.amount

// Tops up matching stacks. TRUE when all of W went in (W is then deleted).
/obj/item/weapon/storage/proc/merge_stack_in(obj/item/W, mob/user, prevent_warning = FALSE)
	var/obj/item/stack/ST = W
	if (!istype(ST))
		return FALSE
	var/list/targets = stack_merge_targets(ST, user)
	if (!targets.len)
		return FALSE
	var/all_fit = stack_merge_room(ST, user) >= ST.amount
	if (all_fit && user && ST.loc == user)
		user.remove_from_mob(ST)
	var/obj/item/stack/first
	for (var/obj/item/stack/other in targets)
		if (QDELETED(ST) || ST.amount <= 0)
			break
		var/before = other.amount
		ST.transfer_to(other)
		if (other.amount > before)
			if (!first)
				first = other
			if (user)
				storage_mark_seen(other, user)
	if (!first)
		return FALSE
	if (user && !prevent_warning)
		to_chat(user, SPAN_NOTICE("You add [all_fit ? "\the [first]" : "some"] to the stack in [src]."))
	if (user && user.s_active == src)
		orient2hud(user)
		show_to(user)
	update_icon()
	return QDELETED(ST) || ST.amount <= 0
