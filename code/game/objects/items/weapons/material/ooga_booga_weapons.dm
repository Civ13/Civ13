
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
		to_chat(H, "You start picking the leaves from the branch...")
		if (do_after(H, 60, src))
			if (src && leaves)
				var /obj/item/stack/material/leaf/dropleaves = new /obj/item/stack/material/leaf(get_turf(src))
				dropleaves.amount = 3
				dropleaves.update_strings()
				to_chat(H, "You pick up some leaves from the branch.")
				name = "cleared branch"
				desc = "A tree branch with all the leaves picked out."
				icon_state = "cleared_stick"
				leaves = FALSE
				return
		return
	else if (H.a_intent == I_HARM && !leaves && branched)
		to_chat(H, "You start removing the small twigs...")
		if (do_after(H, 60, src))
			if (src && branched)
				if (map.ID == MAP_WIZARD_BOY)
					new /obj/item/wand_part/pine_wood(get_turf(src))
				else
					new /obj/item/weapon/branch(get_turf(src))
				to_chat(H, "You finish clearing the stick.")
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
	var/tmp/assembling_axe = FALSE

/obj/item/weapon/branch/persistence_runtime_var(key)
	if (key == "assembling_axe")
		return TRUE
	return ..()

/obj/item/weapon/branch/proc/axe_binding(mob/user)
	var/turf/site = get_turf(user)
	if (!site)
		return
	for (var/obj/item/stack/S in user.contents + site.contents)
		if (!QDELETED(S) && S.amount >= 1 && (istype(S, /obj/item/stack/sinew) || istype(S, /obj/item/stack/material/rope)))
			return S

/obj/item/weapon/branch/proc/axe_parts_valid(mob/user, obj/item/weapon/flint/head, obj/item/stack/binding)
	return !QDELETED(src) && !QDELETED(user) && !QDELETED(head) && !QDELETED(binding) && sharpened && head.sharpened && user.stat == CONSCIOUS && (loc == user || loc == get_turf(user)) && head.loc == user && binding.amount >= 1 && (binding.loc == user || binding.loc == get_turf(user)) && (istype(binding, /obj/item/stack/sinew) || istype(binding, /obj/item/stack/material/rope))

/obj/item/weapon/branch/proc/axe_assembly_wait(mob/user)
	return do_after(user, 100, src)

/obj/item/weapon/branch/proc/axe_actor_connected(mob/user)
	return user && user.client

/obj/item/weapon/branch/proc/assemble_flint_axe(mob/user, obj/item/weapon/flint/head)
	if (assembling_axe || !axe_actor_connected(user))
		return
	var/obj/item/stack/binding = axe_binding(user)
	if (!binding)
		to_chat(user, SPAN_WARNING("You need one portion of sinew or rope in your inventory or on the ground beneath you to bind the axe head."))
		return
	if (!axe_parts_valid(user, head, binding))
		return
	assembling_axe = TRUE
	to_chat(user, SPAN_NOTICE("You start binding the flint head to the stick..."))
	var/completed = axe_assembly_wait(user)
	if (QDELETED(src))
		return
	assembling_axe = FALSE
	if (!completed || !axe_actor_connected(user) || !axe_parts_valid(user, head, binding))
		return
	if (!binding.use(1))
		return
	// Invalidate the reusable head before creating the completed tool.
	head.sharpened = FALSE
	qdel(head)
	new /obj/item/weapon/material/hatchet/tribal/flint(get_turf(user))
	to_chat(user, SPAN_NOTICE("You finish making the bound flint axe."))
	qdel(src)

/obj/item/weapon/branch/attack_self(mob/living/human/user as mob)
	if (ants)
		to_chat(user, SPAN_NOTICE("You start licking some ants off the stick..."))
		if (do_after(user, 50, src))
			if (src && ants)
				to_chat(user, SPAN_NOTICE("You finish eating some ants."))
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
		to_chat(user, "You start sharpening the stick...")
		if (do_after(user, 80, src))
			if (src && !sharpened)
				to_chat(user, "You finish sharpening the stick.")
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
			assemble_flint_axe(user, F)
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
