// Makes a stack of `amount` at `target` and tops up matching stacks already there.
// new stack(loc) merges its default single item before the caller sets amount,
// so "new X(loc); X.amount = n" left one item on an existing pile and lost the rest.
// Whatever does not fit stays in the new stack. Returns the stack holding the
// remainder, or the last stack it merged into when everything fit.
/proc/spawn_stack(path, atom/target, amount)
	if (!ispath(path, /obj/item/stack) || !target || amount <= 0)
		return null
	var/obj/item/stack/made = new path(target, amount, FALSE)
	made.amount = amount
	if (!made.can_stack)
		made.update_icon()
		return made
	var/obj/item/stack/kept = made
	for (var/obj/item/stack/S in target)
		if (S == made || !istype(S, made.type) || !made.stack_compatible(S) || !S.stack_compatible(made) || S.amount <= 0)
			continue
		var/room = S.max_amount - S.amount
		if (room <= 0)
			continue
		var/moved = min(room, made.amount)
		S.amount += moved
		made.amount -= moved
		S.update_icon()
		S.update_strings()
		kept = S
		if (made.amount <= 0)
			qdel(made)
			return kept
	made.update_icon()
	made.update_strings()
	return made
