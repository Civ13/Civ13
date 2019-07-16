/* General medicine */

/datum/reagent/adrenaline
	name = "Adrenaline"
	id = "adrenaline"
	description = "Adrenaline is used to treat shock and stabilize patients before advanced medical care."
	taste_description = "bitterness"
	reagent_state = LIQUID
	color = "#00BFFF"
	overdose = REAGENTS_OVERDOSE * 3 //3 doses
	metabolism = REM * 0.5
	scannable = TRUE

/datum/reagent/adrenaline/affect_blood(var/mob/living/carbon/M, var/alien, var/removed)
	M.add_chemical_effect(CE_STABLE)
	M.add_chemical_effect(CE_PAINKILLER, 5)
	M.add_chemical_effect(CE_PULSE, 1)
	M.traumatic_shock = max(0,M.traumatic_shock-removed)
	M.shock_stage = max(0,M.shock_stage-removed/2)
	M.mood += removed*4
	M.SetParalysis(0)
	M.SetWeakened(0)

/datum/reagent/anti_toxin
	name = "Anti-toxin"
	id = "anti_toxin"
	description = "A broad-spectrum antitoxin preparation."
	taste_description = "a roll of gauze"
	reagent_state = LIQUID
	color = "#00A000"
	scannable = TRUE

/datum/reagent/anti_toxin/affect_blood(var/mob/living/carbon/M, var/alien, var/removed)
	M.drowsyness = max(0, M.drowsyness - 6 * removed)
	M.hallucination = max(0, M.hallucination - 9 * removed)
	M.adjustToxLoss(-4 * removed)

/datum/reagent/tricordrazine
	name = "Tricordrazine"
	id = "tricordrazine"
	description = "Tricordrazine is a highly potent stimulant, originally derived from cordrazine. Can be used to treat a wide range of injuries."
	taste_description = "grossness"
	reagent_state = LIQUID
	color = "#8040FF"
	scannable = TRUE

/datum/reagent/tricordrazine/affect_blood(var/mob/living/carbon/M, var/alien, var/removed)
	M.adjustOxyLoss(-6 * removed)
	M.heal_organ_damage(3 * removed, 3 * removed)
	M.adjustToxLoss(-3 * removed)

/* Painkillers */

/datum/reagent/paracetamol
	name = "Paracetamol"
	id = "paracetamol"
	description = "Most probably know this as Tylenol, but this chemical is a mild, simple painkiller."
	taste_description = "sickness"
	reagent_state = LIQUID
	color = "#C8A5DC"
	overdose = 60
	scannable = TRUE
	metabolism = 0.02

/datum/reagent/paracetamol/affect_blood(var/mob/living/carbon/M, var/alien, var/removed)
	M.add_chemical_effect(CE_PAINKILLER, 50)

/datum/reagent/paracetamol/overdose(var/mob/living/carbon/M, var/alien)
	..()
	M.hallucination = max(M.hallucination, 2)

/datum/reagent/tramadol
	name = "Tramadol"
	id = "tramadol"
	description = "A simple, yet effective painkiller."
	taste_description = "sourness"
	reagent_state = LIQUID
	color = "#CB68FC"
	overdose = 30
	scannable = TRUE
	metabolism = 0.02

/datum/reagent/tramadol/affect_blood(var/mob/living/carbon/M, var/alien, var/removed)
	M.add_chemical_effect(CE_PAINKILLER, 80)
	M.mood += removed*3
/datum/reagent/tramadol/overdose(var/mob/living/carbon/M, var/alien)
	..()
	M.hallucination = max(M.hallucination, 2)

/datum/reagent/oxycodone
	name = "Oxycodone"
	id = "oxycodone"
	description = "An effective and very addictive painkiller."
	taste_description = "bitterness"
	reagent_state = LIQUID
	color = "#800080"
	overdose = 20
	metabolism = 0.02

/datum/reagent/oxycodone/affect_blood(var/mob/living/carbon/M, var/alien, var/removed)
	M.add_chemical_effect(CE_PAINKILLER, 200)

/datum/reagent/oxycodone/overdose(var/mob/living/carbon/M, var/alien)
	..()
	M.druggy = max(M.druggy, 10)
	M.hallucination = max(M.hallucination, 3)

/* Other medicine */

/datum/reagent/synaptizine
	name = "Synaptizine"
	id = "synaptizine"
	description = "Synaptizine is used to treat various diseases."
	taste_description = "bitterness"
	reagent_state = LIQUID
	color = "#99CCFF"
	metabolism = REM * 0.05
	overdose = REAGENTS_OVERDOSE
	scannable = TRUE

/datum/reagent/synaptizine/affect_blood(var/mob/living/carbon/M, var/alien, var/removed)
	M.drowsyness = max(M.drowsyness - 5, FALSE)
	M.AdjustParalysis(-1)
	M.AdjustStunned(-1)
	M.AdjustWeakened(-1)
	holder.remove_reagent("mindbreaker", 5)
	M.hallucination = max(0, M.hallucination - 10)
	M.adjustToxLoss(5 * removed) // It used to be incredibly deadly due to an oversight. Not anymore!
	M.add_chemical_effect(CE_PAINKILLER, 40)

/datum/reagent/alkysine
	name = "Alkysine"
	id = "alkysine"
	description = "Alkysine is a drug used to lessen the damage to neurological tissue after a catastrophic injury. Can heal brain tissue."
	taste_description = "bitterness"
	reagent_state = LIQUID
	color = "#FFFF66"
	metabolism = REM * 0.25
	overdose = REAGENTS_OVERDOSE
	scannable = TRUE

/datum/reagent/alkysine/affect_blood(var/mob/living/carbon/M, var/alien, var/removed)
	M.adjustBrainLoss(-30 * removed)
	M.add_chemical_effect(CE_PAINKILLER, 10)

/datum/reagent/imidazoline
	name = "Imidazoline"
	id = "imidazoline"
	description = "Heals eye damage."
	taste_description = "dull toxin"
	reagent_state = LIQUID
	color = "#C8A5DC"
	overdose = REAGENTS_OVERDOSE
	scannable = TRUE

/datum/reagent/imidazoline/affect_blood(var/mob/living/carbon/M, var/alien, var/removed)
	M.eye_blurry = max(M.eye_blurry - 5, FALSE)
	M.eye_blind = max(M.eye_blind - 5, FALSE)
	if (ishuman(M))
		var/mob/living/carbon/human/H = M
		var/obj/item/organ/eyes/E = H.internal_organs_by_name["eyes"]
		if (E && istype(E))
			if (E.damage > 0)
				E.damage = max(E.damage - 5 * removed, FALSE)

/datum/reagent/peridaxon
	name = "Peridaxon"
	id = "peridaxon"
	description = "Used to encourage recovery of internal organs and nervous systems. Medicate cautiously."
	taste_description = "bitterness"
	reagent_state = LIQUID
	color = "#561EC3"
	overdose = 10
	scannable = TRUE

/datum/reagent/peridaxon/affect_blood(var/mob/living/carbon/M, var/alien, var/removed)
	if (ishuman(M))
		var/mob/living/carbon/human/H = M

		for (var/obj/item/organ/I in H.internal_organs)
			if (I.damage > 0)
				I.damage = max(I.damage - removed, FALSE)

/datum/reagent/hyperzine
	name = "Hyperzine"
	id = "hyperzine"
	description = "Hyperzine is a highly effective, long lasting, muscle stimulant."
	taste_description = "acid"
	reagent_state = LIQUID
	color = "#FF3300"
	metabolism = REM * 0.15
	overdose = REAGENTS_OVERDOSE * 0.5

/datum/reagent/hyperzine/affect_blood(var/mob/living/carbon/M, var/alien, var/removed)
	if (prob(5))
		M.emote(pick("twitch", "blink_r", "shiver"))
	M.add_chemical_effect(CE_SPEEDBOOST, TRUE)
	M.add_chemical_effect(CE_PULSE, 2)


/datum/reagent/potassium_iodide
	name = "Potassium Iodide"
	id = "potassium_iodide"
	description = "A salt of stable iodine, used to prevent the thyroid from absorbing radioactive iodine, helping lessen the effects of radiation on the body."
	taste_description = "bitterness"
	reagent_state = LIQUID
	color = "#408000"
	metabolism = REM * 0.25
	overdose = REAGENTS_OVERDOSE
	scannable = TRUE

/datum/reagent/potassium_iodide/affect_blood(var/mob/living/carbon/M, var/alien, var/removed)
	M.radiation = max(M.radiation - 15 * removed, FALSE)

/datum/reagent/penicillin
	name = "penicillin"
	id = "penicillin"
	description = "An all-purpose antiviral agent."
	taste_description = "bitterness"
	reagent_state = LIQUID
	color = "#C1C1C1"
	metabolism = REM * 0.05
	overdose = REAGENTS_OVERDOSE
	scannable = TRUE

/datum/reagent/prontosil
	name = "Prontosil"
	id = "prontosil"
	description = "A sulfanomide used as an external antimicrobial."
	taste_description = "bitterness"
	reagent_state = LIQUID
	color = "#C8A5DC"
	overdose = REAGENTS_OVERDOSE
	touch_met = 5

/datum/reagent/prontosil/affect_touch(var/mob/living/carbon/M, var/alien, var/removed)
	M.germ_level -= min(removed*25, M.germ_level)

/datum/reagent/prontosil/touch_obj(var/obj/O)
	O.germ_level -= min(volume*20, O.germ_level)

/datum/reagent/prontosil/touch_turf(var/turf/T)
	T.germ_level -= min(volume*20, T.germ_level)

/datum/reagent/hydrogen_peroxide
	name = "Hidrogen Peroxide"
	id = "hydrogen_peroxide"
	description = "Sterilizes wounds in preparation for surgery and thoroughly removes blood."
	taste_description = "water"
	reagent_state = LIQUID
	color = "#ADD8E6"
	touch_met = 5

/datum/reagent/hydrogen_peroxide/affect_touch(var/mob/living/carbon/M, var/alien, var/removed)
	M.germ_level -= min(removed*10, M.germ_level)
	for (var/obj/item/I in M.contents)
		I.was_bloodied = null
	M.was_bloodied = null

/datum/reagent/hydrogen_peroxide/touch_obj(var/obj/O)
	O.germ_level -= min(volume*10, O.germ_level)
	O.was_bloodied = null

/datum/reagent/hydrogen_peroxide/touch_turf(var/turf/T)
	T.germ_level -= min(volume*10, T.germ_level)
	for (var/obj/item/I in T.contents)
		I.was_bloodied = null
	for (var/obj/effect/decal/cleanable/blood/B in T)
		qdel(B)

/* Antidepressants */

#define ANTIDEPRESSANT_MESSAGE_DELAY 5*60*10

/datum/reagent/methylphenidate
	name = "Methylphenidate"
	id = "methylphenidate"
	description = "Improves the ability to concentrate."
	taste_description = "sourness"
	reagent_state = LIQUID
	color = "#BF80BF"
	metabolism = 0.01
	data = FALSE

/datum/reagent/methylphenidate/affect_blood(var/mob/living/carbon/M, var/alien, var/removed)
	if (volume <= 0.1 && data != -1)
		data = -1
		M << "<span class='warning'>You lose focus...</span>"
	else
		if (world.time > data + ANTIDEPRESSANT_MESSAGE_DELAY)
			data = world.time
			M << "<span class='notice'>Your mind feels focused and undivided.</span>"

/datum/reagent/citalopram
	name = "Citalopram"
	id = "citalopram"
	description = "Stabilizes the mind a little."
	taste_description = "bitterness"
	reagent_state = LIQUID
	color = "#FF80FF"
	metabolism = 0.01
	data = FALSE

/datum/reagent/citalopram/affect_blood(var/mob/living/carbon/M, var/alien, var/removed)
	if (volume <= 0.1 && data != -1)
		data = -1
		M << "<span class='warning'>Your mind feels a little less stable...</span>"
	else
		if (world.time > data + ANTIDEPRESSANT_MESSAGE_DELAY)
			data = world.time
			M << "<span class='notice'>Your mind feels stable... a little stable.</span>"
	M.mood += removed*20

/datum/reagent/paroxetine
	name = "Paroxetine"
	id = "paroxetine"
	description = "Stabilizes the mind greatly, but has a chance of adverse effects."
	reagent_state = LIQUID
	color = "#FF80BF"
	metabolism = 0.01
	data = FALSE

/datum/reagent/paroxetine/affect_blood(var/mob/living/carbon/M, var/alien, var/removed)
	if (volume <= 0.1 && data != -1)
		data = -1
		M << "<span class='warning'>Your mind feels much less stable...</span>"
	else
		if (world.time > data + ANTIDEPRESSANT_MESSAGE_DELAY)
			data = world.time
			if (prob(90))
				M << "<span class='notice'>Your mind feels much more stable.</span>"
			else
				M << "<span class='warning'>Your mind breaks apart...</span>"
				M.hallucination += 200
	M.mood += removed*30

/datum/reagent/opium
	name = "Opium"
	id = "opium"
	description = "A powerful sedative and painkiller."
	taste_description = "bitterness"
	reagent_state = LIQUID
	color = "#000067"
	metabolism = REM * 0.10
	overdose = 14

/datum/reagent/opium/affect_blood(var/mob/living/carbon/M, var/alien, var/removed)
	M.add_chemical_effect(CE_PAINKILLER, 100)
	M.addictions["opium"] += 0.1
	M.mood += removed*20
/datum/reagent/opium/overdose(var/mob/living/carbon/M, var/alien)
	..()
	M.sleeping = max(M.sleeping, 100)
	M.druggy = max(M.druggy, 200)

/datum/reagent/cocaine
	name = "Cocaine"
	id = "cocaine"
	description = "A powerful stimulant. Very addictive."
	taste_description = "metallic bitterness"
	reagent_state = SOLID
	color = "#faeff1"
	metabolism = REM * 0.13
	overdose = 60

/datum/reagent/cocaine/affect_blood(var/mob/living/carbon/M, var/alien, var/removed)
	M.add_chemical_effect(CE_PAINKILLER, 40)
	M.addictions["cocaine"] += 0.12
	M.add_chemical_effect(CE_SPEEDBOOST, 2)
	M.add_chemical_effect(CE_PULSE, 4)
	M.mood += removed*10
/datum/reagent/opium/overdose(var/mob/living/carbon/M, var/alien)
	..()
	M.make_dizzy(6)

/datum/reagent/pervitin
	name = "Pervitin"
	id = "pervitin"
	description = "Pervitine is a highly effective stimulant. Addictive!"
	taste_description = "sweetness"
	reagent_state = LIQUID
	color = "#FF3300"
	metabolism = REM * 0.15
	overdose = REAGENTS_OVERDOSE * 0.5

/datum/reagent/pervitin/affect_blood(var/mob/living/carbon/M, var/alien, var/removed)
	if (prob(5))
		M.emote(pick("twitch", "blink_r", "shiver"))
	M.add_chemical_effect(CE_SPEEDBOOST, TRUE)
	M.add_chemical_effect(CE_PULSE, 2)
	M.mood += removed*10

/datum/reagent/morphine
	name = "Morphine"
	id = "morphine"
	description = "A powerful sedative and painkiller"
	taste_description = "bitterness"
	reagent_state = LIQUID
	color = "#000067"
	metabolism = REM * 0.10
	overdose = 9

/datum/reagent/morphine/affect_blood(var/mob/living/carbon/M, var/alien, var/removed)
	M.add_chemical_effect(CE_PAINKILLER, 200)
	M.mood += removed*16
/datum/reagent/morphine/overdose(var/mob/living/carbon/M, var/alien)
	..()
	M.sleeping = max(M.sleeping, 100)
	M.druggy = max(M.druggy, 250)


/datum/reagent/potass_iodide
	name = "Potassium Iodide"
	id = "potass_iodide"
	description = "Efficiently restores low radiation damage."
	reagent_state = LIQUID
	color = "#C8A5DC"
	metabolism = 0.2

/datum/reagent/potass_iodide/on_mob_life(mob/living/M)
	if(M.radiation > 0)
		M.radiation -= 6
	if(M.radiation < 0)
		M.radiation = 0
	..()
	return

/datum/reagent/pen_acid
	name = "Pentetic Acid"
	id = "pen_acid"
	description = "Reduces massive amounts of radiation and toxin damage while purging other chemicals from the body. Has a chance of dealing brute damage."
	reagent_state = LIQUID
	color = "#C8A5DC"
	metabolism = 0.4

/datum/reagent/pen_acid/on_mob_life(mob/living/M)
	if(M.radiation > 0)
		M.radiation -= 12
	M.adjustToxLoss(-2*REM)
	if(M.radiation < 0)
		M.radiation = 0
	for(var/datum/reagent/R in M.reagents.reagent_list)
		if(R != src)
			M.reagents.remove_reagent(R.id,2)
	..()
	return

/datum/reagent/sal_acid
	name = "Salicyclic Acid"
	id = "sal_acid"
	description = "Stimulates the healing of severe bruises. Extremely rapidly heals severe bruising and slowly heals minor ones. Overdose will worsen existing bruising."
	reagent_state = LIQUID
	color = "#C8A5DC"
	metabolism = 0.5
	overdose = 25

/datum/reagent/sal_acid/affect_blood(var/mob/living/carbon/M, var/alien, var/removed)
	if(M.getBruteLoss() > 50)
		M.adjustBruteLoss(-4*REM) //Twice as effective as styptic powder for severe bruising
	else
		M.adjustBruteLoss(-0.5*REM) //But only a quarter as effective for more minor ones
	..()
	return
/datum/reagent/sal_acid/overdose(mob/living/M)
	if(M.getBruteLoss()) //It only makes existing bruises worse
		M.adjustBruteLoss(4.5*REM) // it's going to be healing either 4 or 0.5
	..()
	return
