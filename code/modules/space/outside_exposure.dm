// ============================================================
// Outside exposure (space settlement)
// ------------------------------------------------------------
// The two turf hooks in barren_world.dm are read here, once per human life
// tick, by the breathing and temperature steps the mob already runs. No
// process scans turfs. On every shipped map both hooks answer "ordinary
// ground", so nothing changes until a barren region exists.
//
// A sealed pressure suit (pressure_suits.dm) keeps the outside out: the
// wearer breathes from the tank and the heater holds room temperature.
// Anyone else on unbreathable ground suffocates at HABITAT_SUFFOCATE_OXYLOSS
// per tick, which knocks a conscious person out in about a minute (decision
// D4) rather than killing them at once, so crewmates can drag them inside.
// Surface hazards (surface_hazards.dm) act on people on open ground here, and
// a sealed rover cabin (surface_rovers.dm) stands in for the ground's air.
// ============================================================

// TRUE while a sealed suit with air keeps the outside out.
/mob/living/human/proc/sealed_against_outside()
	return pressure_suit_sealed()

// The temperature this ground imposes on someone standing in the open, or
// null to keep the ordinary weather and climate temperature.
/mob/living/human/proc/outside_temperature_c(turf/T)
	if (!istype(T))
		return null
	var/ambient = T.outside_ambient_c()
	if (isnull(ambient))
		return null
	var/datum/habitat_ledger/cabin = T.outside_air_breathable() ? null : rover_cabin()
	if (cabin)
		if (cabin.breathable())
			return cabin.temperature
		ambient = cabin.temperature
	if (!sealed_against_outside())
		return ambient
	return pressure_suit_temperature_c(ambient)

// One breath on this ground. Returns TRUE when the air could not be breathed.
/mob/living/human/proc/outside_exposure_step(turf/T)
	if (!istype(T) || stat == DEAD)
		return FALSE
	// A sealed rover cabin (surface_rovers.dm) shelters and holds its own air.
	var/datum/habitat_ledger/cabin = T.outside_air_breathable() ? null : rover_cabin()
	if (cabin)
		if (cabin.breathable())
			return FALSE
	else
		if (T.barren_open_ground())
			barren_hazard_exposure(T)
		if (T.outside_air_breathable())
			return FALSE
	if (sealed_against_outside())
		pressure_suit_breathe()
		return FALSE
	losebreath = max(losebreath + 1, 1)
	adjustOxyLoss(HABITAT_SUFFOCATE_OXYLOSS)
	if (prob(8))
		to_chat(src, SPAN_DANGER("There is nothing to breathe out here!"))
	return TRUE
