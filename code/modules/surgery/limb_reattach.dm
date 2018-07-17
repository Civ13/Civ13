//Procedures in this file: Robotic limbs attachment, meat limbs attachment
//////////////////////////////////////////////////////////////////
//						LIMB SURGERY							//
//////////////////////////////////////////////////////////////////

/datum/surgery_step/limb/
	priority = 3 // Must be higher than /datum/surgery_step/internal
	can_infect = FALSE
	can_use(mob/living/user, mob/living/carbon/human/target, target_zone, obj/item/tool)
		if (!hasorgans(target))
			return FALSE
		var/obj/item/organ/external/affected = target.get_organ(target_zone)
		if (affected)
			return FALSE
		var/list/organ_data = target.species.has_limbs["[target_zone]"]
		return !isnull(organ_data)

/datum/surgery_step/limb/attach
	allowed_tools = list(/obj/item/organ/external = 100)

	min_duration = 50
	max_duration = 70

	begin_step(mob/user, mob/living/carbon/human/target, target_zone, obj/item/tool)
		var/obj/item/organ/external/E = tool
		user.visible_message("[user] starts attaching [E.name] to [target]'s [E.amputation_point].", \
		"You start attaching [E.name] to [target]'s [E.amputation_point].")

	end_step(mob/living/user, mob/living/carbon/human/target, target_zone, obj/item/tool)
		var/obj/item/organ/external/E = tool
		user.visible_message("<span class='notice'>[user] has attached [target]'s [E.name] to the [E.amputation_point].</span>",	\
		"<span class='notice'>You have attached [target]'s [E.name] to the [E.amputation_point].</span>")
		user.drop_from_inventory(E)
		E.replaced(target)
		target.update_body()
		target.updatehealth()
		target.UpdateDamageIcon()

	fail_step(mob/living/user, mob/living/carbon/human/target, target_zone, obj/item/tool)
		var/obj/item/organ/external/E = tool
		user.visible_message("<span class='warning'> [user]'s hand slips, damaging [target]'s [E.amputation_point]!</span>", \
		"<span class='warning'> Your hand slips, damaging [target]'s [E.amputation_point]!</span>")
		target.apply_damage(10, BRUTE, null, sharp=1)

/datum/surgery_step/limb/connect
	allowed_tools = list(
	/obj/item/weapon/hemostat = 100,	\
	/obj/item/stack/cable_coil = 75, 	\
	/obj/item/assembly/mousetrap = 20
	)
	can_infect = TRUE

	min_duration = 100
	max_duration = 120

	can_use(mob/living/user, mob/living/carbon/human/target, target_zone, obj/item/tool)
		var/obj/item/organ/external/E = target.get_organ(target_zone)
		return E && !E.is_stump() && (E.status & ORGAN_DESTROYED)

	begin_step(mob/user, mob/living/carbon/human/target, target_zone, obj/item/tool)
		var/obj/item/organ/external/E = target.get_organ(target_zone)
		user.visible_message("[user] starts connecting tendons and muscles in [target]'s [E.amputation_point] with [tool].", \
		"You start connecting tendons and muscle in [target]'s [E.amputation_point].")

	end_step(mob/living/user, mob/living/carbon/human/target, target_zone, obj/item/tool)
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

	fail_step(mob/living/user, mob/living/carbon/human/target, target_zone, obj/item/tool)
		var/obj/item/organ/external/E = tool
		user.visible_message("<span class='warning'> [user]'s hand slips, damaging [target]'s [E.amputation_point]!</span>", \
		"<span class='warning'> Your hand slips, damaging [target]'s [E.amputation_point]!</span>")
		target.apply_damage(10, BRUTE, null, sharp=1)
