/mob/living/human/proc/print_mood()
	if (!ishuman(src))
		return
	else
		var/mob/living/human/H = src
		var/msg = ""
		var/msg_hygiene = ""
		switch(mood_tier(mood))
			if(MOOD_TIER_HORRIBLE)
				msg = "Your mood is horrible!"
			if(MOOD_TIER_BAD)
				msg = "Your mood is bad."
			if(MOOD_TIER_NEUTRAL)
				msg = "Your mood is neutral."
			if(MOOD_TIER_GOOD)
				msg = "Your mood is good."
			if(MOOD_TIER_EXCELLENT)
				msg = "Your mood is excellent!"
		msg_hygiene = H.hygiene_feeling()
		if (H.next_dirty_zone())
			msg_hygiene += " Examine yourself to see which parts need washing."
		to_chat(H, "<span class='info'>*---------*</span>")
		to_chat(H, "<span class='info'>[msg]</span>")
		H.print_mood_causes()
		H.print_mood_rest()
		to_chat(H, "<span class='info'>[msg_hygiene]</span>")
		H.print_excrement()
		to_chat(H, "<span class='info'>*---------*</span>")
		return

// Below clean, this follows the parts self-examine marks (body_washing.dm):
// once every part is washed it says so, and skin left under clothes is named.
/mob/living/human/proc/hygiene_feeling()
	if (hygiene >= HYGIENE_LEVEL_CLEAN)
		return "You feel very clean!"
	if (hygiene >= HYGIENE_LEVEL_NORMAL)
		return "You feel clean."
	var/bare_dirty = FALSE
	var/covered_dirty = FALSE
	for (var/obj/item/organ/external/E in organs)
		if (part_dirt_status(E) == "")
			continue
		if (part_is_covered(E))
			covered_dirty = TRUE
		else
			bare_dirty = TRUE
	if (!bare_dirty && !covered_dirty)
		return "You feel fairly clean; soap, a tub or a bath in running water would get you properly clean."
	var/how = hygiene < HYGIENE_LEVEL_DIRTY ? "very dirty" : "a bit dirty"
	if (!bare_dirty)
		return "You feel [how] under your clothes; undress to wash there."
	return hygiene < HYGIENE_LEVEL_DIRTY ? "You feel very dirty!" : "You feel a bit dirty."

/mob/living/human/proc/flash_sadness(ptsd = 1)
	if (ingested.has_reagent("citalopram", 5) || ingested.has_reagent("paroxetine", 3.33)) //antidepressives and anxiolytics block PTSD effects
		return
	if(prob(2*ptsd))
		flick("sadness",HUDtech["pain"])
		var/spoopysound = pick('sound/effects/badmood1.ogg','sound/effects/badmood2.ogg','sound/effects/badmood3.ogg','sound/effects/badmood4.ogg')
		sound_to(src, spoopysound)

// The one mood scale. A boundary value belongs to the higher tier, so mood 40
// is Neutral and mood 60 is Good everywhere.
/proc/mood_tier(value)
	if (value < 20)
		return MOOD_TIER_HORRIBLE
	if (value < 40)
		return MOOD_TIER_BAD
	if (value < 60)
		return MOOD_TIER_NEUTRAL
	if (value < 80)
		return MOOD_TIER_GOOD
	return MOOD_TIER_EXCELLENT

/proc/mood_tier_name(value)
	var/tier = mood_tier(value)
	if (tier == MOOD_TIER_HORRIBLE)
		return "horrible"
	if (tier == MOOD_TIER_BAD)
		return "bad"
	if (tier == MOOD_TIER_NEUTRAL)
		return "neutral"
	if (tier == MOOD_TIER_GOOD)
		return "good"
	return "excellent"

// What mood does to every stat: nothing in Neutral, finer steps outside it.
/proc/mood_stat_modifier(value)
	if (value < 10)
		return 0.8
	if (value < 20)
		return 0.85
	if (value < 30)
		return 0.90
	if (value < 40)
		return 0.95
	if (value < 60)
		return 1
	if (value < 80)
		return 1.05
	if (value < 90)
		return 1.10
	return 1.15

// Extra movement delay from low mood. Neutral and better move freely.
/proc/mood_movement_delay(value)
	var/tier = mood_tier(value)
	if (tier == MOOD_TIER_HORRIBLE)
		return 0.90
	if (tier == MOOD_TIER_BAD)
		return 0.8
	return 0

// The resting level is where mood settles: MOOD_REST moved by lasting
// conditions (company for a sociable character, and so on). Each condition is
// a named part, so the mood panel can say what is holding mood up or down.
/mob/living/human
	var/tmp/list/mood_rest_parts // condition -> change to the resting level
	var/tmp/mood_rest = MOOD_REST
	var/tmp/next_mood_rest_check = 0
	var/tmp/list/mood_rest_told // condition -> world.time it was last announced

/mob/living/human/proc/mood_resting_level()
	if (world.time >= next_mood_rest_check)
		next_mood_rest_check = world.time + MOOD_REST_CHECK
		refresh_mood_rest()
	return mood_rest

// Lasting conditions add themselves here: parts[condition] = change.
/mob/living/human/proc/collect_mood_rest_parts(list/parts)
	return

/mob/living/human/proc/refresh_mood_rest()
	var/list/parts = list()
	if (stat != DEAD)
		collect_mood_rest_parts(parts)
	var/total = 0
	for (var/condition in parts)
		total += parts[condition]
	var/list/before = mood_rest_parts
	mood_rest_parts = parts
	mood_rest = clamp(MOOD_REST + total, MOOD_REST_MIN, MOOD_REST_MAX + home_rest_cap_bonus())
	for (var/condition in parts)
		if (!islist(before) || !(condition in before))
			tell_mood_rest(condition, parts[condition])

// A new condition is announced once, and not again for five minutes, so walking
// in and out of company does not fill the chat.
/mob/living/human/proc/tell_mood_rest(condition, change)
	if (!client || !change)
		return
	if (!islist(mood_rest_told))
		mood_rest_told = list()
	if (isnum(mood_rest_told[condition]) && world.time < mood_rest_told[condition] + 3000)
		return
	mood_rest_told[condition] = world.time
	if (change > 0)
		to_chat(src, "<span class='info'>Your mood will settle higher: [condition].</span>")
	else
		to_chat(src, "<span class='warning'>Your mood will settle lower: [condition].</span>")

/mob/living/human/proc/print_mood_rest()
	if (!islist(mood_rest_parts) || !mood_rest_parts.len)
		return
	to_chat(src, "<span class='info'>Left alone, your mood settles at [mood_tier_name(mood_rest)]. What moves that:</span>")
	for (var/condition in mood_rest_parts)
		var/change = mood_rest_parts[condition]
		var/strength = abs(change) >= 6 ? "a lot" : (abs(change) >= 3 ? "somewhat" : "a little")
		if (change > 0)
			to_chat(src, "<span class='good'>&nbsp;+ [capitalize(condition)]: raises it [strength].</span>")
		else
			to_chat(src, "<span class='bad'>&nbsp;- [capitalize(condition)]: lowers it [strength].</span>")

// Mood settles at the resting level from either side and never overshoots it.
// A lift within MOOD_BOOST_BAND of the resting level fades slowly; anything
// above that burns off fast, so repeated pleasures and drug highs cannot be
// stacked into a lasting peak. Sleep discards the fade (set_mood), the
// recovery still applies.
/mob/living/human/proc/mood_drift()
	if (mood > 120)
		set_mood(120)
	else if (mood < 0)
		set_mood(0)
	var/rest = mood_resting_level()
	if (mood > rest + MOOD_BOOST_BAND)
		set_mood(max(rest, mood - MOOD_BURN))
	else if (mood > rest)
		set_mood(max(rest, mood - MOOD_FADE))
	else if (mood < rest)
		set_mood(min(rest, mood + MOOD_RECOVER))
	if (droid)
		set_mood(100)

/mob/living/human/proc/handle_mood()
	fade_mood_causes()
	mood_modifier = mood_stat_modifier(mood)
	// The sadness flash and its sounds belong to a horrible mood only.
	if (mood_tier(mood) == MOOD_TIER_HORRIBLE)
		flash_sadness((50-mood)/40)


/mob/living/human/proc/handle_hygiene()
	if (sleeping)
		return
	adjust_hygiene(-HYGIENE_FACTOR)
	hygiene_sweat() // hygiene_work.dm
	if (hygiene > HYGIENE_LEVEL_CLEAN)
		hygiene = HYGIENE_LEVEL_CLEAN
	if (hygiene < 0)
		hygiene = 0
	var/image/img_nasties = image('icons/effects/effects.dmi', "nothing")
	switch(hygiene)
		if(HYGIENE_LEVEL_NORMAL to INFINITY)
//			img_nasties.overlays += null
		if(HYGIENE_LEVEL_DIRTY to HYGIENE_LEVEL_NORMAL)
//			overlays_standing[27] = null
		if(0 to HYGIENE_LEVEL_DIRTY)
			var/image/smell = image('icons/effects/effects.dmi', "smell")
			img_nasties.overlays += smell
	if (hygiene <= HYGIENE_LEVEL_DIRTY)
		if (prob(12))
			for(var/mob/living/human/HM in range(3,src))
				if (HM != src && !HM.orc)
					to_chat(HM, "<span class='notice'>You sense a strong, nasty smell coming from [src].</span>")
					HM.adjust_mood(-(1.5), "a nasty smell nearby")
	var/fleas_found = FALSE
	var/typhus_fleas = FALSE
	for (var/obj/item/clothing/C in list(wear_suit,w_uniform,shoes))
		if (C)
			C.gain_dirt(C.blood_DNA ? 0.02 : 0.015)
			// Filthy clothes only slowly pick up fleas, and few of them carry typhus.
			if (!C.fleas && C.dirtyness > 90 && prob(FLEA_INFEST_CHANCE))
				C.fleas = TRUE
				C.flea_typhus = prob(FLEA_TYPHUS_SHARE)
			if (C.fleas)
				fleas_found = TRUE
				if (C.flea_typhus)
					typhus_fleas = TRUE
	if (fleas_found)
		var/image/fleas = image('icons/effects/effects.dmi', "lice_overlay")
		img_nasties.overlays += fleas
		if (!has_fleas)
			to_chat(src, SPAN_WARNING("You feel something biting you. Your filthy clothes are crawling with fleas! Wash them, or you may catch typhus."))
		else if (prob(1))
			to_chat(src, SPAN_WARNING(pick("You scratch at a flea bite.", "Your skin itches and crawls.", "Something bites you under your clothes.")))
		// Only fleas that carry it spread typhus, scaled like every other way of catching an illness.
		var/typhus_chance = typhus_fleas ? FLEA_TYPHUS_RATE * infection_chance_scale("typhus") : 0
		if (typhus_chance > 0 && prob(typhus_chance))
			catch_disease("typhus")
	else if (has_fleas)
		to_chat(src, SPAN_NOTICE("You no longer feel fleas biting you."))
	has_fleas = fleas_found
	// The overlay only changes with the smell and lice states; replacing it every
	// tick depended on Life() redrawing every human once a second.
	var/nasties_state = "[hygiene < HYGIENE_LEVEL_DIRTY ? 1 : 0][fleas_found ? 1 : 0]"
	if (nasties_state != hygiene_overlay_state || !overlays_standing[27])
		hygiene_overlay_state = nasties_state
		overlays_standing[27] = img_nasties
		queue_overlay_redraw()
/mob/living/human/var/tmp/hygiene_overlay_state = null
// Whether the last awake hygiene check found fleas, so the warning shows once.
/mob/living/human/var/tmp/has_fleas = FALSE

/mob/living/human/proc/adjust_hygiene(var/amount)
	var/old_hygiene = hygiene
	if(amount>0)
		hygiene = min(hygiene+amount, HYGIENE_LEVEL_CLEAN)

	else if(old_hygiene)
		hygiene = max(hygiene+amount, 0)

/mob/living/human/proc/set_hygiene(var/amount)
	if(amount >= 0)
		hygiene = min(HYGIENE_LEVEL_CLEAN, amount)

// Washing only ever makes someone cleaner.
/mob/living/human/proc/raise_hygiene(amount)
	if (amount > hygiene)
		set_hygiene(amount)

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
	return key == "mood_causes" || key == "mood_cause_times" || key == "mood_causes_noticed" || key == "mood_rest_parts" || key == "mood_rest" || key == "next_mood_rest_check" || key == "mood_rest_told" || ..()

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
