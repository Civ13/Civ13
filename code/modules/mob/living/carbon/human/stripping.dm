/mob/living/human/proc/handle_strip(var/slot_to_strip,var/mob/living/user)

	if (!slot_to_strip || !user.IsAdvancedToolUser())
		return

	if (user.incapacitated()  || !user.Adjacent(src))
		user << browse(null, text("window=mob[name]"))
		return

	var/obj/item/target_slot = get_equipped_item(text2num(slot_to_strip))

	switch(slot_to_strip)
		// Handle things that are part of this interface but not removing/replacing a given item.
		if ("pockets")
			visible_message("<span class='danger'>\The [user] is trying to empty \the [src]'s pockets!</span>")
			if (do_mob(user,src,HUMAN_STRIP_DELAY,progress = FALSE))
				empty_pockets(user)
			return
		if ("splints")
			visible_message("<span class='danger'>\The [user] is trying to remove \the [src]'s splints!</span>")
			if (do_mob(user,src,HUMAN_STRIP_DELAY,progress = FALSE))
				remove_splints(user)
			return
		if ("internals")
			visible_message("<span class='danger'>\The [usr] is trying to set \the [src]'s internals!</span>")
			return
		if ("tie")
			var/obj/item/clothing/under/suit = w_uniform
			if (!istype(suit) || !suit.accessories.len)
				return
			var/obj/item/clothing/accessory/A = suit.accessories[1]
			if (!istype(A))
				return
			visible_message("<span class='danger'>\The [usr] is trying to remove \the [src]'s [A.name]!</span>")

			if (!do_mob(user,src,HUMAN_STRIP_DELAY,progress=0))
				return

			if (!A || suit.loc != src || !(A in suit.accessories))
				return

			if (istype(A, /obj/item/clothing/accessory/medal))
				user.visible_message("<span class='danger'>\The [user] tears off \the [A] from [src]'s [suit.name]!</span>")
			attack_log += "\[[time_stamp()]\] <font color='orange'>Has had \the [A] removed by [user.name] ([user.ckey])</font>"
			user.attack_log += "\[[time_stamp()]\] <font color='red'>Attempted to remove [name]'s ([ckey]) [A.name]</font>"
			A.on_removed(user)
			suit.accessories -= A
			update_inv_w_uniform()
			return

	// Are we placing or stripping?
	var/stripping
	var/obj/item/held = user.get_active_hand()
	if (!istype(held))
		if (!istype(target_slot))  // They aren't holding anything valid and there's nothing to remove, why are we even here?
			return
		if (!target_slot.canremove)
			user << "<span class='warning'>You cannot remove \the [src]'s [target_slot.name].</span>"
			return
		stripping = TRUE

	if (stripping)
		visible_message("<span class='danger'>\The [user] is trying to remove \the [src]'s [target_slot.name]!</span>")
	else
		visible_message("<span class='danger'>\The [user] is trying to put \a [held] on \the [src]!</span>")

	if (!do_mob(user,src,HUMAN_STRIP_DELAY,progress = FALSE))
		return

	if (!stripping && user.get_active_hand() != held)
		return

	if (stripping)
		admin_attack_log(user, src, "Attempted to remove \a [target_slot]", "Target of an attempt to remove \a [target_slot].", "attempted to remove \a [target_slot] from")
		unEquip(target_slot)
	else if (user.unEquip(held))
		equip_to_slot_if_possible(held, text2num(slot_to_strip), FALSE, TRUE, TRUE)
		if (held && held.loc != src)
			user.put_in_hands(held)

// Empty out everything in the target's pockets.
/mob/living/human/proc/empty_pockets(var/mob/living/user)
	if (!r_store && !l_store)
		user << "<span class='warning'>\The [src] has nothing in their pockets.</span>"
		return
	if (r_store)
		unEquip(r_store)
	if (l_store)
		unEquip(l_store)
	visible_message("<span class='danger'>\The [user] empties \the [src]'s pockets!</span>")

// Remove all splints.
/mob/living/human/proc/remove_splints(var/mob/living/user)

	var/can_reach_splints = TRUE

	if (can_reach_splints)
		var/removed_splint
		for (var/organ in list("l_leg","r_leg","l_arm","r_arm"))
			var/obj/item/organ/external/o = get_organ(organ)
			if (o && o.status & ORGAN_SPLINTED)
				var/obj/item/W = new /obj/item/stack/medical/splint(get_turf(src), TRUE)
				o.status &= ~ORGAN_SPLINTED
				W.add_fingerprint(user)
				removed_splint = TRUE
		if (removed_splint)
			visible_message("<span class='danger'>\The [user] removes \the [src]'s splints!</span>")
		else
			user << "<span class='warning'>\The [src] has no splints to remove.</span>"