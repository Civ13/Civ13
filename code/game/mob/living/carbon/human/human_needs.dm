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
		to_chat(H, "<span class='info'>*---------*</span>")
		to_chat(H, "<span class='info'>[msg]</span>")
		H.print_mood_causes()
		to_chat(H, "<span class='info'>[msg_hygiene]</span>")
		H.print_excrement()
		to_chat(H, "<span class='info'>*---------*</span>")
		return

/mob/living/human/proc/flash_sadness(ptsd = 1)
	if (ingested.has_reagent("citalopram", 5) || ingested.has_reagent("paroxetine", 3.33)) //antidepressives and anxiolytics block PTSD effects
		return
	if(prob(2*ptsd))
		flick("sadness",HUDtech["pain"])
		var/spoopysound = pick('sound/effects/badmood1.ogg','sound/effects/badmood2.ogg','sound/effects/badmood3.ogg','sound/effects/badmood4.ogg')
		sound_to(src, spoopysound)

/mob/living/human/proc/handle_mood()
	fade_mood_causes()
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
			adjust_mood(-(0.01), "being dirty")
		if(0 to HYGIENE_LEVEL_DIRTY)
			img_nasties.overlays += smell
			adjust_mood(-(0.02), "being dirty")
	if (hygiene <= HYGIENE_LEVEL_DIRTY)
		if (prob(12))
			for(var/mob/living/human/HM in range(3,src))
				if (HM != src && !HM.orc)
					to_chat(HM, "<span class='notice'>You sense a strong, nasty smell coming from [src].</span>")
					HM.adjust_mood(-(1.5), "a nasty smell nearby")
	var/fleas_found = FALSE
	for (var/obj/item/clothing/C in list(wear_suit,w_uniform,shoes))
		if (C)
			if (C.blood_DNA)
				C.dirtyness += 0.02
			else
				C.dirtyness += 0.015
			if (C.dirtyness > 100)
				C.dirtyness = 100
			if (C.dirtyness > 90)
				C.fleas = TRUE
				fleas_found = TRUE
	if (fleas_found)
		img_nasties.overlays += fleas
		adjust_mood(-(0.02), "fleas")
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

// Mood changes use the recipient's actual sleep state, including off-tick events.
// Discard losses immediately; waking never replays them. Resting alone is awake.
/mob/living/human/proc/set_mood(amount, cause = null)
	if (sleeping > 0 && amount < mood)
		return mood
	if (cause)
		note_mood_cause(cause, amount - mood)
	mood = amount
	return mood

/mob/living/human/proc/adjust_mood(amount, cause = null)
	return set_mood(mood + amount, cause)

// Recent mood causes, shown by clicking the mood HUD. A labelled mood change
// adds to its cause; every life tick each cause fades, so the list explains
// what moved mood lately. Unlabelled drift toward neutral and caps are omitted.
/mob/living/human
	var/tmp/list/mood_causes // cause -> recent net mood change
	var/tmp/list/mood_cause_times // cause -> world.time of its last change
	var/tmp/list/mood_causes_noticed // causes already announced to the player

// Causes describe this process's recent events, not the saved body.
/mob/living/human/persistence_runtime_var(key)
	return key == "mood_causes" || key == "mood_cause_times" || key == "mood_causes_noticed" || ..()

#define MOOD_CAUSE_FADE 0.99
#define MOOD_CAUSE_NOTICE 1
#define MOOD_CAUSE_FORGET 0.5
#define MOOD_CAUSE_ONGOING 300 // deciseconds since the last change
#define MOOD_CAUSE_SHOWN 8

/mob/living/human/proc/note_mood_cause(cause, delta)
	if (!delta || !istext(cause))
		return
	if (!islist(mood_causes))
		mood_causes = list()
		mood_cause_times = list()
		mood_causes_noticed = list()
	var/total = mood_causes[cause]
	if (!isnum(total))
		total = 0
	total += delta
	mood_causes[cause] = total
	mood_cause_times[cause] = world.time
	if (abs(total) >= MOOD_CAUSE_NOTICE && !(cause in mood_causes_noticed))
		mood_causes_noticed += cause
		if (total > 0)
			to_chat(src, "<span class='info'>Your mood improves: [cause].</span>")
		else
			to_chat(src, "<span class='warning'>Your mood worsens: [cause].</span>")

/mob/living/human/proc/fade_mood_causes()
	if (!islist(mood_causes) || !mood_causes.len)
		return
	for (var/cause in mood_causes.Copy())
		var/total = mood_causes[cause] * MOOD_CAUSE_FADE
		if (abs(total) >= MOOD_CAUSE_FORGET)
			mood_causes[cause] = total
			continue
		mood_causes -= cause
		mood_cause_times -= cause
		if (cause in mood_causes_noticed)
			mood_causes_noticed -= cause
			to_chat(src, "<span class='info'>Your mood is no longer affected by [cause].</span>")

// The cause pushing mood hardest in one direction: positive for 1, negative for -1.
/mob/living/human/proc/strongest_mood_cause(direction)
	var/best = null
	var/best_total = 0
	if (!islist(mood_causes))
		return null
	for (var/cause in mood_causes)
		var/total = mood_causes[cause] * direction
		if (total > best_total)
			best = cause
			best_total = total
	return best

/mob/living/human/proc/print_mood_causes()
	var/list/order = list()
	if (islist(mood_causes))
		for (var/cause in mood_causes)
			if (abs(mood_causes[cause]) < MOOD_CAUSE_NOTICE)
				continue
			var/placed = FALSE
			for (var/i = 1, i <= order.len, i++)
				if (abs(mood_causes[cause]) > abs(mood_causes[order[i]]))
					order.Insert(i, cause)
					placed = TRUE
					break
			if (!placed)
				order += cause
	if (!order.len)
		to_chat(src, "<span class='info'>Nothing in particular has changed your mood lately.</span>")
		return
	to_chat(src, "<span class='info'>What has been affecting your mood:</span>")
	var/shown = 0
	for (var/cause in order)
		if (++shown > MOOD_CAUSE_SHOWN)
			break
		var/total = mood_causes[cause]
		var/strength = "slightly"
		if (abs(total) >= 15)
			strength = "strongly"
		else if (abs(total) >= 5)
			strength = "moderately"
		var/timing = world.time - mood_cause_times[cause] <= MOOD_CAUSE_ONGOING ? "ongoing" : "fading"
		if (total > 0)
			to_chat(src, "<span class='good'>&nbsp;+ [capitalize(cause)]: lifting it [strength] ([timing]).</span>")
		else
			to_chat(src, "<span class='bad'>&nbsp;- [capitalize(cause)]: weighing on it [strength] ([timing]).</span>")

#undef MOOD_CAUSE_FADE
#undef MOOD_CAUSE_NOTICE
#undef MOOD_CAUSE_FORGET
#undef MOOD_CAUSE_ONGOING
#undef MOOD_CAUSE_SHOWN
