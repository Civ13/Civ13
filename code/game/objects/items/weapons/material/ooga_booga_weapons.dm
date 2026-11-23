
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
	var/cutting_viable = FALSE

/obj/structure/branch/cleared
	name = "cleared branch"
	desc = "A tree branch with all the leaves picked out."
	icon_state = "cleared_stick"
	leaves = FALSE

/obj/structure/branch/examine(mob/user, distance = -1)
	. = ..()
	if (cutting_viable && branched)
		to_chat(user, SPAN_NOTICE("Pick it up with an empty hand on Help intent to plant it as a cutting. Removing its small twigs makes it unusable for planting."))

/obj/structure/branch/proc/pick_up_cutting(mob/living/human/H)
	if (QDELETED(src) || !cutting_viable || !branched || !istype(H) || H.incapacitated() || H.get_active_hand() || !isturf(H.loc) || !isturf(loc) || !H.Adjacent(src))
		return FALSE
	if (persistence_active_operation || persistence_save_in_progress || persistence_load_recovery_required)
		return FALSE
	var/obj/item/tree_cutting/C = new(loc)
	C.leaves = leaves
	if (!leaves)
		C.icon_state = "cleared_stick"
	if (!H.put_in_active_hand(C))
		qdel(C)
		return FALSE
	qdel(src)
	return TRUE

/obj/structure/branch/attack_hand(mob/living/human/H)
	if (H.a_intent == I_HELP && cutting_viable)
		pick_up_cutting(H)
		return
	if (H.a_intent == I_GRAB && leaves)
		if (!H.may_do_after)
			return
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
		if (!H.may_do_after)
			return
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

// The portable form is not a crafted stick. Setting it down preserves the
// original leaf/wood processing path without making finished sticks plantable.
/obj/item/tree_cutting
	name = "tree cutting"
	desc = "An intact broadleaf branch. Use it on an open ploughed plot to plant it, or click it in your active hand to set it down for stripping."
	icon = 'icons/obj/old_weapons.dmi'
	icon_state = "leaved_stick"
	item_state = "debranched_stick"
	w_class = ITEM_SIZE_SMALL
	flammable = TRUE
	var/leaves = TRUE

/obj/item/tree_cutting/attack_self(mob/user)
	if (!can_handle_cutting(user))
		return
	var/obj/structure/branch/B
	if (leaves)
		B = new /obj/structure/branch(user.loc)
	else
		B = new /obj/structure/branch/cleared(user.loc)
	B.cutting_viable = TRUE
	qdel(src)
	to_chat(user, SPAN_NOTICE("You set down the branch. Grab to strip any leaves, then Harm to trim it into a stick."))

/obj/item/tree_cutting/proc/can_handle_cutting(mob/user)
	return !QDELETED(src) && ishuman(user) && !user.incapacitated() && isturf(user.loc) && loc == user && user.get_active_hand() == src && !persistence_active_operation && !persistence_save_in_progress && !persistence_load_recovery_required

/obj/item/tree_cutting/afterattack(atom/target, mob/user, proximity_flag, params)
	if (proximity_flag && isturf(target))
		plant_cutting(target, user)

/obj/item/tree_cutting/proc/plant_cutting(turf/T, mob/user)
	if (!can_handle_cutting(user) || !T || !user.Adjacent(T))
		return FALSE
	var/site_error = tree_planting_error(T)
	if (site_error)
		to_chat(user, SPAN_WARNING(site_error))
		return FALSE
	new /obj/structure/farming/plant/tree(T)
	var/mob/living/human/H = user
	H.adaptStat("farming", 1)
	qdel(src)
	to_chat(user, SPAN_NOTICE("You plant the tree cutting. Keep it watered as it grows."))
	return TRUE

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
		if (!QDELETED(S) && S.amount >= 1 && (istype(S, /obj/item/stack/sinew) || istype(S, /obj/item/stack/material/rope) || istype(S, /obj/item/stack/crude_twine)))
			return S

/obj/item/weapon/branch/proc/axe_parts_valid(mob/user, obj/item/weapon/flint/head, obj/item/stack/binding)
	return !QDELETED(src) && !QDELETED(user) && !QDELETED(head) && !QDELETED(binding) && sharpened && head.sharpened && user.stat == CONSCIOUS && (loc == user || loc == get_turf(user)) && head.loc == user && binding.amount >= 1 && (binding.loc == user || binding.loc == get_turf(user)) && (istype(binding, /obj/item/stack/sinew) || istype(binding, /obj/item/stack/material/rope) || istype(binding, /obj/item/stack/crude_twine))

/obj/item/weapon/branch/proc/axe_assembly_wait(mob/user)
	return do_after(user, 100, src)

/obj/item/weapon/branch/proc/axe_actor_connected(mob/user)
	// An agent-controlled character has no client but is driven like a player.
	return user && (user.client || agent_character_for(user))

// Keep the original ground output if the actor cannot take it immediately.
/proc/offer_crafted_axe_to_active_hand(mob/user, obj/item/axe)
	if (QDELETED(user) || QDELETED(axe) || user.stat != CONSCIOUS || user.incapacitated() || !isturf(user.loc) || axe.loc != user.loc || user.get_active_hand())
		return FALSE
	return user.put_in_active_hand(axe)

/obj/item/weapon/branch/proc/assemble_flint_axe(mob/user, obj/item/weapon/flint/head)
	if (!user || !user.may_do_after)
		return
	if (assembling_axe || !axe_actor_connected(user))
		return
	var/obj/item/stack/binding = axe_binding(user)
	if (!binding)
		to_chat(user, SPAN_WARNING("You need one portion of sinew, rope or crude twine in your inventory or on the ground beneath you to bind the axe head."))
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
	var/weak_binding = istype(binding, /obj/item/stack/crude_twine)
	if (!binding.use(1))
		return
	// Invalidate the reusable head before creating the completed tool.
	head.sharpened = FALSE
	qdel(head)
	var/obj/item/weapon/material/hatchet/tribal/flint/axe = new(get_turf(user))
	if (weak_binding)
		axe.maxhealth = max(1, axe.maxhealth * 0.25)
		axe.health = axe.maxhealth
		axe.desc += " Its crude grass binding wears out quickly."
	to_chat(user, SPAN_NOTICE("You finish making the bound flint axe."))
	qdel(src)
	offer_crafted_axe_to_active_hand(user, axe)

/obj/item/weapon/branch/attack_self(mob/living/human/user as mob)
	if (ants)
		if (!user.may_do_after)
			return
		to_chat(user, SPAN_NOTICE("You start licking some ants off the stick..."))
		if (do_after(user, 50, src))
			if (src && ants)
				to_chat(user, SPAN_NOTICE("You finish eating some ants."))
				icon_state = "sharpened_stick"
				ants = FALSE
				if (user.gorillaman)
					user.adjust_mood(10, "eating ants")
				else if (user.ant)
					user.adjust_mood(-(20), "eating ants")
				else if (!user.orc && !user.crab)
					user.adjust_mood(-(10), "eating ants")
				user.nutrition += 80
				return
	else
		..()

/obj/item/weapon/branch/attackby(obj/item/weapon/W as obj, mob/user as mob)
	if (W.edge && !sharpened)
		if (!user || !user.may_do_after)
			return
		to_chat(user, "You start sharpening the stick...")
		if (do_after(user, 80, src))
			if (src && !sharpened)
				to_chat(user, "You finish sharpening the stick.")
				tutorial_event_for(user, "whittle")
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
