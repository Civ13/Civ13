//Procedures in this file: Putting items in body cavity. Implant removal. Items removal.

//////////////////////////////////////////////////////////////////
//					ITEM PLACEMENT SURGERY						//
//////////////////////////////////////////////////////////////////

/datum/surgery_step/cavity
	priority = TRUE
	can_use(mob/living/user, mob/living/human/target, target_zone, obj/item/tool)
		if(!hasorgans(target))
			return FALSE
		var/obj/item/organ/external/affected = target.get_organ(target_zone)
		return affected && affected.open == 2 && !(affected.status & ORGAN_BLEEDING)

	proc/get_max_wclass(var/obj/item/organ/external/affected)
		switch (affected.name)
			if ("head")
				return TRUE
			if ("upper body")
				return 3
			if ("lower body")
				return 2
		return FALSE

	proc/get_cavity(var/obj/item/organ/external/affected)
		switch (affected.name)
			if ("head")
				return "cranial"
			if ("upper body")
				return "thoracic"
			if ("lower body")
				return "abdominal"
		return ""

	fail_step(mob/living/user, mob/living/human/target, target_zone, obj/item/tool)
		var/obj/item/organ/external/chest/affected = target.get_organ(target_zone)
		user.visible_message("<span class = 'red'>[user]'s hand slips, scraping around inside [target]'s [affected.name] with \the [tool]!</span>", \
		"<span class = 'red'>Your hand slips, scraping around inside [target]'s [affected.name] with \the [tool]!</span>")
		affected.createwound(CUT, 20)

/datum/surgery_step/cavity/make_space
	allowed_tools = list(
		1 = list("/obj/item/weapon/surgery/scalpel",100),
		2 = list("/obj/item/weapon/surgery/scalpel/bronze",100),
		3 = list("/obj/item/weapon/pen",75),
		4 = list("/obj/item/weapon/material/handle",50),
	)

	min_duration = 60
	max_duration = 80

	can_use(mob/living/user, mob/living/human/target, target_zone, obj/item/tool)
		if(..())
			var/obj/item/organ/external/affected = target.get_organ(target_zone)
			return affected && !affected.cavity

	begin_step(mob/user, mob/living/human/target, target_zone, obj/item/tool)
		var/obj/item/organ/external/affected = target.get_organ(target_zone)
		user.visible_message("[user] starts making some space inside [target]'s [get_cavity(affected)] cavity with \the [tool].", \
		"You start making some space inside [target]'s [get_cavity(affected)] cavity with \the [tool]." )
		target.custom_pain("The pain in your chest is living hell!",1)
		affected.cavity = TRUE
		..()

	end_step(mob/living/user, mob/living/human/target, target_zone, obj/item/tool)
		var/obj/item/organ/external/chest/affected = target.get_organ(target_zone)
		user.visible_message("<span class = 'notice'>[user] makes some space inside [target]'s [get_cavity(affected)] cavity with \the [tool].</span>", \
		"<span class = 'notice'>You make some space inside [target]'s [get_cavity(affected)] cavity with \the [tool].</span>" )

/datum/surgery_step/cavity/close_space
	priority = TRUE
	allowed_tools = list(
		1 = list("/obj/item/weapon/surgery/cautery",100),
		2 = list("/obj/item/weapon/surgery/cautery/bronze",85),
		3 = list("/obj/item/clothing/mask/smokable/cigarette/cigar",60),
		4 = list("/obj/item/flashlight/torch",75),
	)

	min_duration = 60
	max_duration = 80

	can_use(mob/living/user, mob/living/human/target, target_zone, obj/item/tool)
		if(..())
			var/obj/item/organ/external/affected = target.get_organ(target_zone)
			return affected && !affected.cavity && affected.open == FALSE

	begin_step(mob/user, mob/living/human/target, target_zone, obj/item/tool)
		var/obj/item/organ/external/affected = target.get_organ(target_zone)
		user.visible_message("[user] starts mending [target]'s [get_cavity(affected)] cavity wall with \the [tool].", \
		"You start mending [target]'s [get_cavity(affected)] cavity wall with \the [tool]." )
		target.custom_pain("The pain in your chest is living hell!",1)
		affected.cavity = FALSE
		..()

	end_step(mob/living/user, mob/living/human/target, target_zone, obj/item/tool)
		var/obj/item/organ/external/chest/affected = target.get_organ(target_zone)
		user.visible_message("<span class = 'notice'>[user] mends [target]'s [get_cavity(affected)] cavity walls with \the [tool].</span>", \
		"<span class = 'notice'>You mend [target]'s [get_cavity(affected)] cavity walls with \the [tool].</span>" )

/datum/surgery_step/cavity/place_item
	priority = FALSE
	allowed_tools = list(
		1 = list("/obj/item",100),
	)

	min_duration = 80
	max_duration = 100

	can_use(mob/living/user, mob/living/human/target, target_zone, obj/item/tool)
		if(..())
			var/obj/item/organ/external/affected = target.get_organ(target_zone)
			if(affected && affected.cavity)
				var/total_volume = tool.w_class
				for(var/obj/item/I in affected.implants)
	/*				if(istype(I,/obj/item/weapon/implant))
						continue*/
					total_volume += I.w_class
				return total_volume <= get_max_wclass(affected)

	begin_step(mob/user, mob/living/human/target, target_zone, obj/item/tool)
		var/obj/item/organ/external/affected = target.get_organ(target_zone)
		user.visible_message("[user] starts putting \the [tool] inside [target]'s [get_cavity(affected)] cavity.", \
		"You start putting \the [tool] inside [target]'s [get_cavity(affected)] cavity." )
		target.custom_pain("The pain in your chest is living hell!",1)
		playsound(target.loc, 'sound/effects/squelch1.ogg', 50, TRUE)
		..()

	end_step(mob/living/user, mob/living/human/target, target_zone, obj/item/tool)
		var/obj/item/organ/external/chest/affected = target.get_organ(target_zone)

		user.visible_message("<span class = 'notice'>[user] puts \the [tool] inside [target]'s [get_cavity(affected)] cavity.</span>", \
		"<span class = 'notice'>You put \the [tool] inside [target]'s [get_cavity(affected)] cavity.</span>" )
		if (tool.w_class > get_max_wclass(affected)/2 && prob(50))
			user << "<span class = 'red'>You tear some blood vessels trying to fit such a big object in this cavity.</span>"
			var/datum/wound/internal_bleeding/I = new (10)
			affected.wounds += I
			affected.owner.custom_pain("You feel something rip in your [affected.name]!", TRUE)
		user.drop_item()
		affected.implants += tool
		tool.loc = affected
		affected.cavity = FALSE

//////////////////////////////////////////////////////////////////
//					IMPLANT/ITEM REMOVAL SURGERY						//
//////////////////////////////////////////////////////////////////

/datum/surgery_step/internal/implant_removal
	allowed_tools = list(
		1 = list("/obj/item/weapon/surgery/hemostat",100),
		2 = list("/obj/item/weapon/wirecutters",75),
		3 = list("/obj/item/weapon/material/kitchen/utensil/fork",35),
	)

	min_duration = 80
	max_duration = 100

	can_use(mob/living/user, mob/living/human/target, target_zone, obj/item/tool)
		var/obj/item/organ/brain/sponge = target.internal_organs_by_name["brain"]
		return ..() && (!sponge || !sponge.damage)

	begin_step(mob/user, mob/living/human/target, target_zone, obj/item/tool)
		var/obj/item/organ/external/affected = target.get_organ(target_zone)
		user.visible_message("[user] starts poking around inside [target]'s [affected.name] with \the [tool]...", \
		"You start poking around inside [target]'s [affected.name] with \the [tool]..." )
		target.custom_pain("The pain in your [affected.name] is living hell!",1)
		..()

	end_step(mob/living/user, mob/living/human/target, target_zone, obj/item/tool)
		var/obj/item/organ/external/chest/affected = target.get_organ(target_zone)

		var/find_prob = FALSE

		if (affected.implants.len)

			var/obj/item/obj = pick(affected.implants)

			find_prob +=50
			var/mob/living/human/H = user
			if (prob(find_prob)*H.getStatCoeff("medical"))
				user.visible_message("<span class = 'notice'>[user] takes something out of incision on [target]'s [affected.name] with \the [tool].</span>", \
				"<span class = 'notice'>You take [obj] out of incision on [target]'s [affected.name]s with \the [tool].</span>" )
				affected.implants -= obj

				obj.loc = get_turf(target)
				obj.add_blood(target)
				obj.update_icon()
				playsound(target.loc, 'sound/effects/squelch1.ogg', 50, TRUE)
			else
				user.visible_message("<span class = 'notice'>[user] removes \the [tool] from [target]'s [affected.name].</span>", \
				"<span class = 'notice'>There's something inside [target]'s [affected.name], but you just missed it this time.</span>" )
		else
			user.visible_message("<span class = 'notice'>[user] could not find anything inside [target]'s [affected.name], and pulls \the [tool] out.</span>", \
			"<span class = 'notice'>You could not find anything inside [target]'s [affected.name].</span>" )

	fail_step(mob/living/user, mob/living/human/target, target_zone, obj/item/tool)
		..()
		var/obj/item/organ/external/chest/affected = target.get_organ(target_zone)
		if (affected.implants.len)
			var/fail_prob = 10
			fail_prob += 100 - tool_quality(tool)
			if (prob(fail_prob))
				user.visible_message("<span class = 'red'>Something makes a noise inside [target]'s [affected.name]!</span>")

