/obj/item/clothing/proc/can_attach_accessory(obj/item/clothing/accessory/A)
	if (valid_accessory_slots && istype(A) && (A.slot in valid_accessory_slots))
		.=1
	else
		return FALSE
	if (accessories.len && restricted_accessory_slots && (A.slot in restricted_accessory_slots))
		for (var/obj/item/clothing/accessory/AC in accessories)
			if (AC.slot == A.slot)
				return FALSE

/obj/item/clothing/attackby(var/obj/item/I, var/mob/user)
	if (istype(I, /obj/item/clothing/accessory))

		if (!valid_accessory_slots || !valid_accessory_slots.len)
			usr << "<span class='warning'>You cannot attach accessories of any kind to \the [src].</span>"
			return

		var/obj/item/clothing/accessory/A = I
		if (can_attach_accessory(A))
			user.drop_item()
			accessories += A
			A.on_attached(src, user)
			verbs |= /obj/item/clothing/proc/removetie_verb
			if (istype(loc, /mob/living/human))
				var/mob/living/human/H = loc
				H.update_inv_w_uniform()
			return
		else
			to_chat(user, SPAN_DANGER("You cannot attach more accessories of this type to [src]."))
		return

	if (accessories.len)
		for (var/obj/item/clothing/accessory/A in accessories)
			A.attackby(I, user)
		return

	if (istype(I, /obj/item/stack/material/rags))
		var/obj/item/stack/material/rags/R = I
		if (secondary_action && ripable && R.amount >= 1 && health < initial(health)*4)

			user << "You start patching \the [src]..."
			if (do_after(user, 100, user.loc))
				playsound(user.loc, 'sound/items/poster_ripped.ogg', 100, TRUE)
				user << "You finish patching \the [src]."
				health += 5
				if (R.amount > 1)
					R.amount--
				else
					qdel(R)
				return
	else if (istype(I, /obj/item/stack/material/cloth))
		var/obj/item/stack/material/cloth/R = I
		if (secondary_action && ripable && R.amount >= 1 && health < initial(health)*4)

			user << "You start patching \the [src]..."
			if (do_after(user, 100, user.loc))
				playsound(user.loc, 'sound/items/poster_ripped.ogg', 100, TRUE)
				user << "You finish patching \the [src]."
				health += 10
				if (R.amount > 1)
					R.amount--
				else
					qdel(R)
				return
	else if (istype(I, /obj/item/stack/material/woolcloth))
		var/obj/item/stack/material/woolcloth/R = I
		if (secondary_action && ripable && R.amount >= 1 && health < initial(health)*4)

			user << "You start patching \the [src]..."
			if (do_after(user, 100, user.loc))
				playsound(user.loc, 'sound/items/poster_ripped.ogg', 100, TRUE)
				user << "You finish patching \the [src]."
				health += 12
				if (R.amount > 1)
					R.amount--
				else
					qdel(R)
				return
	else
		return
	..()

/obj/item/clothing/attack_hand(var/mob/user)
	//only forward to the attached accessory if the clothing is equipped (not in a storage)
	if (accessories.len && loc == user)
		for (var/obj/item/clothing/accessory/A in accessories)
			A.attack_hand(user)
		return
	return ..()

/obj/item/clothing/MouseDrop(var/obj/over_object)
	if (ishuman(usr) || issmall(usr))
		//makes sure that the clothing is equipped so that we can't drag it into our hand from miles away.
		if (!(loc == usr))
			return

		if (( usr.restrained() ) || ( usr.stat ))
			return

		if (!usr.unEquip(src))
			return
		if (istype(over_object, /obj/screen/inventory/hand))
			var/obj/screen/inventory/hand/H = over_object
			switch(H.slot_id)
				if (slot_r_hand)
					usr.put_in_r_hand(src)
				if (slot_l_hand)
					usr.put_in_l_hand(src)
		add_fingerprint(usr)

/obj/item/clothing/examine(var/mob/user)
	..(user)
	if (accessories.len)
		for (var/obj/item/clothing/accessory/A in accessories)
			user << "\A [A] is attached to it."

/obj/item/clothing/proc/remove_accessory(mob/user, obj/item/clothing/accessory/A)
	if (!(A in accessories))
		return

	A.on_removed(user)
	accessories -= A
	update_clothing_icon()

/obj/item/clothing/proc/removetie_verb()
	set name = "Remove Accessory"
	set category = null
	set src in usr
	if (!istype(usr, /mob/living)) return
	if (usr.stat) return
	if (!accessories.len) return
	var/obj/item/clothing/accessory/A
	if (accessories.len > 1)
		A = WWinput(usr, "Select an accessory to remove from [src].", "Remove Accessory", accessories[1], accessories)
	else
		A = accessories[1]
	remove_accessory(usr,A)
	if (!accessories.len)
		verbs -= /obj/item/clothing/proc/removetie_verb

/obj/item/clothing/emp_act(severity)
	if (accessories.len)
		for (var/obj/item/clothing/accessory/A in accessories)
			A.emp_act(severity)
	..()