mob/proc/flash_pain()
	return
	if (istype(src,/mob/living))
		var/mob/living/L = src
		if (L.HUDtech.Find("pain"))
			flick("pain",L.HUDtech["pain"])

mob/proc/flash_weak_pain()//Why the fuck wasn't that there before?
	return
	if (istype(src,/mob/living))
		var/mob/living/L = src
		if (L.HUDtech.Find("pain"))
			flick("weak_pain",L.HUDtech["pain"])

mob/proc/flash_weakest_pain()
	return
	if (istype(src,/mob/living))
		var/mob/living/L = src
		if (L.HUDtech.Find("pain"))
			flick("weakest_pain",L.HUDtech["pain"])

mob/var/list/pain_stored = list()
mob/var/last_pain_message = ""
mob/var/next_pain_time = FALSE

// partname is the name of a body part
// amount is a num from TRUE to 100
/mob/living/carbon/proc/pain(var/partname, var/amount, var/force, var/burning = FALSE)
	if (stat >= 1)
		return
	if (species && (species.flags & NO_PAIN))
		return
	if (analgesic > 40)
		return
	if (world.time < next_pain_time && !force)
		return
	if (bloodstr)
		var/no_pain_prob = FALSE
		for (var/datum/reagent/ethanol/E in ingested.reagent_list)
			no_pain_prob += E.volume
		if (prob(no_pain_prob))
			return
	if (amount > 10 && istype(src,/mob/living/carbon/human))
		if (src:paralysis)
			src:paralysis = max(0, src:paralysis-round(amount/10))
	if (amount > 50 && prob(amount / 5))
		src:drop_item()
	var/msg
	/*if (burning)
		switch(amount)
			if (1 to 10)
				//msg = "\red <b>Your [partname] burns.</b>"
			if (11 to 90)
				flash_weak_pain()
				//msg = "\red <b><font size=2>Your [partname] burns badly!</font></b>"
			if (91 to 10000)
				flash_pain()
				//msg = "\red <b><font size=3>OH GOD! Your [partname] is on fire!</font></b>"
	else*/
	switch(amount)
		if (1 to 10)
			flash_weakest_pain()
			//msg = "<b>Your [partname] hurts.</b>"
		if (11 to 90)
			flash_weak_pain()
			//msg = "<b><font size=2>Your [partname] hurts badly.</font></b>"
		if (91 to 10000)
			flash_pain()
				//msg = "<b><font size=3>OH GOD! Your [partname] is hurting terribly!</font></b>"
	if (msg && (msg != last_pain_message || prob(10)))
		last_pain_message = msg
		src << msg
	next_pain_time = world.time + (100 - amount)


// message is the custom message to be displayed
// flash_strength is FALSE for weak pain flash, TRUE for strong pain flash
mob/living/carbon/human/proc/custom_pain(var/message, var/flash_strength)
	if (stat >= 1)
		return
	if (species.flags & NO_PAIN)
		return
	if (reagents.has_reagent("tramadol"))
		return
	if (reagents.has_reagent("oxycodone"))
		return
	if (analgesic)
		return
	var/msg = "<span class = 'red'><b>[message]</b></span>"
	if (flash_strength >= 1)
		msg = "<span class = 'red'><font size=3><b>[message]</b></font></span>"

	// Anti message spam checks
	if (msg && ((msg != last_pain_message) || (world.time >= next_pain_time)))
		last_pain_message = msg
		src << msg
	next_pain_time = world.time + 100

mob/living/carbon/human/proc/handle_pain()
	if (stat >= 2) return

	if(world.time < next_pain_time)
		return
	var/maxdam = 0
	var/obj/item/organ/external/damaged_organ = null
	for(var/obj/item/organ/external/E in organs)
		var/dam = E.get_damage()
		// make the choice of the organ depend on damage,
		// but also sometimes use one of the less damaged ones
		if(dam > maxdam && (maxdam == 0 || prob(70)) )
			damaged_organ = E
			maxdam = dam
	if(damaged_organ && chem_effects[CE_PAINKILLER] < maxdam)
		if(maxdam > 10 && paralysis)
			paralysis = max(0, paralysis - round(maxdam/10))
		var/burning = damaged_organ.burn_dam > damaged_organ.brute_dam
		var/msg
		switch(maxdam)
			if(1 to 10)
				msg =  "Your [damaged_organ.name] [burning ? "burns" : "hurts"]."
			if(11 to 90)
				msg = "Your [damaged_organ.name] [burning ? "burns" : "hurts"] badly!"
			if(91 to 10000)
				msg = "OH GOD! Your [damaged_organ.name] is [burning ? "on fire" : "hurting terribly"]!"
		custom_pain(msg, maxdam, prob(10), damaged_organ, TRUE)
	// Damage to internal organs hurts a lot.
	for(var/obj/item/organ/I in internal_organs)
		if(prob(1) && !(I.status & ORGAN_DEAD) && I.damage > 5)
			var/obj/item/organ/external/parent = get_organ(I.parent_organ)
			var/pain = 10
			var/message = "You feel a dull pain in your [parent.name]"
			if(I.is_bruised())
				pain = 25
				message = "You feel a pain in your [parent.name]"
			if(I.is_broken())
				pain = 50
				message = "You feel a sharp pain in your [parent.name]"
			src.custom_pain(message, pain, affecting = parent)


	if(prob(1))
		switch(getToxLoss())
			if(5 to 17)
				custom_pain("Your body stings slightly.", getToxLoss())
			if(17 to 35)
				custom_pain("Your body stings.", getToxLoss())
			if(35 to 60)
				custom_pain("Your body stings strongly.", getToxLoss())
			if(60 to 100)
				custom_pain("Your whole body hurts badly.", getToxLoss())
			if(100 to INFINITY)
				custom_pain("Your body aches all over, it's driving you mad.", getToxLoss())

/mob/living/carbon/human/proc/painchecks()
	if (stat >= 2)
		return
	if (species.flags & NO_PAIN)
		return
	if (reagents.has_reagent("paracetamol"))
		return
	if (reagents.has_reagent("tramadol"))
		return
	if (reagents.has_reagent("oxycodone"))
		return
	if (reagents.has_reagent("opium"))
		return
	if (analgesic)
		return
	else
		return TRUE

/*mob/living/carbon/human/proc/suffer_well(var/prob)//Subber well pupper.
	if (prob(prob))
		emote("agony")
		Weaken(10)
		shake_camera(src, 20, 3)
		if (!stat)//So this doesn't get displayed when you're asleep.
			visible_message("<span class='warning'>[src] gives into the pain!</span>")
			*/ //to be finished soon.