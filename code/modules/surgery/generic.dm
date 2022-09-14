//Procedures in this file: Gneric surgery steps
//////////////////////////////////////////////////////////////////
//						COMMON STEPS							//
//////////////////////////////////////////////////////////////////

/datum/surgery_step/generic/
	can_infect = TRUE
	can_use(mob/living/user, mob/living/human/target, target_zone, obj/item/tool)
		if (user == target)
			return FALSE
		if (target_zone == "eyes")	//there are specific steps for eye surgery
			return FALSE
		if (!hasorgans(target))
			return FALSE
		var/obj/item/organ/external/affected = target.get_organ(target_zone)
		if (affected == null)
			return FALSE
		if (affected.is_stump())
			return FALSE
		if (affected.is_stump())
			return FALSE
		return TRUE

/datum/surgery_step/generic/cut_open
	allowed_tools = list(
		1 = list("/obj/item/weapon/surgery/scalpel",100),
		2 = list("/obj/item/weapon/surgery/scalpel/bronze",85),
		3 = list("/obj/item/weapon/material/kitchen/utensil/knife",75),
		4 = list("/obj/item/weapon/material/shard",50),
		5 = list("/obj/item/weapon/material/kitchen/utensil/knife/bone",70),
	)

	min_duration = 90
	max_duration = 110

	can_use(mob/living/user, mob/living/human/target, target_zone, obj/item/tool)
		if (..())
			var/obj/item/organ/external/affected = target.get_organ(target_zone)
			return affected && affected.open == FALSE && target_zone != "mouth"

	begin_step(mob/user, mob/living/human/target, target_zone, obj/item/tool)
		var/obj/item/organ/external/affected = target.get_organ(target_zone)
		user.visible_message("[user] starts the incision on [target]'s [affected.name] with \the [tool].", \
		"You start the incision on [target]'s [affected.name] with \the [tool].")
		target.custom_pain("You feel a horrible pain as if from a sharp knife in your [affected.name]!",120)
		..()

	end_step(mob/living/user, mob/living/human/target, target_zone, obj/item/tool)
		var/obj/item/organ/external/affected = target.get_organ(target_zone)
		user.visible_message("<span class = 'notice'>[user] has made an incision on [target]'s [affected.name] with \the [tool].</span>", \
		"<span class = 'notice'>You have made an incision on [target]'s [affected.name] with \the [tool].</span>",)
		affected.open = TRUE

		if (istype(target) && !(target.species.flags & NO_BLOOD))
			affected.status |= ORGAN_BLEEDING
		playsound(target.loc, 'sound/weapons/bladeslice.ogg', 50, TRUE)

		affected.createwound(CUT, TRUE)

	fail_step(mob/living/user, mob/living/human/target, target_zone, obj/item/tool)
		var/obj/item/organ/external/affected = target.get_organ(target_zone)
		user.visible_message("<span class = 'red'>[user]'s hand slips, slicing open [target]'s [affected.name] in the wrong place with \the [tool]!</span>", \
		"<span class = 'red'>Your hand slips, slicing open [target]'s [affected.name] in the wrong place with \the [tool]!</span>")
		affected.createwound(CUT, 10)

/datum/surgery_step/generic/clamp_bleeders
	allowed_tools = list(
		1 = list("/obj/item/weapon/surgery/hemostat",100),
		2 = list("/obj/item/weapon/surgery/hemostat/bronze",85),
		3 = list("/obj/item/stack/material/rope",50),
		4 = list("/obj/item/flashlight/torch",30),
	)

	min_duration = 40
	max_duration = 60

	can_use(mob/living/user, mob/living/human/target, target_zone, obj/item/tool)
		if (..())
			var/obj/item/organ/external/affected = target.get_organ(target_zone)
			return affected && affected.open && (affected.status & ORGAN_BLEEDING)

	begin_step(mob/user, mob/living/human/target, target_zone, obj/item/tool)
		var/obj/item/organ/external/affected = target.get_organ(target_zone)
		user.visible_message("[user] starts clamping bleeders in [target]'s [affected.name] with \the [tool].", \
		"You start clamping bleeders in [target]'s [affected.name] with \the [tool].")
		target.custom_pain("The pain in your [affected.name] is maddening!",200)
		..()

	end_step(mob/living/user, mob/living/human/target, target_zone, obj/item/tool)
		var/obj/item/organ/external/affected = target.get_organ(target_zone)
		user.visible_message("<span class = 'notice'>[user] clamps bleeders in [target]'s [affected.name] with \the [tool].</span>",	\
		"<span class = 'notice'>You clamp bleeders in [target]'s [affected.name] with \the [tool].</span>")
		affected.clamping()
		spread_germs_to_organ(affected, user)

	fail_step(mob/living/user, mob/living/human/target, target_zone, obj/item/tool)
		var/obj/item/organ/external/affected = target.get_organ(target_zone)
		user.visible_message("<span class = 'red'>[user]'s hand slips, tearing blood vessals and causing massive bleeding in [target]'s [affected.name] with \the [tool]!</span>",	\
		"<span class = 'red'>Your hand slips, tearing blood vessels and causing massive bleeding in [target]'s [affected.name] with \the [tool]!</span>",)
		affected.createwound(CUT, 10)

/datum/surgery_step/generic/retract_skin
	allowed_tools = list(
		1 = list("/obj/item/weapon/surgery/retractor",100),
		2 = list("/obj/item/weapon/surgery/retractor/bronze",85),
		3 = list("/obj/item/weapon/crowbar",70),
		4 = list("/obj/item/weapon/material/handle",60),
		5 = list("/obj/item/weapon/material/kitchen/utensil/fork",50),
	)

	min_duration = 30
	max_duration = 40

	can_use(mob/living/user, mob/living/human/target, target_zone, obj/item/tool)
		if (..())
			var/obj/item/organ/external/affected = target.get_organ(target_zone)
			return affected && affected.open == TRUE //&& !(affected.status & ORGAN_BLEEDING)

	begin_step(mob/user, mob/living/human/target, target_zone, obj/item/tool)
		var/obj/item/organ/external/affected = target.get_organ(target_zone)
		var/msg = "[user] starts to pry open the incision on [target]'s [affected.name] with \the [tool]."
		var/self_msg = "You start to pry open the incision on [target]'s [affected.name] with \the [tool]."
		if (target_zone == "chest")
			msg = "[user] starts to retract the skin on [target]'s torso with \the [tool]."
			self_msg = "You start to retract the skin on [target]'s torso with \the [tool]."
		if (target_zone == "groin")
			msg = "[user] starts to pry open the incision and retract the skin on [target]'s lower abdomen with \the [tool]."
			self_msg = "You start to pry open the incision and retract the skin on [target]'s lower abdomen with \the [tool]."
		user.visible_message(msg, self_msg)
		target.custom_pain("It feels like the skin on your [affected.name] is on fire!",170)
		..()

	end_step(mob/living/user, mob/living/human/target, target_zone, obj/item/tool)
		var/obj/item/organ/external/affected = target.get_organ(target_zone)
		var/msg = "<span class = 'notice'>[user] keeps the incision open on [target]'s [affected.name] with \the [tool].</span>"
		var/self_msg = "<span class = 'notice'>You keep the incision open on [target]'s [affected.name] with \the [tool].</span>"
		if (target_zone == "chest")
			msg = "<span class = 'notice'>[user] keeps the incision open on [target]'s torso with \the [tool].</span>"
			self_msg = "<span class = 'notice'>You keep the incision open on [target]'s torso with \the [tool].</span>"
		if (target_zone == "groin")
			msg = "<span class = 'notice'>[user] keeps the incision open on [target]'s lower abdomen with \the [tool].</span>"
			self_msg = "<span class = 'notice'>You keep the incision open on [target]'s lower abdomen with \the [tool].</span>"
		user.visible_message(msg, self_msg)
		affected.open = 2

	fail_step(mob/living/user, mob/living/human/target, target_zone, obj/item/tool)
		var/obj/item/organ/external/affected = target.get_organ(target_zone)
		var/msg = "<span class = 'red'>[user]'s hand slips, tearing the edges of the incision on [target]'s [affected.name] with \the [tool]!</span>"
		var/self_msg = "<span class = 'red'>Your hand slips, tearing the edges of the incision on [target]'s [affected.name] with \the [tool]!</span>"
		if (target_zone == "chest")
			msg = "<span class = 'red'>[user]'s hand slips, damaging [target]'s torso with \the [tool]!</span>"
			self_msg = "<span class = 'red'>Your hand slips, damaging [target]'s torso with \the [tool]!</span>"
		if (target_zone == "groin")
			msg = "<span class = 'red'>[user]'s hand slips, damaging [target]'s lower abdomen with \the [tool]!</span>"
			self_msg = "<span class = 'red'>Your hand slips, damaging [target]'s lower abdomen with \the [tool]!</span>"
		user.visible_message(msg, self_msg)
		target.apply_damage(12, BRUTE, affected, sharp=1)

/datum/surgery_step/generic/cauterize
	allowed_tools = list(
		1 = list("/obj/item/weapon/surgery/cautery",100),
		2 = list("/obj/item/weapon/surgery/cautery/bronze",85),
		3 = list("/obj/item/clothing/mask/smokable/cigarette/cigar",60),
		4 = list("/obj/item/flashlight/torch",75),
	)

	min_duration = 70
	max_duration = 100

	can_use(mob/living/user, mob/living/human/target, target_zone, obj/item/tool)
		if (..())
			var/obj/item/organ/external/affected = target.get_organ(target_zone)
			return affected && affected.open && target_zone != "mouth"

	begin_step(mob/user, mob/living/human/target, target_zone, obj/item/tool)
		var/obj/item/organ/external/affected = target.get_organ(target_zone)
		user.visible_message("[user] is beginning to cauterize the incision on [target]'s [affected.name] with \the [tool]." , \
		"You are beginning to cauterize the incision on [target]'s [affected.name] with \the [tool].")
		target.custom_pain("Your [affected.name] is being burned!",70)
		..()

	end_step(mob/living/user, mob/living/human/target, target_zone, obj/item/tool)
		var/obj/item/organ/external/affected = target.get_organ(target_zone)
		user.visible_message("<span class = 'notice'>[user] cauterizes the incision on [target]'s [affected.name] with \the [tool].</span>", \
		"<span class = 'notice'>You cauterize the incision on [target]'s [affected.name] with \the [tool].</span>")
		affected.open = FALSE
		affected.germ_level = FALSE
		affected.status &= ~ORGAN_BLEEDING

	fail_step(mob/living/user, mob/living/human/target, target_zone, obj/item/tool)
		var/obj/item/organ/external/affected = target.get_organ(target_zone)
		user.visible_message("<span class = 'red'>[user]'s hand slips, leaving a small burn on [target]'s [affected.name] with \the [tool]!</span>", \
		"<span class = 'red'>Your hand slips, leaving a small burn on [target]'s [affected.name] with \the [tool]!</span>")
		target.apply_damage(3, BURN, affected)

/datum/surgery_step/generic/amputate
	allowed_tools = list(
		1 = list("/obj/item/weapon/surgery/bone_saw",100),
		2 = list("/obj/item/weapon/surgery/bone_saw/bronze",85),
		3 = list("/obj/item/weapon/material/kitchen/utensil/knife/bone",30),
		4 = list("/obj/item/weapon/material/battleaxe",70),
		5 = list("/obj/item/weapon/material/machete",75),
	)

	min_duration = 110
	max_duration = 160

	can_use(mob/living/user, mob/living/human/target, target_zone, obj/item/tool)
		if (target_zone == "eyes")	//there are specific steps for eye surgery
			return FALSE
		if (!hasorgans(target))
			return FALSE
		var/obj/item/organ/external/affected = target.get_organ(target_zone)
		if (affected == null)
			return FALSE
		if (istype(tool, /obj/item/weapon/material/kitchen/utensil/knife/bone) && user.a_intent != I_HARM)
			return FALSE
		return !affected.cannot_amputate

	begin_step(mob/user, mob/living/human/target, target_zone, obj/item/tool)
		var/obj/item/organ/external/affected = target.get_organ(target_zone)
		user.visible_message("[user] is beginning to amputate [target]'s [affected.name] with \the [tool]." , \
		"You are beginning to cut through [target]'s [affected.amputation_point] with \the [tool].")
		target.custom_pain("Your [affected.amputation_point] is being ripped apart!",250)
		..()

	end_step(mob/living/user, mob/living/human/target, target_zone, obj/item/tool)
		var/obj/item/organ/external/affected = target.get_organ(target_zone)
		user.visible_message("<span class = 'notice'>[user] amputates [target]'s [affected.name] at the [affected.amputation_point] with \the [tool].</span>", \
		"<span class = 'notice'>You amputate [target]'s [affected.name] with \the [tool].</span>")
		affected.droplimb(1,DROPLIMB_EDGE)
		affected.nationality = target.nationality

	fail_step(mob/living/user, mob/living/human/target, target_zone, obj/item/tool)
		var/obj/item/organ/external/affected = target.get_organ(target_zone)
		user.visible_message("<span class = 'red'>[user]'s hand slips, sawing through the bone in [target]'s [affected.name] with \the [tool]!</span>", \
		"<span class = 'red'>Your hand slips, sawwing through the bone in [target]'s [affected.name] with \the [tool]!</span>")
		affected.createwound(CUT, 30)
		affected.fracture()
