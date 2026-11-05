// ============================================================
// Outside exposure (space settlement, ahead of phase 4 suits)
// ------------------------------------------------------------
// The two turf hooks in barren_world.dm are read here, once per human life
// tick, by the breathing and temperature steps the mob already runs. No
// process scans turfs. On every shipped map both hooks answer "ordinary
// ground", so nothing changes until a barren region exists.
//
// Suits (phase 4) override sealed_against_outside(); until then anyone on
// unbreathable ground suffocates at HABITAT_SUFFOCATE_OXYLOSS per tick, which
// knocks a conscious person out in about a minute (decision D4) rather than
// killing them at once, so crewmates can drag them inside.
// ============================================================

// TRUE once a sealed suit with air keeps the outside out (phase 4).
/mob/living/human/proc/sealed_against_outside()
	return FALSE

// The temperature this ground imposes on someone standing in the open, or
// null to keep the ordinary weather and climate temperature.
/mob/living/human/proc/outside_temperature_c(turf/T)
	if (!istype(T) || sealed_against_outside())
		return null
	return T.outside_ambient_c()

// One breath on this ground. Returns TRUE when the air could not be breathed.
/mob/living/human/proc/outside_exposure_step(turf/T)
	if (!istype(T) || stat == DEAD || T.outside_air_breathable() || sealed_against_outside())
		return FALSE
	losebreath = max(losebreath + 1, 1)
	adjustOxyLoss(HABITAT_SUFFOCATE_OXYLOSS)
	if (prob(8))
		to_chat(src, SPAN_DANGER("There is nothing to breathe out here!"))
	return TRUE
