// Gameplay balance, not a model of real disease or medical treatment.
// One call per existing /process/mob tick (nominally one second).

// Pain an illness alone can hold a patient at. Traumatic shock counts half of
// it, so neither ceiling reaches the 80 that starts shock on its own.
#define SEVERE_DISEASE_PAIN 30
#define SEVERE_DISEASE_PAIN_CRITICAL 60
/mob/living/human/proc/is_severe_disease()
	return disease && (disease_type in list("plague", "typhus", "malaria", "cholera"))

/mob/living/human/proc/clear_disease()
	// Pain is shared with injuries and other causes. Stop adding illness pain;
	// normal recovery clears the remainder without erasing unrelated trauma.
	disease = FALSE
	disease_type = "none"
	disease_progression = 0
	disease_treatment = 0
	disease_course = 0

/mob/living/human/proc/handle_severe_disease()
	// Dead, disconnected, transforming and explicitly invulnerable actors do
	// not count as normal active susceptible gameplay. No offline catch-up.
	if (inducedSSD || (status_flags & GODMODE))
		disease_treatment = 0
		return
	var/treatment = disease_treatment
	disease_treatment = 0 // Metabolism must renew it on the next Life call.
	if (treatment > 0)
		disease_course = min(180, round(disease_course + treatment, 0.01))
		if (disease_course >= 180)
			clear_disease()
			bodytemperature = min(bodytemperature, species.body_temperature)
			to_chat(src, SPAN_NOTICE("Your treatment course is complete. The illness has cleared."))
			return
	else
		disease_course = 0 // An interrupted course must be restarted.
		disease_progression = min(1200, disease_progression + 1)
		if (disease_progression == 1)
			to_chat(src, SPAN_WARNING("You feel seriously ill. Medicine will shorten the illness; rest and protect yourself while you recover."))
		if (disease_progression == 180)
			to_chat(src, SPAN_WARNING("Your illness is worsening. You feel weak and feverish. Complete a medicine course to recover sooner."))
		if (disease_progression == 900)
			to_chat(src, SPAN_DANGER("Your illness is severe! Rest and seek continuous treatment."))
	// Symptoms remain meaningful during treatment, but never cause a random
	// early lethal toxin/brain spike or timer death. Existing immunity clears
	// untreated disease after about 2000 active ticks. Other injuries, oxygen
	// loss, starvation and infections remain dangerous independently.
	if (disease_progression >= 180)
		set_mood(max(0, mood - 0.1), "being sick")
		apply_effect(3, DROWSY, FALSE)
		// Illness keeps a steady ache rather than stacking pain every tick:
		// resting only clears 1-3 a second, so an uncapped +3 reached
		// traumatic shock in about 15 minutes with almost no real damage.
		var/pain_cap = disease_progression >= 900 ? SEVERE_DISEASE_PAIN_CRITICAL : SEVERE_DISEASE_PAIN
		if (halloss < pain_cap)
			apply_effect(min(3, pain_cap - halloss), AGONY, FALSE)
		if (disease_progression >= 900)
			apply_effect(6, DROWSY, FALSE)
			Weaken(2)
		if (life_tick % 30 == 0)
			emote(disease_type == "cholera" ? "shiver" : "cough")
			to_chat(src, SPAN_WARNING("You feel weak from your illness."))

/mob/living/human/proc/receive_disease_treatment(rate)
	if (is_severe_disease() || (disease && disease_type == "worms"))
		disease_treatment = max(disease_treatment, rate)
	else if (disease && disease_type == "flu")
		disease_treatment = TRUE

// Illnesses that pass between people standing close together. Cholera comes
// only from swallowed germs (unboiled water) and typhus only from fleas, so
// neither spreads from a sick person or a body.
var/global/list/contagious_diseases = list("flu", "plague")

// Germ reagents and the illness each one carries. Malaria lives only in the
// blood, so it infects by injection or transfusion and never by swallowing.
var/global/list/germ_reagent_disease = list("cholera" = "cholera", "typhus" = "typhus", "plague" = "plague", "worm_eggs" = "worms", "malaria" = "malaria")

// Germs swallowed in food or drink get one infection roll per swallow, scaled
// by the dose actually swallowed: 25% per unit. The germ reagents themselves
// are inert in the stomach, so this roll is the only ingestion route.
var/global/list/swallowed_germs = list("cholera", "typhus", "plague", "worm_eggs")
// Dirty water (the cholera reagent) also carries worm eggs: a third the chance.
#define DIRTY_WATER_WORMS 0.33

/mob/living/human/proc/swallow_germs(datum/reagents/swallowed)
	if (!swallowed || disease || droid || orc || crab || inducedSSD || (status_flags & GODMODE))
		return null
	var/dmod = 1
	if (find_trait("Weak Immune System"))
		dmod = 2
	if (find_trait("Strong Immune System"))
		dmod = 0.2
	for (var/germ in swallowed_germs)
		var/amount = swallowed.get_reagent_amount(germ)
		var/kind = germ_reagent_disease[germ]
		if (amount <= 0 || (kind in disease_immunity) || resists_disease(kind))
			continue
		if (prob(min(amount * 25 * dmod, 100)))
			catch_disease(kind)
			return kind
	var/dirty = swallowed.get_reagent_amount("cholera")
	if (dirty > 0 && !("worms" in disease_immunity) && prob(min(dirty * 25 * dmod * DIRTY_WATER_WORMS, 100)))
		catch_disease("worms")
		return "worms"
	return null

/mob/living/human/proc/catch_disease(kind)
	disease = TRUE
	disease_type = kind
	disease_progression = 0
	disease_treatment = 0
	disease_course = 0

// Drinking straight from dirty water: cholera at the given chance, otherwise
// worms at a third of it. Strong and Weak Immune System scale both.
/mob/living/human/proc/catch_dirty_water_illness(chance)
	if (disease || droid || orc || crab)
		return null
	if (find_trait("Weak Immune System"))
		chance *= 2
	if (find_trait("Strong Immune System"))
		chance *= 0.2
	if (prob(chance) && !resists_disease("cholera") && !("cholera" in disease_immunity))
		catch_disease("cholera")
		return "cholera"
	if (prob(chance * DIRTY_WATER_WORMS) && !("worms" in disease_immunity))
		catch_disease("worms")
		return "worms"
	return null

// The germ a sick person's blood (or, with meat, their flesh) carries.
// Flu and zombie infection do not pass this way.
/mob/living/human/proc/carried_germ(meat = FALSE)
	if (!disease)
		return null
	switch (disease_type)
		if ("cholera", "typhus", "plague")
			return disease_type
		if ("malaria")
			return meat ? null : "malaria"
		if ("worms")
			return meat ? "worm_eggs" : null
	return null

// Cooking and boiling kill every germ in food or drink.
/datum/reagents/proc/kill_germs()
	for (var/germ in germ_reagent_disease)
		del_reagent(germ)

// Lying buckled in a real bed (not a chair) speeds recovery.
/mob/living/human/proc/resting_in_bed()
	if (!buckled)
		return FALSE
	if (istype(buckled, /obj/structure/bed/chair))
		return FALSE
	return istype(buckled, /obj/structure/bed) || istype(buckled, /obj/structure/medicalbed) || istype(buckled, /obj/structure/optable)

/mob/living/human/proc/acquire_nearby_disease()
	if (inducedSSD || droid || disease)
		return
	for (var/mob/living/human/H in range(2, src))
		if (H == src || !H.disease || (H.disease_type in disease_immunity) || resists_disease(H.disease_type) || !(H.disease_type in contagious_diseases))
			continue
		var/chance = (H.stat == DEAD ? 3 : 1) * disease_node_scale()
		if (find_trait("Weak Immune System"))
			chance *= 2
		if (istype(wear_mask, /obj/item/clothing/mask/sterile))
			chance *= 0.5
		if (H.disease_type == "flu" && istype(H.wear_mask, /obj/item/clothing/mask/sterile))
			continue
		if (prob(chance))
			disease = TRUE
			disease_type = H.disease_type
			disease_progression = 0
			disease_treatment = 0
			disease_course = 0
			return
	if (map && map.civilizations && hygiene < HYGIENE_LEVEL_DIRTY && !("flu" in disease_immunity) && !resists_disease("flu"))
		if (prob((find_trait("Weak Immune System") ? 0.4 : 0.2) * disease_node_scale()))
			disease = TRUE
			disease_type = "flu"
			disease_progression = 0
			disease_treatment = 0

#undef DIRTY_WATER_WORMS
#undef SEVERE_DISEASE_PAIN
#undef SEVERE_DISEASE_PAIN_CRITICAL
