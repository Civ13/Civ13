//Procedures in this file: limbs attachment
//////////////////////////////////////////////////////////////////
//						LIMB SURGERY							//
//////////////////////////////////////////////////////////////////

/datum/surgery_step/limb
	priority = 3 // Must be higher than /datum/surgery_step/internal
	req_open = FALSE
	can_infect = FALSE
	can_use(mob/living/user, mob/living/human/target, target_zone, obj/item/tool)
		if (!hasorgans(target))
			return FALSE
		var/obj/item/organ/external/affected = target.get_organ(target_zone)
		if (affected)
			return FALSE
		var/list/organ_data = target.species.has_limbs["[target_zone]"]
		return !isnull(organ_data)

// Check every external organ that replaced() will register from the donor,
// including children carried as direct contents rather than as attached limbs.
/obj/item/organ/external/proc/graft_slots_clear(mob/living/human/target, list/seen, inside_slot = null)
	if (QDELETED(src) || owner || is_stump() || !limb_name || seen[limb_name] || target.get_organ(limb_name) || !target.species.has_limbs[limb_name])
		return FALSE
	if (!isnull(inside_slot) && parent_organ != inside_slot)
		return FALSE
	seen[limb_name] = TRUE
	for (var/obj/item/organ/external/child in src)
		if (!child.graft_slots_clear(target, seen, limb_name))
			return FALSE
	return TRUE

/datum/surgery_step/limb/attach
	allowed_tools = alist(1 = list("/obj/item/organ/external",100))

	min_duration = 50
	max_duration = 70

	can_use(mob/living/user, mob/living/human/target, target_zone, obj/item/tool)
		if (!..())
			return FALSE
		var/obj/item/organ/external/E = tool
		if (!istype(E) || E.limb_name != target_zone)
			to_chat(user, "<span class='warning'>That limb does not match the selected body part.</span>")
			return SURGERY_FAILURE
		if (E.parent_organ)
			var/obj/item/organ/external/parent = target.get_organ(E.parent_organ)
			if (QDELETED(parent) || parent.is_stump() || parent.owner != target || parent.loc != target)
				to_chat(user, "<span class='warning'>The body part this limb connects to must be attached first.</span>")
				return SURGERY_FAILURE
		if (!E.graft_slots_clear(target, list()))
			to_chat(user, "<span class='warning'>The donor limb or one of its attached parts cannot be fitted here.</span>")
			return SURGERY_FAILURE
		return TRUE

	begin_step(mob/user, mob/living/human/target, target_zone, obj/item/tool)
		var/obj/item/organ/external/E = tool
		user.visible_message("[user] starts attaching [E.name] to [target]'s [E.amputation_point].", \
		"You start attaching [E.name] to [target]'s [E.amputation_point].")

	end_step(mob/living/user, mob/living/human/target, target_zone, obj/item/tool)
		// A parent or child can change while the other surgery zone is reserved.
		if (QDELETED(tool) || tool.loc != user || can_use(user, target, target_zone, tool) != TRUE)
			to_chat(user, "<span class='warning'>The limb can no longer be attached there.</span>")
			return
		var/obj/item/organ/external/E = tool
		if (!user.drop_from_inventory(E))
			return
		E.replaced(target)
		user.visible_message("<span class='notice'>[user] has attached [target]'s [E.name] to the [E.amputation_point].</span>",	\
		"<span class='notice'>You have attached [target]'s [E.name] to the [E.amputation_point].</span>")
		target.update_body()
		target.updatehealth()
		target.UpdateDamageIcon()

	fail_step(mob/living/user, mob/living/human/target, target_zone, obj/item/tool)
		var/obj/item/organ/external/E = tool
		user.visible_message("<span class='warning'> [user]'s hand slips, damaging [target]'s [E.amputation_point]!</span>", \
		"<span class='warning'> Your hand slips, damaging [target]'s [E.amputation_point]!</span>")
		target.apply_damage(10, BRUTE, null, sharp=1)

/datum/surgery_step/limb/connect
	allowed_tools = alist(
		1 = list("/obj/item/weapon/surgery/hemostat",100),
		2 = list("/obj/item/weapon/surgery/hemostat/bronze",85),
		3 = list("/obj/item/stack/material/rope",50),
	)
	can_infect = TRUE

	min_duration = 100
	max_duration = 120

	can_use(mob/living/user, mob/living/human/target, target_zone, obj/item/tool)
		var/obj/item/organ/external/E = target.get_organ(target_zone)
		return E && !E.is_stump() && (E.status & ORGAN_DESTROYED)

	begin_step(mob/user, mob/living/human/target, target_zone, obj/item/tool)
		var/obj/item/organ/external/E = target.get_organ(target_zone)
		user.visible_message("[user] starts connecting tendons and muscles in [target]'s [E.amputation_point] with [tool].", \
		"You start connecting tendons and muscle in [target]'s [E.amputation_point].")

	end_step(mob/living/user, mob/living/human/target, target_zone, obj/item/tool)
		var/obj/item/organ/external/E = target.get_organ(target_zone)
		user.visible_message("<span class='notice'>[user] has connected tendons and muscles in [target]'s [E.amputation_point] with [tool].</span>",	\
		"<span class='notice'>You have connected tendons and muscles in [target]'s [E.amputation_point] with [tool].</span>")
		E.status &= ~ORGAN_DESTROYED
		if (E.children)
			for (var/obj/item/organ/external/C in E.children)
				C.status &= ~ORGAN_DESTROYED
		target.update_body()
		target.updatehealth()
		target.UpdateDamageIcon()

	fail_step(mob/living/user, mob/living/human/target, target_zone, obj/item/tool)
		var/obj/item/organ/external/E = target.get_organ(target_zone)
		user.visible_message("<span class='warning'> [user]'s hand slips, damaging [target]'s [E.amputation_point]!</span>", \
		"<span class='warning'> Your hand slips, damaging [target]'s [E.amputation_point]!</span>")
		target.apply_damage(10, BRUTE, null, sharp=1)
