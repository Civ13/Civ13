/mob/living/carbon/human/proc/print_happiness()
//	var/msg = "\n<span class='info'>I am a follower of <font color='red'>[religion]</font></span>.\n"
//	msg += "<span class='info'>I am [get_social_class()]</span>.\n"
	var/msg += "<span class='info'>*---------*\n<EM>Current mood</EM>\n"
	for(var/i in events)
		var/datum/happiness_event/event = events[i]
		msg += event.description

	if(!events.len)
		msg += "<span class='info'>I feel indifferent.</span>\n"


	msg += "<span class='info'>*---------*</span>"
	to_chat(src, msg)

/mob/living/carbon/human/proc/update_happiness()
	var/old_mood = mood
	var/old_icon = null
	if(mood_icon)
	old_icon = H.HUDneed["mood"].icon_state
/*
	happiness = 0
	for(var/i in events)
		var/datum/happiness_event/event = events[i]
		happiness += event.happiness
*/
	switch(mood)
		if(-5000000 to 19)
			if(happiness_icon)
				happiness_icon.icon_state = "mood5"

		if(20 to 39)
			if(happiness_icon)
				happiness_icon.icon_state = "mood4"

		if(40 to 59)
			if(happiness_icon)
				happiness_icon.icon_state = "mood3"

		if(60 to 79)
			if(happiness_icon)
				happiness_icon.icon_state = "mood2"

		if(80 to INFINITY)
			if(happiness_icon)
				happiness_icon.icon_state = "mood1"

	if(old_icon && old_icon != mood.icon_state)
		if(old_happiness > happiness)
			src << "<span class='warning'>My mood gets worse.</span>"
		else
			src << "<span class='info'>My mood gets better.</span>"

/mob/proc/flash_sadness()
	if(prob(2))
		flick("sadness",pain)
		var/spoopysound = pick('sound/effects/badmood1.ogg','sound/effects/badmood2.ogg','sound/effects/badmood3.ogg','sound/effects/badmood4.ogg')
		sound_to(src, spoopysound)

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

/*
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