// Internal surgeries.
/datum/surgery_step/internal
	priority = 2
	can_infect = TRUE
	blood_level = TRUE

/datum/surgery_step/internal/can_use(mob/living/user, mob/living/human/target, target_zone, obj/item/tool)
	return operation_site_open(target, target_zone)

/datum/surgery_step/internal/proc/operation_site_open(mob/living/human/target, target_zone)
	if (!hasorgans(target))
		return FALSE

	var/obj/item/organ/external/affected = target.get_organ(target_zone)
	return affected && affected.open == (affected.encased ? 3 : 2)


// Bind a choice to the exact organ seen by this action, not just its display name.
/datum/surgery_step/internal/proc/select_organ(mob/living/user, mob/living/human/target, target_zone, obj/item/tool, cut_away)
	var/datum/surgery_status/stage = target.op_stage
	var/list/options = list()
	var/list/organs = list()
	for (var/tag in target.internal_organs_by_name)
		var/obj/item/organ/I = target.internal_organs_by_name[tag]
		if (organ_matches_selection(target, target_zone, I, cut_away))
			options += tag
			organs[tag] = I
	if (!options.len)
		return FALSE
	var/choice = player_input(user, cut_away ? "Which organ do you want to remove?" : "Which organ do you want to prepare for removal?", null, null, "anything", options, TRUE)
	if (!(choice in options) || QDELETED(user) || QDELETED(target) || QDELETED(tool) || target.op_stage != stage || !(target_zone in stage.in_progress))
		return SURGERY_FAILURE
	if (!user.Adjacent(target) || !(tool in user.contents) || user.a_intent == I_HARM)
		return SURGERY_FAILURE
	var/obj/item/organ/selected = organs[choice]
	if (!organ_matches_selection(target, target_zone, selected, cut_away))
		return SURGERY_FAILURE
	stage.selected_organs[target_zone] = selected
	return TRUE

/datum/surgery_step/internal/proc/organ_matches_selection(mob/living/human/target, target_zone, obj/item/organ/I, cut_away)
	if (QDELETED(I) || I.parent_organ != target_zone || target.internal_organs_by_name[I.organ_tag] != I || !operation_site_open(target, target_zone))
		return FALSE
	if (I.status & ORGAN_CUT_AWAY)
		return cut_away
	return !cut_away

/datum/surgery_step/internal/proc/current_zone_selection(mob/living/human/target, target_zone, cut_away)
	var/obj/item/organ/selected = target.op_stage.selected_organs[target_zone]
	if (organ_matches_selection(target, target_zone, selected, cut_away))
		return selected
	return null

//////////////////////////////////////////////////////////////////
//				CHEST INTERNAL ORGAN SURGERY					//
//////////////////////////////////////////////////////////////////
/datum/surgery_step/internal/fix_organ
	allowed_tools = alist(
		1 = list("/obj/item/stack/medical/advanced/bruise_pack",100),
		2 = list("/obj/item/stack/medical/advanced/herbs",100),
		3 = list("/obj/item/stack/medical/bruise_pack",100),
	)

	min_duration = 70
	max_duration = 90

	can_use(mob/living/user, mob/living/human/target, target_zone, obj/item/tool)

		if (!hasorgans(target))
			return
		var/obj/item/organ/external/affected = target.get_organ(target_zone)
		if (!affected)
			return
		var/is_organ_damaged = FALSE
		for (var/obj/item/organ/I in affected.internal_organs)
			if (I.damage > 0)
				is_organ_damaged = TRUE
				break
		return ..() && is_organ_damaged

	begin_step(mob/user, mob/living/human/target, target_zone, obj/item/tool)
		var/tool_name = "\the [tool]"
		if (istype(tool, /obj/item/stack/medical/advanced/bruise_pack))
			tool_name = "healing ointment"
		else if (istype(tool, /obj/item/stack/medical/bruise_pack))
			tool_name = "the bandage"

		if (!hasorgans(target))
			return
		var/obj/item/organ/external/affected = target.get_organ(target_zone)
		if(!affected || affected.open < 2)
			return
		for (var/obj/item/organ/I in affected.internal_organs)
			if (I && I.damage > 0)
				user.visible_message("[user] starts treating damage to [target]'s [I.name] with [tool_name].", \
				"You start treating damage to [target]'s [I.name] with [tool_name]." )

		target.custom_pain("The pain in your [affected.name] is living hell!",200)
		..()

	end_step(mob/living/user, mob/living/human/target, target_zone, obj/item/tool)
		var/tool_name = "\the [tool]"
		if (istype(tool, /obj/item/stack/medical/advanced/bruise_pack))
			tool_name = "healing ointment"
		if (istype(tool, /obj/item/stack/medical/bruise_pack))
			tool_name = "the bandage"

		if (!hasorgans(target))
			return
		var/obj/item/organ/external/affected = target.get_organ(target_zone)
		if(!affected || affected.open < 2)
			return
		for (var/obj/item/organ/I in affected.internal_organs)
			if (I && I.damage > 0)
				user.visible_message("<span class='notice'>[user] treats damage to [target]'s [I.name] with [tool_name].</span>", \
				"<span class='notice'>You treat damage to [target]'s [I.name] with [tool_name].</span>" )
				I.damage = FALSE
				target.shock_stage *= 0.5

	fail_step(mob/living/user, mob/living/human/target, target_zone, obj/item/tool)

		if (!hasorgans(target))
			return
		var/obj/item/organ/external/affected = target.get_organ(target_zone)

		user.visible_message("<span class='warning'>[user]'s hand slips, getting mess and tearing the inside of [target]'s [affected.name] with \the [tool]!</span>", \
		"<span class='warning'>Your hand slips, getting mess and tearing the inside of [target]'s [affected.name] with \the [tool]!</span>")
		var/dam_amt = 2

		if (istype(tool, /obj/item/stack/medical/advanced/bruise_pack))
			target.adjustToxLoss(5)

		else if (istype(tool, /obj/item/stack/medical/bruise_pack))
			dam_amt = 5
			target.adjustToxLoss(10)
			affected.createwound(CUT, 5)

		for (var/obj/item/organ/I in affected.internal_organs)
			if (I && I.damage > 0)
				I.take_damage(dam_amt,0)

/datum/surgery_step/internal/detatch_organ

	allowed_tools = alist(
		1 = list("/obj/item/weapon/surgery/scalpel",100),
		2 = list("/obj/item/weapon/surgery/scalpel/bronze",85),
		3 = list("/obj/item/weapon/material/kitchen/utensil/knife",75),
		4 = list("/obj/item/weapon/material/shard",50),
		5 = list("/obj/item/weapon/material/kitchen/utensil/knife/bone",70),
	)

	min_duration = 90
	max_duration = 110

	can_use(mob/living/user, mob/living/human/target, target_zone, obj/item/tool)

		if (!..())
			return FALSE
		return select_organ(user, target, target_zone, tool, FALSE)

	begin_step(mob/user, mob/living/human/target, target_zone, obj/item/tool)
		var/obj/item/organ/selected = target.op_stage.selected_organs[target_zone]
		user.visible_message("[user] starts to separate [target]'s [selected.organ_tag] with \the [tool].", \
		"You start to separate [target]'s [selected.organ_tag] with \the [tool].")
		var/obj/item/organ/external/affected = target.get_organ(target_zone)
		target.custom_pain("The pain in your [affected.name] is living hell!",200)
		..()

	end_step(mob/living/user, mob/living/human/target, target_zone, obj/item/tool)
		var/obj/item/organ/selected = current_zone_selection(target, target_zone, FALSE)
		if (!selected)
			return
		user.visible_message("<span class='notice'>[user] has separated [target]'s [selected.organ_tag] with \the [tool].</span>", \
		"<span class='notice'>You have separated [target]'s [selected.organ_tag] with \the [tool].</span>")
		selected.status |= ORGAN_CUT_AWAY

	fail_step(mob/living/user, mob/living/human/target, target_zone, obj/item/tool)
		var/obj/item/organ/external/affected = target.get_organ(target_zone)
		user.visible_message("<span class='warning'>[user]'s hand slips, slicing an artery inside [target]'s [affected.name] with \the [tool]!</span>", \
		"<span class='warning'>Your hand slips, slicing an artery inside [target]'s [affected.name] with \the [tool]!</span>")
		affected.createwound(CUT, rand(30,50), TRUE)

/datum/surgery_step/internal/remove_organ

	allowed_tools = alist(
		1 = list("/obj/item/weapon/surgery/hemostat",100),
		2 = list("/obj/item/weapon/surgery/hemostat/bronze",85),
		3 = list("/obj/item/weapon/material/kitchen/utensil/fork",20),
		4 = list("/obj/item/weapon/material/kitchen/utensil/knife/bone",70),
		5 = list("/obj/item/weapon/material/kitchen/utensil/knife/",50),
	)

	min_duration = 60
	max_duration = 80

	can_use(mob/living/user, mob/living/human/target, target_zone, obj/item/tool)

		if (!..())
			return FALSE
		return select_organ(user, target, target_zone, tool, TRUE)

	begin_step(mob/user, mob/living/human/target, target_zone, obj/item/tool)
		var/obj/item/organ/selected = target.op_stage.selected_organs[target_zone]
		user.visible_message("[user] starts removing [target]'s [selected.organ_tag] with \the [tool].", \
		"You start to remove [target]'s [selected.organ_tag] with \the [tool].")
		target.custom_pain("Someone's ripping out your [selected.organ_tag]!",200)
		..()

	end_step(mob/living/user, mob/living/human/target, target_zone, obj/item/tool)
		var/obj/item/organ/selected = current_zone_selection(target, target_zone, TRUE)
		if (!selected)
			return
		user.visible_message("<span class='notice'>[user] has removed [target]'s [selected.organ_tag] with \the [tool].</span>", \
		"<span class='notice'>You have removed [target]'s [selected.organ_tag] with \the [tool].</span>")
		selected.removed(user)
		playsound(target.loc, 'sound/effects/squelch1.ogg', 50, TRUE)

	fail_step(mob/living/user, mob/living/human/target, target_zone, obj/item/tool)
		var/obj/item/organ/external/affected = target.get_organ(target_zone)
		user.visible_message("<span class='warning'>[user]'s hand slips, damaging [target]'s [affected.name] with \the [tool]!</span>", \
		"<span class='warning'>Your hand slips, damaging [target]'s [affected.name] with \the [tool]!</span>")
		affected.createwound(BRUISE, 20)

/datum/surgery_step/internal/replace_organ
	allowed_tools = alist(1 = list("/obj/item/organ",100))

	min_duration = 60
	max_duration = 80

	can_use(mob/living/user, mob/living/human/target, target_zone, obj/item/tool)

		var/obj/item/organ/O = tool
		var/obj/item/organ/external/affected = target.get_organ(target_zone)
		if (!affected) return
		var/organ_compatible
		var/organ_missing

		if (!istype(O))
			return FALSE

		if (!target.species)
			to_chat(user, "<span class='danger'>You have no idea what species this person is. Report this on the bug tracker.</span>")
			return SURGERY_FAILURE

		var/o_is = (O.gender == PLURAL) ? "are" : "is"
		var/o_a =  (O.gender == PLURAL) ? "" : "a "
		var/o_do = (O.gender == PLURAL) ? "don't" : "doesn't"

		if (O.organ_tag == "limb")
			return FALSE
		else if (target.species.has_organ[O.organ_tag])

			if (O.damage > (O.max_damage * 0.75))
				to_chat(user, "<span class='warning'>\The [O.organ_tag] [o_is] in no state to be transplanted.</span>")
				return SURGERY_FAILURE

			if (!target.internal_organs_by_name[O.organ_tag])
				organ_missing = TRUE
			else
				to_chat(user, "<span class='warning'>\The [target] already has [o_a][O.organ_tag].</span>")
				return SURGERY_FAILURE

			if (O && affected.limb_name == O.parent_organ)
				organ_compatible = TRUE
			else
				to_chat(user, "<span class='warning'>\The [O.organ_tag] [o_do] normally go in \the [affected.name].</span>")
				return SURGERY_FAILURE
		else
			to_chat(user, "<span class='warning'>You're pretty sure [target.species.name_plural] don't normally have [o_a][O.organ_tag].</span>")
			return SURGERY_FAILURE

		return ..() && organ_missing && organ_compatible

	begin_step(mob/user, mob/living/human/target, target_zone, obj/item/tool)
		var/obj/item/organ/external/affected = target.get_organ(target_zone)
		user.visible_message("[user] starts transplanting \the [tool] into [target]'s [affected.name].", \
		"You start transplanting \the [tool] into [target]'s [affected.name].")
		target.custom_pain("Someone's rooting around in your [affected.name]!",80)
		var/obj/item/organ/O = tool
		if (istype(O))
			// Readable warnings only; the surgeon may still go ahead.
			if (O.germ_level >= INFECTION_LEVEL_ONE)
				to_chat(user, SPAN_WARNING("\The [O] has started to spoil and will carry an infection."))
			if (O.dna && target.dna && blood_incompatible(O.dna.b_type, target.dna.b_type, O.species, target.species))
				to_chat(user, SPAN_WARNING("\The [O] does not match [target]'s blood. The body will reject it."))
		..()

	end_step(mob/living/user, mob/living/human/target, target_zone, obj/item/tool)
		var/obj/item/organ/external/affected = target.get_organ(target_zone)
		var/obj/item/organ/O = tool
		// Two surgeons can start on one empty slot; only the first one fills it.
		if (!istype(O) || !affected || target.internal_organs_by_name[O.organ_tag] || O.loc != user || (O.status & ORGAN_DEAD))
			to_chat(user, SPAN_WARNING("You can't place \the [tool] there any more."))
			return
		user.visible_message("<span class='notice'>[user] has transplanted \the [tool] into [target]'s [affected.name].</span>", \
		"<span class='notice'>You have transplanted \the [tool] into [target]'s [affected.name].</span>")
		if (istype(O))
			user.remove_from_mob(O)
			O.replaced(target,affected)
			playsound(target.loc, 'sound/effects/squelch1.ogg', 50, TRUE)

	fail_step(mob/living/user, mob/living/human/target, target_zone, obj/item/tool)
		user.visible_message("<span class='warning'>[user]'s hand slips, damaging \the [tool]!</span>", \
		"<span class='warning'>Your hand slips, damaging \the [tool]!</span>")
		var/obj/item/organ/I = tool
		if (istype(I))
			I.take_damage(rand(3,5),0)