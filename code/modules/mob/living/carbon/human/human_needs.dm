/mob/living/carbon/human/proc/print_mood()
	if (!ishuman(src))
		return
	else
		var/mob/living/carbon/human/H = src
		var/msg = ""
		switch(mood)
			if(-5000000 to 19)
				msg = "My mood is horrible!"
			if(20 to 39)
				msg = "My mood is bad."
			if(40 to 59)
				msg = "My mood is neutral."
			if(60 to 79)
				msg = "My mood is good."
			if(80 to INFINITY)
				msg = "My mood is excellent!"
		H << "<span class='info'>[msg]<br>*---------*</span>"
		return
/mob/living/carbon/human/proc/handle_ptsd()
	if (ptsd > 100)
		ptsd = 100
	if (ptsd < 0)
		ptsd = 0

	if (ptsd < 10)
		return FALSE
	else
		if (prob(0.45*(ptsd/10))) //at ptsd of 10, every 3 minutes or so, assuming the life tick of humans takes 8 deciseconds
			do_ptsd()
			return TRUE
		flash_sadness(ptsd)

/mob/living/carbon/human/proc/do_ptsd()
	if (ptsd < 3)
		return
	else
		if (prob(50))
			jitteriness += rand(140,200)
			src << "<span class='warning'>You start shaking!</span>"
			return
		else
			jitteriness += rand(60,90)
			Paralyse(3)
			visible_message("[src] collapses, breathing heavily!","<span class='warning'>You can't handle the situation!</span>")
			return


/mob/living/carbon/human/proc/flash_sadness(ptsd = 1)
	if(prob(2*ptsd))
		flick("sadness",HUDtech["pain"])
		var/spoopysound = pick('sound/effects/badmood1.ogg','sound/effects/badmood2.ogg','sound/effects/badmood3.ogg','sound/effects/badmood4.ogg')
		sound_to(src, spoopysound)
/*
/mob/living/carbon/human/proc/handle_happiness()
	switch(happiness)
		if(-5000000 to 19)
			flash_sadness()
			mood_modifier = -10
		if(20 to 39)
			flash_sadness()
			mood_modifier = -5
		if(40 to 59)
			crit_mood_modifier = CRIT_SUCCESS_NORM
		if(60 to 79)
			mood_modifier = 5
		if(80 to INFINITY)
			mood_modifier = 10


/mob/living/carbon/human/proc/add_event(category, type) //Category will override any events in the same category, should be unique unless the event is based on the same thing like hunger.
	var/datum/happiness_event/the_event
	if(events[category])
		the_event = events[category]
		if(the_event.type != type)
			clear_event(category)
			return .()
		else
			return 0 //Don't have to update the event.
	else
		the_event = new type()

	events[category] = the_event
	update_happiness()

	if(the_event.timeout)
		spawn(the_event.timeout)
			clear_event(category)

/mob/living/carbon/human/proc/clear_event(category)
	var/datum/happiness_event/event = events[category]
	if(!event)
		return 0

	events -= category
	qdel(event)
	update_happiness()

/mob/living/carbon/human/proc/handle_hygiene()
	adjust_hygiene(-my_hygiene_factor)
	var/image/smell = image('icons/effects/effects.dmi', "smell")//This is a hack, there has got to be a safer way to do this but I don't know it at the moment.
	switch(hygiene)
		if(HYGIENE_LEVEL_NORMAL to INFINITY)
			add_event("hygiene", /datum/happiness_event/hygiene/clean)
			overlays -= smell
		if(HYGIENE_LEVEL_DIRTY to HYGIENE_LEVEL_NORMAL)
			clear_event("hygiene")
			overlays -= smell
		if(0 to HYGIENE_LEVEL_DIRTY)
			overlays -= smell
			overlays += smell
			add_event("hygiene", /datum/happiness_event/hygiene/smelly)

/mob/living/carbon/human/proc/adjust_hygiene(var/amount)
	var/old_hygiene = hygiene
	if(amount>0)
		hygiene = min(hygiene+amount, HYGIENE_LEVEL_CLEAN)

	else if(old_hygiene)
		hygiene = max(hygiene+amount, 0)

/mob/living/carbon/human/proc/set_hygiene(var/amount)
	if(amount >= 0)
		hygiene = min(HYGIENE_LEVEL_CLEAN, amount)

/mob/living/carbon/human/proc/adjust_thirst(var/amount)
	var/old_thirst = thirst
	if(amount>0)
		thirst = min(thirst+amount, THIRST_LEVEL_MAX)

	else if(old_thirst)
		thirst = max(thirst+amount, 0)

/mob/living/carbon/human/proc/set_thirst(var/amount)
	if(amount >= 0)
		thirst = min(THIRST_LEVEL_MAX, amount)

*/