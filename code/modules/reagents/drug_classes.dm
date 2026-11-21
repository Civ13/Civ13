// Drugs by class: dependence, tolerance, cross-relief, mixing, lasting harm
// and the signs other players can see. Every drug gives a clear benefit and
// carries a clear cost, including dangerous ones.
//
// addictions[class]     0-100 dependence. Withdrawal while none of the class
//                       is in the body. Falls 0.05 a Life tick.
// drug_tolerance[class] 0-100. Regular use blunts mood and painkilling and
//                       raises the overdose threshold. Falls 0.15 a Life tick,
//                       faster than dependence, so a user who relapses after a
//                       break and takes their old dose can overdose.
// Heavy use (dependence 60+) slowly damages one organ per class.
// Withdrawal is miserable but only alcohol withdrawal can kill (as before).

#define DRUG_DEPENDENCE_DECAY 0.05
#define DRUG_TOLERANCE_DECAY 0.15
#define DRUG_HEAVY_USE 60

/mob/living/human/var/list/drug_tolerance = list()

// class -> reagent ids that belong to it. Ids not in the game yet are harmless.
/proc/drug_class_reagents()
	return list(
		"opioid" = list("opium", "morphine", "tramadol", "laudanum", "heroin", "poppy_tea"),
		"stimulant" = list("cocaine", "crack", "methamphetamine", "dragon_powder", "coca_leaf", "coca_tea", "khat"),
		"nicotine" = list("nicotine"),
		"cannabis" = list("thc"),
		"caffeine" = list("coffee"),
		"alcohol" = list(), // every /datum/reagent/ethanol
	)

/proc/drug_classes()
	return list("opioid", "stimulant", "nicotine", "cannabis", "caffeine", "alcohol")

// Old saved keys from before drugs had classes.
/proc/drug_legacy_class(key)
	switch (key)
		if ("cocaine")
			return "stimulant"
		if ("opium")
			return "opioid"
		if ("tobacco")
			return "nicotine"
	return key

/proc/drug_reagent_class(datum/reagent/R)
	if (!R)
		return null
	if (istype(R, /datum/reagent/ethanol))
		return "alcohol"
	if (istype(R, /datum/reagent/drink/coffee))
		return "caffeine"
	var/list/table = drug_class_reagents()
	for (var/class in table)
		if (R.id in table[class])
			return class
	return null

// Reagents of the class in the bloodstream or stomach.
/mob/living/human/proc/drug_class_reagent_ids(class)
	. = list()
	for (var/datum/reagents/holder in list(reagents, ingested))
		for (var/datum/reagent/R in holder.reagent_list)
			if (R.volume > 0 && drug_reagent_class(R) == class)
				. |= R.id

/mob/living/human/proc/drug_class_active(class)
	var/list/ids = drug_class_reagent_ids(class)
	return ids.len > 0

// A dose of a class: dependence and tolerance build with use.
/mob/living/human/proc/drug_dose(class, dependence, tolerance)
	if (!class)
		return
	addictions[class] = clamp((addictions[class] || 0) + dependence, 0, 100)
	drug_tolerance[class] = clamp((drug_tolerance[class] || 0) + tolerance, 0, 100)

// 1 with no tolerance, 0.4 at full tolerance.
/mob/living/human/proc/drug_effect_scale(class)
	return 1 - 0.6 * (drug_tolerance[class] || 0) / 100

/mob/living/human/proc/drug_mood(class, amount, reason)
	adjust_mood(amount * drug_effect_scale(class), reason)

/mob/living/human/proc/drug_painkiller(class, amount)
	add_chemical_effect(CE_PAINKILLER, round(amount * drug_effect_scale(class)))

// Stimulants restore stamina, up to the diet's stamina cap (as coffee does).
/mob/living/human/proc/drug_stamina(class, amount)
	if (!islist(stats) || !islist(stats["stamina"]))
		return
	var/cap = diet_stamina_cap()
	if (stats["stamina"][1] < cap)
		stats["stamina"][1] = min(cap, stats["stamina"][1] + amount * drug_effect_scale(class))

// A stimulant overdose drives the heart until it fails.
/mob/living/human/proc/drug_heart_strain(amount)
	add_chemical_effect(CE_PULSE, 3)
	var/obj/item/organ/heart/heart = internal_organs_by_name["heart"]
	if (heart)
		heart.take_damage(amount, TRUE)
	else
		adjustOxyLoss(amount)
	if (prob(8))
		to_chat(src, "<span class='danger'>Your chest tightens and your heart stutters.</span>")

// Overdose threshold, raised by tolerance (Chemistry-Reagents.dm on_mob_life).
/datum/reagent/proc/overdose_limit(mob/living/M)
	var/mob/living/human/H = M
	if (!overdose || !istype(H))
		return overdose
	var/class = drug_reagent_class(src)
	if (!class || class == "alcohol")
		return overdose
	return overdose * (1 + (H.drug_tolerance[class] || 0) / 100)

// One Life tick (human_life.dm).
/mob/living/human/proc/handle_drugs()
	if (!islist(addictions))
		addictions = list()
	if (!islist(drug_tolerance))
		drug_tolerance = list()
	for (var/key in addictions.Copy())
		var/class = drug_legacy_class(key)
		if (class != key)
			addictions[class] = min(100, (addictions[class] || 0) + (addictions[key] || 0))
			addictions -= key
	for (var/class in addictions)
		var/value = addictions[class]
		if (!isnum(value) || value <= 0)
			addictions[class] = 0
			continue
		process_addictions(class, value)
		drug_lasting_harm(class, value)
		addictions[class] = max(0, value - DRUG_DEPENDENCE_DECAY)
	for (var/class in drug_tolerance)
		var/value = drug_tolerance[class]
		drug_tolerance[class] = isnum(value) ? max(0, value - DRUG_TOLERANCE_DECAY) : 0
	drug_mixing()

// Two depressants stop breathing at a far lower dose; two stimulants strain the heart.
/mob/living/human/proc/drug_mixing()
	if (stat == DEAD)
		return
	if (drug_class_active("opioid") && drug_class_active("alcohol"))
		adjustOxyLoss(2)
		if (losebreath < 5 && prob(30))
			losebreath++
		if (prob(5))
			to_chat(src, "<span class='danger'>Your breathing is slow and shallow.</span>")
	var/list/stimulants = drug_class_reagent_ids("stimulant")
	if (stimulants.len >= 2)
		add_chemical_effect(CE_PULSE, 2)
		var/obj/item/organ/heart/heart = internal_organs_by_name["heart"]
		if (heart && prob(25))
			heart.take_damage(1, TRUE)
		if (prob(5))
			to_chat(src, "<span class='danger'>Your heart is pounding against your ribs.</span>")

// Heavy use over a long time leaves lasting damage that heals slowly.
/mob/living/human/proc/drug_lasting_harm(class, value)
	if (value < DRUG_HEAVY_USE || stat == DEAD || !prob(2))
		return
	var/organ_name = null
	switch (class)
		if ("nicotine")
			organ_name = "lungs"
			if (prob(30))
				emote("cough")
		if ("stimulant")
			organ_name = "heart"
		if ("alcohol")
			organ_name = "liver"
	if (!organ_name)
		return
	var/obj/item/organ/O = internal_organs_by_name[organ_name]
	if (O && O.damage < O.min_bruised_damage)
		O.take_damage(0.5, TRUE)

// What other players can see on examine: courts and doctors can act on it.
/mob/living/human/proc/drug_examine_text(datum/gender/T)
	. = ""
	if (!T || stat == DEAD)
		return
	if (drug_class_active("opioid"))
		. += "<span class='warning'>[T.His] pupils are pinpoint and [T.he] [T.is] half asleep.</span>\n"
	if (drug_class_active("stimulant"))
		. += "<span class='warning'>[T.His] pupils are wide and [T.he] can't keep still.</span>\n"
	if (drug_class_active("cannabis"))
		. += "<span class='notice'>[T.His] eyes are red and heavy-lidded.</span>\n"
	if (drug_class_active("nicotine"))
		. += "<span class='notice'>The smell of tobacco smoke hangs about [T.him].</span>\n"
	for (var/class in list("opioid", "stimulant", "alcohol"))
		if ((addictions[class] || 0) >= 56 && !drug_class_active(class))
			. += "<span class='warning'>[T.His] hands are shaking.</span>\n"
			break

#undef DRUG_DEPENDENCE_DECAY
#undef DRUG_TOLERANCE_DECAY
#undef DRUG_HEAVY_USE
