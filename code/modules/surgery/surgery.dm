/* SURGERY STEPS */

/datum/surgery_step
	var/priority = FALSE	//steps with higher priority would be attempted first

	// type path referencing tools that can be used for this step, and how well are they suited for it
	var/list/allowed_tools = list(1 = list("/obj/item/cursedtreasure",100)) //so its not used
	// type paths referencing races that this step applies to.
	var/list/allowed_species = null
	var/list/disallowed_species = null

	// duration of the step
	var/min_duration = FALSE
	var/max_duration = FALSE

	// evil infection stuff that will make everyone hate me
	var/can_infect = FALSE
	//How much blood this step can get on surgeon. TRUE - hands, 2 - full body.
	var/blood_level = FALSE

	//returns how well the tool is suited for this step. from 1 to 100 (to be used as a prob of suceeding)
	proc/tool_quality(obj/item/TT, var/mob/living/human/user)
		var/quality = FALSE
		for (var/i = 1, i <= allowed_tools.len, i++)
			if (istype(TT, text2path(allowed_tools[i][1])))
				quality = allowed_tools[i][2]
		if (istype(user, /mob/living/human))
			quality *= user.getStatCoeff("medical")

		if (quality > 100)
			quality = 100
		if (quality < 0)
			quality = 0

		. = quality

	// Checks if this step applies to the user mob at all
	proc/is_valid_target(mob/living/human/target)
		if (!hasorgans(target))
			return FALSE

		if (allowed_species)
			for (var/species in allowed_species)
				if (target.species.get_bodytype() == species)
					return TRUE

		if (disallowed_species)
			for (var/species in disallowed_species)
				if (target.species.get_bodytype() == species)
					return FALSE

		return TRUE


	// checks whether this step can be applied with the given user and target
	proc/can_use(mob/living/user, mob/living/human/target, target_zone, obj/item/tool)
		return FALSE

	// does stuff to begin the step, usually just printing messages. Moved germs transfering and bloodying here too
	proc/begin_step(mob/living/user, mob/living/human/target, target_zone, obj/item/tool)
		var/obj/item/organ/external/affected = target.get_organ(target_zone)
		if (can_infect && affected)
			spread_germs_to_organ(affected, user)
		if (ishuman(user) && prob(60))
			var/mob/living/human/H = user
			if (blood_level)
				H.bloody_hands(target,0)
			if (blood_level > 1)
				H.bloody_body(target,0)
		return

	// does stuff to end the step, which is normally print a message + do whatever this step changes
	proc/end_step(mob/living/user, mob/living/human/target, target_zone, obj/item/tool)
		return

	// stuff that happens when the step fails
	proc/fail_step(mob/living/user, mob/living/human/target, target_zone, obj/item/tool)
		return null

proc/spread_germs_to_organ(var/obj/item/organ/external/E, var/mob/living/human/user)
	if (!istype(user) || !istype(E)) return

	var/germ_level = user.germ_level
	if (user.gloves)
		germ_level = user.gloves.germ_level

	E.germ_level = max(germ_level,E.germ_level) //as funny as scrubbing microbes out with clean gloves is - no.

proc/do_surgery(mob/living/human/M, mob/living/human/user, obj/item/tool)
	if (!istype(M))
		return FALSE
	if (user.a_intent == I_HARM)	//check for Hippocratic Oath
		return FALSE
	var/zone = user.targeted_organ
	if (user.targeted_organ == "random")
		zone = pick("l_foot","r_foot","l_leg","r_leg","chest","groin","l_arm","r_arm","l_hand","r_hand","eyes","mouth","head")
	if (zone in M.op_stage.in_progress) //Can't operate on someone repeatedly.
		user << "<span class='warning'>You can't operate on this area while surgery is already in progress.</span>"
		return TRUE
	for (var/datum/surgery_step/S in surgery_steps)
		//check if tool is right or close enough and if this step is possible
		if (S.tool_quality(tool, user) > 50)
			var/step_is_valid = S.can_use(user, M, zone, tool)
			if (step_is_valid && S.is_valid_target(M))
				if (step_is_valid == SURGERY_FAILURE) // This is a failure that already has a message for failing.
					return TRUE
				M.op_stage.in_progress += zone
				S.begin_step(user, M, zone, tool)		//start on it
				//We had proper tools! (or RNG smiled.) and user did not move or change hands.
				if (prob(S.tool_quality(tool, user)))
					if (do_after(user, rand(S.min_duration, S.max_duration), M))//&& do_mob(user, M, rand(S.min_duration, S.max_duration), FALSE) && user.Adjacent(M))
						S.end_step(user, M, zone, tool)		//finish successfully
						if (ishuman(user))
							var/mob/living/human/H = user
							var/mod = 1
							if (user.religious_clergy == "Shamans")
								mod = 2
							H.adaptStat("medical", 1.5*mod)
						M.op_stage.in_progress -= zone 									// Clear the in-progress flag.
					else
						if (M)
							M.op_stage.in_progress -= zone 									// Clear the in-progress flag.
				else
					if (user.Adjacent(M) && (tool in user.contents))			//or
						// better solution to combat surgery, nothing happens unless you were doing it for a while - Kachnov
						S.fail_step(user, M, zone, tool)		//malpractice
					else
						if (!(tool in user.contents))
							user << "<span class='warning'>You stop the surgery.</span>"
							if (prob(5))
								S.fail_step(user, M, zone, tool)
						else if (!user.Adjacent(M))
							user << "<span class='warning'>You must remain close to your patient to conduct surgery.</span>"
							if (prob(15))
								S.fail_step(user, M, zone, tool)
						else // This failing silently was a pain.
							user << "<span class='warning'>Your hand slips!</span>"
							if (prob(8))
								S.fail_step(user, M, zone, tool)
					M.op_stage.in_progress -= zone 									// Clear the in-progress flag.
					if (ishuman(M))
						var/mob/living/human/H = M
						H.update_surgery()
				return	TRUE	  												//don't want to do weapony things after surgery
		else if (S.tool_quality(tool, user) > 0 && S.tool_quality(tool, user) <= 50)
			user << "You are not skilled enough to perform this surgery step with \the [tool]."
			return TRUE
	return FALSE

proc/sort_surgeries()
	var/gap = surgery_steps.len
	var/swapped = TRUE
	while (gap > 1 || swapped)
		swapped = FALSE
		if (gap > 1)
			gap = round(gap / 1.247330950103979)
		if (gap < 1)
			gap = TRUE
		for (var/i = TRUE; gap + i <= surgery_steps.len; i++)
			var/datum/surgery_step/l = surgery_steps[i]		//Fucking hate
			var/datum/surgery_step/r = surgery_steps[gap+i]	//how lists work here
			if (l.priority < r.priority)
				surgery_steps.Swap(i, gap + i)
				swapped = TRUE

/datum/surgery_status/
	var/eyes	=	0
	var/face	=	0
	var/head_reattach = FALSE
	var/current_organ = "organ"
	var/list/in_progress = list()
