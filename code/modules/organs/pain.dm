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

/mob/living/carbon/human/proc/handle_pain()
	// not when sleeping

	if (species.flags & NO_PAIN) return

	if (!has_pain) return

	if (stat >= 2) return
	if (analgesic > 70)
		return
	var/maxdam = FALSE
	var/obj/item/organ/external/damaged_organ = null
	for (var/obj/item/organ/external/E in organs)
		if (E.status & (ORGAN_DEAD|ORGAN_ROBOT)) continue
		var/dam = E.get_damage()
		// make the choice of the organ depend on damage,
		// but also sometimes use one of the less damaged ones
		if (dam > maxdam && (maxdam == FALSE || prob(70)) )
			damaged_organ = E
			maxdam = dam
	if (damaged_organ)
		if (prob(30))
			pain(damaged_organ.name, maxdam, FALSE)
		damaged_organ.pain = maxdam

	// Damage to internal organs hurts a lot.
	for (var/obj/item/organ/I in internal_organs)
		if (I.status & (ORGAN_DEAD|ORGAN_ROBOT)) continue
		if (I.damage > 2) if (prob(2))
			var/obj/item/organ/external/parent = get_organ(I.parent_organ)
			custom_pain("You feel a sharp pain in your [parent.name]", TRUE)

	var/toxDamageMessage = null
	var/toxMessageProb = TRUE
	switch(getToxLoss())
		if (1 to 5)
			toxMessageProb = TRUE
			toxDamageMessage = "Your body stings slightly."
		if (6 to 10)
			toxMessageProb = 2
			toxDamageMessage = "Your whole body hurts a little."
		if (11 to 15)
			toxMessageProb = 2
			toxDamageMessage = "Your whole body hurts."
		if (15 to 25)
			toxMessageProb = 3
			toxDamageMessage = "Your whole body hurts badly."
		if (26 to INFINITY)
			toxMessageProb = 5
			toxDamageMessage = "Your body aches all over, it's driving you mad."

	if (toxDamageMessage && prob(toxMessageProb))
		custom_pain(toxDamageMessage, getToxLoss() >= 15)


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
	if (reagents.has_reagent("morphine"))
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