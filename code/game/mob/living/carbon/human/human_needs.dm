/mob/living/human/proc/print_mood()
	if (!ishuman(src))
		return
	else
		var/mob/living/human/H = src
		var/msg = ""
		var/msg_hygiene = ""
		switch(mood)
			if(-5000000 to 20)
				msg = "Your mood is horrible!"
			if(20 to 40)
				msg = "Your mood is bad."
			if(40 to 60)
				msg = "Your mood is neutral."
			if(60 to 80)
				msg = "Your mood is good."
			if(80 to 10000)
				msg = "Your mood is excellent!"
		switch(hygiene)
			if(HYGIENE_LEVEL_CLEAN to INFINITY)
				msg_hygiene = "You feel very clean!"
			if(HYGIENE_LEVEL_NORMAL to HYGIENE_LEVEL_CLEAN)
				msg_hygiene = "You feel clean."
			if(HYGIENE_LEVEL_DIRTY to HYGIENE_LEVEL_NORMAL)
				msg_hygiene = "You feel a bit dirty."
			if(0 to HYGIENE_LEVEL_DIRTY)
				msg_hygiene = "You feel very dirty!"
		H << "<span class='info'>*---------*</span>"
		H << "<span class='info'>[msg]</span>"
		H << "<span class='info'>[msg_hygiene]</span>"
		H.print_excrement()
		H << "<span class='info'>*---------*</span>"
		return
/mob/living/human/proc/handle_ptsd()
	if (ptsd > 100)
		ptsd = 100
	if (ptsd < 0)
		ptsd = 0

	if (ptsd < 10 || ingested.has_reagent("citalopram", 5) || ingested.has_reagent("paroxetine", 3.33)) //antidepressives and anxiolytics block PTSD effects
		return FALSE
	else
		if (prob(0.45*(ptsd/8))) //at ptsd of 10, every 3 minutes or so, assuming the life tick of humans takes 8 deciseconds
			do_ptsd()
			return TRUE
		if (prob(0.45*(ptsd/4)))
			flash_sadness(ptsd)

/mob/living/human/proc/do_ptsd()
	if (ptsd < 3 || ingested.has_reagent("citalopram", 5) || ingested.has_reagent("paroxetine", 3.33)) //antidepressives and anxiolytics block PTSD effects
		return
	else
		if (prob(50))
			jitteriness += rand(140,200)
			visible_message("[src] starts shaking!","<span class='warning'>You start shaking!</span>")
			emote("cry")
			return
		else
			jitteriness += rand(60,90)
			Paralyse(3)
			visible_message("[src] collapses, breathing heavily!","<span class='warning'>You can't handle the situation!</span>")
			emote("scream")
			return


/mob/living/human/proc/flash_sadness(ptsd = 1)
	if (ingested.has_reagent("citalopram", 5) || ingested.has_reagent("paroxetine", 3.33)) //antidepressives and anxiolytics block PTSD effects
		return
	if(prob(2*ptsd))
		flick("sadness",HUDtech["pain"])
		var/spoopysound = pick('sound/effects/badmood1.ogg','sound/effects/badmood2.ogg','sound/effects/badmood3.ogg','sound/effects/badmood4.ogg')
		sound_to(src, spoopysound)

/mob/living/human/proc/handle_mood()
	switch(mood)
		if(-5000000 to 10)
			flash_sadness(mood/40)
			mood_modifier = 0.8
		if(10 to 20)
			flash_sadness(mood/40)
			mood_modifier = 0.85
		if(20 to 30)
			if (prob(35))
				flash_sadness(mood/40)
			mood_modifier = 0.90
		if(30 to 40)
			if (prob(30))
				flash_sadness(mood/40)
			mood_modifier = 0.95
		if(40 to 60)
			mood_modifier = 1
		if(60 to 80)
			mood_modifier = 1.05
		if(80 to 90)
			mood_modifier = 1.10
		if(90 to 10000)
			mood_modifier = 1.15


/mob/living/human/proc/handle_hygiene()
	if (sleeping)
		return
	adjust_hygiene(-HYGIENE_FACTOR)
	if (hygiene > HYGIENE_LEVEL_CLEAN)
		hygiene = HYGIENE_LEVEL_CLEAN
	if (hygiene < 0)
		hygiene = 0
	var/image/fleas = image('icons/effects/effects.dmi', "lice_overlay")
	var/image/smell = image('icons/effects/effects.dmi', "smell")//This is a hack, there has got to be a safer way to do this but I don't know it at the moment.
	var/image/img_nasties = image('icons/effects/effects.dmi', "nothing")
	switch(hygiene)
		if(HYGIENE_LEVEL_NORMAL to INFINITY)
//			img_nasties.overlays += null
		if(HYGIENE_LEVEL_DIRTY to HYGIENE_LEVEL_NORMAL)
//			overlays_standing[27] = null
			mood -= 0.02
		if(0 to HYGIENE_LEVEL_DIRTY)
			img_nasties.overlays += smell
			mood -= 0.04
	if (hygiene <= HYGIENE_LEVEL_DIRTY)
		if (prob(3))
			for(var/mob/living/human/HM in range(3,src))
				if (HM != src && !HM.orc)
					HM << "<span class='notice'>You sense a strong, nasty smell coming from [src].</span>"
					HM.mood -= 3
	var/fleas_found = FALSE
	for (var/obj/item/clothing/C in list(wear_suit,w_uniform,shoes))
		if (C)
			if (C.blood_DNA)
				C.dirtyness += 0.04
			else
				C.dirtyness += 0.025
			if (C.dirtyness > 100)
				C.dirtyness = 100
			if (C.dirtyness > 90)
				C.fleas = TRUE
				fleas_found = TRUE
	if (fleas_found)
		img_nasties.overlays += fleas
		mood -= 0.02
		if ((prob(0.2) || (prob(0.5) && find_trait("Weak Immune System"))) && !disease && !inducedSSD)
			disease = TRUE
			disease_type = "typhus"
			disease_progression = 0
			disease_treatment = 0
	overlays_standing[27] = img_nasties
/mob/living/human/proc/adjust_hygiene(var/amount)
	var/old_hygiene = hygiene
	if(amount>0)
		hygiene = min(hygiene+amount, HYGIENE_LEVEL_CLEAN)

	else if(old_hygiene)
		hygiene = max(hygiene+amount, 0)

/mob/living/human/proc/set_hygiene(var/amount)
	if(amount >= 0)
		hygiene = min(HYGIENE_LEVEL_CLEAN, amount)
