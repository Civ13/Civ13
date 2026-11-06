// Gameplay balance, not a model of real immunology.
// Bodies slowly learn to fight what they are exposed to: an illness builds
// resistance to itself while it runs, enough resistance clears it and keeps
// it away for a while, and repeated doses of a poison hurt less over time.
// One call per existing /process/mob tick (nominally one second).

// Resistance runs 0-100 per illness. At 100 the body clears the illness.
#define IMMUNITY_FULL 100
// While resistance stays at or above this, a new infection never takes hold.
#define IMMUNITY_PROTECTS 50
// Untreated, resistance reaches 100 after about 33 minutes, well after a
// severe illness kills (20 minutes), so medicine is still needed.
#define IMMUNITY_GAIN_UNTREATED 0.05
// While medicine supports the body, resistance reaches 100 in about 11
// minutes even if courses keep being interrupted.
#define IMMUNITY_GAIN_TREATED 0.15
// Protection fades: 100 drops below 50 after about 55 minutes of play.
#define IMMUNITY_DECAY 0.015

// Poison tolerance: exposure is the units of that poison the body has
// processed. Damage falls by up to half, reaching a quarter off at 30 units.
#define POISON_TOLERANCE_MAX_REDUCTION 0.5
#define POISON_TOLERANCE_HALF 30
#define POISON_TOLERANCE_CAP 200
#define POISON_TOLERANCE_DECAY 0.005

/mob/living/human/proc/builds_disease_immunity(kind)
	return kind in list("flu", "plague", "typhus", "malaria", "cholera")

/mob/living/human/proc/disease_resistance_to(kind)
	if (!(kind in disease_resistance))
		return 0
	return disease_resistance[kind]

// TRUE while recent resistance keeps this illness from taking hold.
/mob/living/human/proc/resists_disease(kind)
	return builds_disease_immunity(kind) && disease_resistance_to(kind) >= IMMUNITY_PROTECTS

// Returns TRUE when it cleared the current illness this tick.
/mob/living/human/proc/handle_immunity()
	if (inducedSSD || (status_flags & GODMODE))
		return FALSE
	var/fighting = disease && builds_disease_immunity(disease_type) ? disease_type : null

	var/list/faded = list()
	for (var/kind in disease_resistance)
		if (kind == fighting)
			continue
		disease_resistance[kind] = max(0, disease_resistance[kind] - IMMUNITY_DECAY)
		if (disease_resistance[kind] <= 0)
			faded += kind
	disease_resistance -= faded

	faded = list()
	for (var/id in poison_exposure)
		poison_exposure[id] = max(0, poison_exposure[id] - POISON_TOLERANCE_DECAY)
		if (poison_exposure[id] <= 0)
			faded += id
	poison_exposure -= faded

	if (!fighting)
		disease_resist_checked = "none"
		return FALSE

	var/resistance = disease_resistance_to(fighting)
	if (disease_resist_checked != fighting)
		// First tick of a new infection, however it was caught.
		disease_resist_checked = fighting
		if (resists_disease(fighting))
			clear_disease()
			to_chat(src, SPAN_NOTICE("You feel a passing chill, but your body has fought this illness before and shakes it off."))
			return TRUE

	var/gain = disease_treatment > 0 ? IMMUNITY_GAIN_TREATED : IMMUNITY_GAIN_UNTREATED
	var/updated = min(IMMUNITY_FULL, round(resistance + gain, 0.001))
	disease_resistance[fighting] = updated
	if (resistance < IMMUNITY_PROTECTS && updated >= IMMUNITY_PROTECTS)
		to_chat(src, SPAN_NOTICE("Your body is starting to fight off the illness."))
	if (updated >= IMMUNITY_FULL)
		clear_disease()
		bodytemperature = min(bodytemperature, species.body_temperature)
		to_chat(src, SPAN_NOTICE("Your body has fought off the illness. You feel much better, and it won't take hold again for a while."))
		return TRUE
	return FALSE

// Damage multiplier for a dose of poison; removed > 0 also records the dose.
/mob/living/proc/poison_tolerance(id, removed, poison_name)
	return 1

/mob/living/human/poison_tolerance(id, removed, poison_name)
	var/exposure = (id in poison_exposure) ? poison_exposure[id] : 0
	var/factor = 1 - POISON_TOLERANCE_MAX_REDUCTION * exposure / (exposure + POISON_TOLERANCE_HALF)
	if (removed > 0)
		var/updated = min(POISON_TOLERANCE_CAP, exposure + removed)
		poison_exposure[id] = updated
		if (exposure < POISON_TOLERANCE_HALF && updated >= POISON_TOLERANCE_HALF)
			to_chat(src, SPAN_NOTICE("Your body is getting used to [poison_name ? poison_name : "this poison"]."))
	return factor

#undef IMMUNITY_FULL
#undef IMMUNITY_PROTECTS
#undef IMMUNITY_GAIN_UNTREATED
#undef IMMUNITY_GAIN_TREATED
#undef IMMUNITY_DECAY
#undef POISON_TOLERANCE_MAX_REDUCTION
#undef POISON_TOLERANCE_HALF
#undef POISON_TOLERANCE_CAP
#undef POISON_TOLERANCE_DECAY
