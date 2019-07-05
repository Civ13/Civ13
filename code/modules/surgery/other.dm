//////////////////////////////////////////////////////////////////
//					INTERNAL WOUND PATCHING						//
//////////////////////////////////////////////////////////////////

//////////////////////////////////////////////////////////////////
//	 IB fixing step
//////////////////////////////////////////////////////////////////
/datum/surgery_step/fix_vein
	priority = 2
	allowed_tools = list(
		1 = list("/obj/item/weapon/surgery/hemostat",100),
		2 = list("/obj/item/weapon/surgery/hemostat/bronze",85),
		3 = list("/obj/item/stack/material/rope",50),
	)
	can_infect = TRUE
	blood_level = TRUE

	min_duration = 70
	max_duration = 90

	can_use(mob/living/user, mob/living/carbon/human/target, target_zone, obj/item/tool)
		if (!hasorgans(target))
			return FALSE

		var/obj/item/organ/external/affected = target.get_organ(target_zone)
		if (!affected) return
		var/internal_bleeding = FALSE
		for (var/datum/wound/W in affected.wounds) if (W.internal)
			internal_bleeding = TRUE
			break

		return affected.open == 2 && internal_bleeding

	begin_step(mob/user, mob/living/carbon/human/target, target_zone, obj/item/tool)
		var/obj/item/organ/external/affected = target.get_organ(target_zone)
		user.visible_message("[user] starts pinching the damaged [affected.artery_name] in [target]'s [affected.name] with \the [tool]." , \
		"You start pinching the damaged [affected.artery_name] in [target]'s [affected.name] with \the [tool].")
		target.custom_pain("The pain in [affected.name] is unbearable!",100)
		..()

	end_step(mob/living/user, mob/living/carbon/human/target, target_zone, obj/item/tool)
		var/obj/item/organ/external/affected = target.get_organ(target_zone)
		user.visible_message("<span class = 'notice'>[user] has pinched the damaged [affected.artery_name] in [target]'s [affected.name] with \the [tool].</span>", \
			"<span class = 'notice'>You have pinched the damaged [affected.artery_name] in [target]'s [affected.name] with \the [tool].</span>")

		for (var/datum/wound/W in affected.wounds) if (W.internal)
			affected.wounds -= W
			affected.update_damages()
		if (ishuman(user) && prob(40)) user:bloody_hands(target, FALSE)

	fail_step(mob/living/user, mob/living/carbon/human/target, target_zone, obj/item/tool)
		var/obj/item/organ/external/affected = target.get_organ(target_zone)
		user.visible_message("<span class = 'red'>[user]'s hand slips, smearing [tool] in the incision in [target]'s [affected.name]!</span>" , \
		"<span class = 'red'>Your hand slips, smearing [tool] in the incision in [target]'s [affected.name]!</span>")
		affected.take_damage(5, FALSE)

//////////////////////////////////////////////////////////////////
//	 Necrosis treatment
//////////////////////////////////////////////////////////////////
/datum/surgery_step/fix_dead_tissue		//Debridement
	priority = 2
	allowed_tools = list(
		1 = list("/obj/item/weapon/surgery/scalpel",100),
		2 = list("/obj/item/weapon/surgery/scalpel/bronze",85),
		3 = list("/obj/item/weapon/material/knife",75),
		4 = list("/obj/item/weapon/material/shard",50),
	)

	can_infect = TRUE
	blood_level = 1

	min_duration = 110
	max_duration = 160

	can_use(mob/living/user, mob/living/carbon/human/target, target_zone, obj/item/tool)
		if (!hasorgans(target))
			return FALSE

		if (target_zone == "mouth" || target_zone == "eyes")
			return FALSE

		var/obj/item/organ/external/affected = target.get_organ(target_zone)

		return affected && affected.open >= 2 && (affected.status & ORGAN_DEAD)

	begin_step(mob/user, mob/living/carbon/human/target, target_zone, obj/item/tool)
		var/obj/item/organ/external/affected = target.get_organ(target_zone)
		user.visible_message("[user] starts cutting away necrotic tissue in [target]'s [affected.name] with \the [tool]." , \
		"You start cutting away necrotic tissue in [target]'s [affected.name] with \the [tool].")
		target.custom_pain("The pain in [affected.name] is unbearable!",100)
		..()

	end_step(mob/living/user, mob/living/carbon/human/target, target_zone, obj/item/tool)
		var/obj/item/organ/external/affected = target.get_organ(target_zone)
		user.visible_message("<span class = 'notice'>[user] has cut away necrotic tissue in [target]'s [affected.name] with \the [tool].</span>", \
			"<span class = 'notice'>You have cut away necrotic tissue in [target]'s [affected.name] with \the [tool].</span>")
		affected.status &= ~ORGAN_DEAD
		playsound(target.loc, 'sound/effects/squelch1.ogg', 50, TRUE)

	fail_step(mob/living/user, mob/living/carbon/human/target, target_zone, obj/item/tool)
		var/obj/item/organ/external/affected = target.get_organ(target_zone)
		user.visible_message("<span class = 'red'>[user]'s hand slips, slicing an artery inside [target]'s [affected.name] with \the [tool]!</span>", \
		"<span class = 'red'>Your hand slips, slicing an artery inside [target]'s [affected.name] with \the [tool]!</span>")
		affected.createwound(CUT, 20, TRUE)

/datum/surgery_step/treat_necrosis
	priority = 2
	allowed_tools = list(
		1 = list("/obj/item/weapon/reagent_containers/dropper",100),
		2 = list("/obj/item/weapon/reagent_containers/glass/bottle",75),
		3 = list("/obj/item/weapon/reagent_containers/glass/bucket",50),
	)

	can_infect = FALSE
	blood_level = FALSE

	min_duration = 50
	max_duration = 60

	can_use(mob/living/user, mob/living/carbon/human/target, target_zone, obj/item/tool)
		if (!istype(tool, /obj/item/weapon/reagent_containers))
			return FALSE

		var/obj/item/weapon/reagent_containers/container = tool
		if (!container.reagents.has_reagent("peridaxon"))
			return FALSE

		if (!hasorgans(target))
			return FALSE

		if (target_zone == "mouth" || target_zone == "eyes")
			return FALSE

		var/obj/item/organ/external/affected = target.get_organ(target_zone)
		return affected && affected.open == 3 && (affected.status & ORGAN_DEAD)

	begin_step(mob/user, mob/living/carbon/human/target, target_zone, obj/item/tool)
		var/obj/item/organ/external/affected = target.get_organ(target_zone)
		user.visible_message("[user] starts applying medication to the affected tissue in [target]'s [affected.name] with \the [tool]." , \
		"You start applying medication to the affected tissue in [target]'s [affected.name] with \the [tool].")
		target.custom_pain("Something in your [affected.name] is causing you a lot of pain!",250)
		..()

	end_step(mob/living/user, mob/living/carbon/human/target, target_zone, obj/item/tool)
		var/obj/item/organ/external/affected = target.get_organ(target_zone)

		if (!istype(tool, /obj/item/weapon/reagent_containers))
			return

		var/obj/item/weapon/reagent_containers/container = tool

		var/trans = container.reagents.trans_to_mob(target, container.amount_per_transfer_from_this, CHEM_BLOOD) //technically it's contact, but the reagents are being applied to internal tissue
		if (trans > 0)

			if (container.reagents.has_reagent("peridaxon"))
				affected.status &= ~ORGAN_DEAD

			user.visible_message("<span class = 'notice'>[user] applies [trans] units of the solution to affected tissue in [target]'s [affected.name]</span>", \
				"<span class = 'notice'>You apply [trans] units of the solution to affected tissue in [target]'s [affected.name] with \the [tool].</span>")

	fail_step(mob/living/user, mob/living/carbon/human/target, target_zone, obj/item/tool)
		var/obj/item/organ/external/affected = target.get_organ(target_zone)

		if (!istype(tool, /obj/item/weapon/reagent_containers))
			return

		var/obj/item/weapon/reagent_containers/container = tool

		var/trans = container.reagents.trans_to_mob(target, container.amount_per_transfer_from_this, CHEM_BLOOD)

		user.visible_message("<span class = 'red'>[user]'s hand slips, applying [trans] units of the solution to the wrong place in [target]'s [affected.name] with the [tool]!</span>" , \
		"<span class = 'red'>Your hand slips, applying [trans] units of the solution to the wrong place in [target]'s [affected.name] with the [tool]!</span>")

		//no damage or anything, just wastes medicine

//////////////////////////////////////////////////////////////////
//	 Tendon fix surgery step
//////////////////////////////////////////////////////////////////
/datum/surgery_step/fix_tendon
	priority = 2
	allowed_tools = list(
		1 = list("/obj/item/weapon/surgery/hemostat",100),
		2 = list("/obj/item/weapon/surgery/hemostat/bronze",85),
		3 = list("/obj/item/stack/material/rope",50),
	)
	can_infect = 1
	blood_level = 1

	min_duration = 70
	max_duration = 90

/datum/surgery_step/fix_tendon/can_use(mob/living/user, mob/living/carbon/human/target, target_zone, obj/item/tool)
	if(!hasorgans(target))
		return 0
	var/obj/item/organ/external/affected = target.get_organ(target_zone)
	return affected && (affected.status & ORGAN_TENDON_CUT) && affected.open == 1

/datum/surgery_step/fix_tendon/begin_step(mob/user, mob/living/carbon/human/target, target_zone, obj/item/tool)
	var/obj/item/organ/external/affected = target.get_organ(target_zone)
	user.visible_message("[user] starts reattaching the damaged [affected.tendon_name] in [target]'s [affected.name] with \the [tool]." , \
	"You start reattaching the damaged [affected.tendon_name] in [target]'s [affected.name] with \the [tool].")
	target.custom_pain("The pain in your [affected.name] is unbearable!",100,affecting = affected)
	..()

/datum/surgery_step/fix_tendon/end_step(mob/living/user, mob/living/carbon/human/target, target_zone, obj/item/tool)
	var/obj/item/organ/external/affected = target.get_organ(target_zone)
	user.visible_message("<span class='notice'>[user] has reattached the [affected.tendon_name] in [target]'s [affected.name] with \the [tool].</span>", \
		"<span class='notice'>You have reattached the [affected.tendon_name] in [target]'s [affected.name] with \the [tool].</span>")
	affected.status &= ~ORGAN_TENDON_CUT
	affected.update_damages()

/datum/surgery_step/fix_tendon/fail_step(mob/living/user, mob/living/carbon/human/target, target_zone, obj/item/tool)
	var/obj/item/organ/external/affected = target.get_organ(target_zone)
	user.visible_message("<span class='warning'>[user]'s hand slips, smearing [tool] in the incision in [target]'s [affected.name]!</span>" , \
	"<span class='warning'>Your hand slips, smearing [tool] in the incision in [target]'s [affected.name]!</span>")
	affected.take_damage(5, used_weapon = tool)

//////////////////////////////////////////////////////////////////
//	 Disinfection step
//////////////////////////////////////////////////////////////////
/datum/surgery_step/sterilize
	priority = 2
	allowed_tools = list(
		1 = list("/obj/item/stack/medical/advanced/sulfa",100),
		2 = list("/obj/item/stack/medical/advanced/bruise_pack",75),
		3 = list("/obj/item/stack/medical/advanced/ointment",55),
		4 = list("/obj/item/weapon/reagent_containers/glass/bucket",30),
	)

	can_infect = 0
	blood_level = 0

	min_duration = 50
	max_duration = 60

/datum/surgery_step/sterilize/can_use(mob/living/user, mob/living/carbon/human/target, target_zone, obj/item/tool)
	if(!hasorgans(target))
		return 0
	var/obj/item/organ/external/affected = target.get_organ(target_zone)
	if(!istype(affected))
		return 0
	if(affected.is_disinfected())
		return 0
	var/obj/item/weapon/reagent_containers/container = tool
	if(!istype(container))
		return 0
	if(!container.is_open_container())
		return 0
	var/datum/reagent/ethanol/booze = locate() in container.reagents.reagent_list
	if(istype(booze) && booze.strength >= 40)
		to_chat(user, "<span class='warning'>[booze] is too weak, you need something of higher proof for this...</span>")
		return 0
	if(!istype(booze) && !container.reagents.has_reagent("sterilizine"))
		return 0
	return 1

/datum/surgery_step/sterilize/begin_step(mob/user, mob/living/carbon/human/target, target_zone, obj/item/tool)
	var/obj/item/organ/external/affected = target.get_organ(target_zone)
	user.visible_message("[user] starts pouring [tool]'s contents on \the [target]'s [affected.name]." , \
	"You start pouring [tool]'s contents on \the [target]'s [affected.name].")
	target.custom_pain("Your [affected.name] is on fire!",50,affecting = affected)
	..()

/datum/surgery_step/sterilize/end_step(mob/living/user, mob/living/carbon/human/target, target_zone, obj/item/tool)
	var/obj/item/organ/external/affected = target.get_organ(target_zone)

	if (!istype(tool, /obj/item/weapon/reagent_containers))
		return

	var/obj/item/weapon/reagent_containers/container = tool

	var/amount = container.amount_per_transfer_from_this
	var/datum/reagents/temp = new(amount)
	container.reagents.trans_to_holder(temp, amount)

	var/trans = temp.trans_to_mob(target, temp.total_volume, CHEM_BLOOD) //technically it's contact, but the reagents are being applied to internal tissue
	if (trans > 0)
		user.visible_message("<span class='notice'>[user] rubs [target]'s [affected.name] down with \the [tool]'s contents</span>.", \
			"<span class='notice'>You rub [target]'s [affected.name] down with \the [tool]'s contents.</span>")

/datum/surgery_step/sterilize/fail_step(mob/living/user, mob/living/carbon/human/target, target_zone, obj/item/tool)
	var/obj/item/organ/external/affected = target.get_organ(target_zone)

	if (!istype(tool, /obj/item/weapon/reagent_containers))
		return

	var/obj/item/weapon/reagent_containers/container = tool

	container.reagents.trans_to_mob(target, container.amount_per_transfer_from_this, CHEM_BLOOD)

	user.visible_message("<span class='warning'>[user]'s hand slips, splilling \the [tool]'s contents over the [target]'s [affected.name]!</span>" , \
	"<span class='warning'>Your hand slips, splilling \the [tool]'s contents over the [target]'s [affected.name]!</span>")
	affected.disinfect()

