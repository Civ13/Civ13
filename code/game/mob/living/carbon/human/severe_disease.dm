// Gameplay balance, not a model of real disease or medical treatment.
// One call per existing /process/mob tick (nominally one second).

// Pain an illness alone can hold a patient at. Traumatic shock counts half of
// it, so neither ceiling reaches the 80 that starts shock on its own.
#define SEVERE_DISEASE_PAIN 30
#define SEVERE_DISEASE_PAIN_CRITICAL 60
/mob/living/human/proc/is_severe_disease()
	return disease && (disease_type in list("plague", "typhus", "malaria", "cholera"))

/mob/living/human/proc/clear_disease()
	// A cure ends the illness ache too: drop any pain it piled up back to the
	// illness ceiling, and normal recovery (1-3 a second) clears the rest.
	if (disease && is_severe_disease())
		halloss = min(halloss, SEVERE_DISEASE_PAIN_CRITICAL)
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
			to_chat(src, SPAN_WARNING("You feel seriously ill. Seek medicine now; this illness will not clear on its own."))
		if (disease_progression == 180)
			to_chat(src, SPAN_WARNING("Your illness is worsening. You feel weak and feverish. Complete a medicine course before it becomes fatal."))
		if (disease_progression == 900)
			to_chat(src, SPAN_DANGER("Your illness is critical! You need continuous treatment immediately."))
		if (disease_progression >= 1200)
			to_chat(src, SPAN_DANGER("The untreated illness overwhelms your body."))
			death()
			return
	// Symptoms remain meaningful during treatment, but never cause a random
	// early lethal toxin/brain spike. Other injuries/starvation still matter.
	if (disease_progression >= 180)
		set_mood(max(0, mood - 0.1))
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
	if (is_severe_disease())
		disease_treatment = max(disease_treatment, rate)
	else if (disease && disease_type == "flu")
		disease_treatment = TRUE

/mob/living/human/proc/acquire_nearby_disease()
	if (inducedSSD || droid || disease)
		return
	for (var/mob/living/human/H in range(2, src))
		if (H == src || !H.disease || (H.disease_type in disease_immunity) || (H.disease_type in list("none", "malaria", "zombie")))
			continue
		var/chance = H.stat == DEAD ? 3 : 1
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
	if (map && map.civilizations && hygiene < HYGIENE_LEVEL_DIRTY && !("flu" in disease_immunity))
		if (prob(find_trait("Weak Immune System") ? 0.4 : 0.2))
			disease = TRUE
			disease_type = "flu"
			disease_progression = 0
			disease_treatment = 0

#undef SEVERE_DISEASE_PAIN
#undef SEVERE_DISEASE_PAIN_CRITICAL
