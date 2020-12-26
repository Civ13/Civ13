
/obj/structure/branch
	name = "branch"
	desc = "A tree branch still with leaves attached."
	icon = 'icons/obj/old_weapons.dmi'
	icon_state = "leaved_stick"
	density = FALSE
	anchored = FALSE
	not_movable = FALSE
	not_disassemblable = TRUE
	flammable = TRUE
	var/leaves = TRUE
	var/branched = TRUE

/obj/structure/branch/cleared
	name = "cleared branch"
	desc = "A tree branch with all the leaves picked out."
	icon_state = "cleared_stick"
	leaves = FALSE

/obj/structure/branch/attack_hand(mob/living/human/H)
	if (H.a_intent == I_GRAB && leaves)
		H << "You start picking the leaves from the branch..."
		if (do_after(H, 60, src))
			if (src && leaves)
				new /obj/item/stack/material/leaf(get_turf(src))
				new /obj/item/stack/material/leaf(get_turf(src))
				new /obj/item/stack/material/leaf(get_turf(src))
				H << "You pick up some leaves from the branch."
				name = "cleared branch"
				desc = "A tree branch with all the leaves picked out."
				icon_state = "cleared_stick"
				leaves = FALSE
				return
		return
	else if (H.a_intent == I_HARM && !leaves && branched)
		H << "You start removing the small twigs..."
		if (do_after(H, 60, src))
			if (src && branched)
				new /obj/item/weapon/branch(get_turf(src))
				H << "You finish clearing the stick."
				branched = FALSE
				qdel(src)
				return
		return
	else
		..()

/obj/item/weapon/branch
	name = "stick"
	desc = "A tree branch with all the leaves and small branches picked out."
	icon_state = "debranched_stick"
	item_state = "debranched_stick"
	icon = 'icons/obj/old_weapons.dmi'
	force = 7
	attack_verb = list("hit","bashed","poked")
	sharp = FALSE
	edge = FALSE
	slot_flags = SLOT_BELT
	throw_speed = 7
	throw_range = 7
	allow_spin = FALSE
	value = 1
	cooldownw = 6
	flammable = TRUE
	var/sharpened = FALSE

	var/ants = FALSE

/obj/item/weapon/branch/attack_self(mob/living/human/user as mob)
	if (ants)
		user << "You start licking some ants off the stick..."
		if (do_after(user, 50, src))
			if (src && ants)
				user << "You finish eating some ants."
				icon_state = "sharpened_stick"
				ants = FALSE
				if (user.gorillaman)
					user.mood += 10
				else if (user.ant)
					user.mood -= 20
				else if (!user.orc && !user.crab)
					user.mood -= 10
				user.nutrition += 80
				return
	else
		..()
/obj/item/weapon/branch/attackby(obj/item/weapon/W as obj, mob/user as mob)
	if (W.edge && !sharpened)
		user << "You start sharpening the stick..."
		if (do_after(user, 80, src))
			if (src && !sharpened)
				user << "You finish sharpening the stick."
				name = "sharpened stick"
				desc = "A sharpened stick, to be used against bad apes."
				icon_state = "sharpened_stick"
				sharp = TRUE
				force = 14
				sharpened = TRUE
				return
		return
	else if (sharpened && istype(W, /obj/item/weapon/flint))
		var/obj/item/weapon/flint/F = W
		if (F.sharpened)
			user << "You start attaching the flint to the stick..."
			if (do_after(user, 100, src))
				if (src && F && F.sharpened)
					user << "You finish making the flint axe."
					new/obj/item/weapon/material/hatchet/tribal/flint(user.loc)
					qdel(F)
					qdel(src)
					return
	else
		..()

/obj/item/weapon/branch/sharpened
	name = "sharpened stick"
	desc = "A sharpened stick, to be used against bad apes."
	icon_state = "sharpened_stick"
	item_state = "sharpened_stick"
	sharp = TRUE
	force = 14
	sharpened = TRUE