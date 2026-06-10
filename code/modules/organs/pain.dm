/mob/living/proc/flash_pain()
	if (HUDtech.Find("pain"))
		flick("dark128",HUDtech["pain"])
	return
/mob/living/proc/flash_weak_pain()//Why the fuck wasn't that there before?
	if (HUDtech.Find("pain"))
		flick("dark64",HUDtech["pain"])
	return
/mob/living/proc/flash_weakest_pain()
	if (HUDtech.Find("pain"))
		flick("dark32",HUDtech["pain"])
	return
/mob/var/list/pain_stored = list()
/mob/var/last_pain_message = ""
/mob/var/next_pain_time = FALSE




// message is the custom message to be displayed
// power decides how much painkillers will stop the message
// force means it ignores anti-spam timer
/mob/living/human/proc/custom_pain(var/message, var/power = 0, var/force = FALSE, var/obj/item/organ/external/affecting, var/nohalloss = FALSE, var/flash_pain = 0)
	if(!message || stat || chem_effects[CE_PAINKILLER] > power)
		return 0

	// Excessive halloss is horrible, just give them enough to make it visible.
	if(!nohalloss && (power || flash_pain))//Flash pain is so that handle_pain actually makes use of this proc to flash pain.
		if(affecting)
			affecting.add_pain(ceil(power/2))
		else
			adjustHalLoss(ceil(power/2))

		var/actual_flash = max(power,flash_pain)

		switch(actual_flash)
			if(1 to 10)
				flash_weakest_pain()
			if(11 to 90)
				flash_weak_pain()
				if(stuttering < 10)
					stuttering += 5
			if(91 to INFINITY)
				flash_pain()
				if(stuttering < 10)
					stuttering += 10

	// Anti message spam checks
	if(force || (message != last_pain_message) || (world.time >= next_pain_time))
		last_pain_message = message
		if(power >= 50)
			to_chat(src, "<b><font size=3>[message]</font></b>")
		else
			to_chat(src, "<b>[message]</b>")
	next_pain_time = world.time + (100-power)

/mob/living/human/proc/handle_pain()
	if(stat)
		return
	if(!can_feel_pain())
		return
	if(world.time < next_pain_time)
		return

	var/maxdam = 0
	var/obj/item/organ/external/damaged_organ = null
	for(var/obj/item/organ/external/E in organs)
		if(!E.can_feel_pain())
			continue
		var/dam = E.get_damage()
		for(var/obj/item/organ/I in E.internal_organs)
			dam += I.damage
		// make the choice of the organ depend on damage,
		// but also sometimes use one of the less damaged ones
		if(dam > maxdam && (maxdam == 0 || prob(70)))
			damaged_organ = E
			maxdam = dam

	if(damaged_organ && chem_effects[CE_PAINKILLER] < maxdam)
		if(maxdam > 10 && paralysis)
			paralysis = max(0, paralysis - round(maxdam/10))
		/*
		if(maxdam > 50 && prob(maxdam / 5))
			drop_item()
		*/
		var/burning = damaged_organ.burn_dam > damaged_organ.brute_dam
		var/msg
		if (prob(10))
			switch(maxdam)
				if(1 to 40)
					msg = "Your [damaged_organ.name] [burning ? "burns" : "hurts"]."

				if(41 to 80)
					msg = "<font size=2>Your [damaged_organ.name] [burning ? "burns" : "hurts"] badly!</font>"

				if(81 to INFINITY)
					msg = "<font size=3>OH GOD! Your [damaged_organ.name] is [burning ? "on fire" : "hurting terribly"]!</font>"
		custom_pain(msg, maxdam, prob(10), damaged_organ, TRUE, flash_pain = maxdam)

	// Damage to internal organs hurts a lot.
	for(var/obj/item/organ/I in internal_organs)
		if((I.status & ORGAN_DEAD)) continue
		if(I.damage > 2) if(prob(2))
			var/obj/item/organ/external/parent = get_organ(I.parent_organ)
			src.custom_pain("You feel a sharp pain in your [parent.name]", 50, affecting = parent)

	if(prob(2))
		switch(getToxLoss())
			if(10 to 25)
				custom_pain("Your body stings slightly.", getToxLoss())
			if(25 to 45)
				custom_pain("Your whole body hurts badly.", getToxLoss())
			if(61 to INFINITY)
				custom_pain("Your body aches all over, it's driving you mad.", getToxLoss())

/mob/living/human/proc/painchecks()
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

