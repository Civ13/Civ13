/* Toxins, poisons, venoms */

/datum/reagent/toxin
	name = "toxin"
	id = "toxin"
	description = "A toxic chemical."
	taste_description = "bitterness"
	taste_mult = 1.2
	reagent_state = LIQUID
	color = "#CF3600"
	metabolism = REM * 0.05 // 0.01 by default. They last a while and slowly kill you.
	strength = 4 // How much damage it deals per unit

/datum/reagent/toxin/affect_blood(var/mob/living/human/M, var/alien, var/removed)
	if (strength)
		if (issmall(M)) removed *= 2 // Small bodymass, more effect from lower volume.
		M.adjustToxLoss(strength * removed)

/datum/reagent/toxin/plasticide
	name = "Plasticide"
	id = "plasticide"
	description = "Liquid plastic, do not eat."
	taste_description = "plastic"
	reagent_state = LIQUID
	color = "#CF3600"
	strength = 8

/datum/reagent/toxin/amatoxin
	name = "Amatoxin"
	id = "amatoxin"
	description = "A powerful poison derived from certain species of mushroom."
	taste_description = "mushroom"
	reagent_state = LIQUID
	color = "#792300"
	strength = 12

/datum/reagent/toxin/carpotoxin
	name = "Carpotoxin"
	id = "carpotoxin"
	description = "A deadly neurotoxin produced by the dreaded space carp."
	taste_description = "fish"
	reagent_state = LIQUID
	color = "#003333"
	strength = 13

/datum/reagent/toxin/plasma
	name = "Plasma"
	id = "plasma"
	description = "Plasma in its liquid form."
	taste_mult = 1.5
	reagent_state = LIQUID
	color = "#9D14DB"
	strength = 30
	touch_met = 5

/datum/reagent/toxin/plasma/touch_mob(var/mob/living/L, var/amount)
	if (istype(L))
		L.adjust_fire_stacks(amount / 5)

/datum/reagent/toxin/plasma/affect_touch(var/mob/living/human/M, var/alien, var/removed)
	M.take_organ_damage(0, removed * 0.1) //being splashed directly with plasma causes minor chemical burns
/*	if (prob(50))
		M.pl_effects()*/

/datum/reagent/toxin/plasma/touch_turf(var/turf/T)
	if (!istype(T))
		return
//	T.assume_gas("plasma", volume, T20C)
	remove_self(volume)

/datum/reagent/toxin/cyanide //Fast and Lethal
	name = "Cyanide"
	id = "cyanide"
	description = "A highly toxic chemical."
	taste_mult = 0.6
	reagent_state = LIQUID
	color = "#CF3600"
	strength = 17
	metabolism = REM * 1

/datum/reagent/toxin/cyanide/affect_blood(var/mob/living/human/M, var/alien, var/removed)
	..()
	M.adjustOxyLoss(20 * removed)
	M.sleeping += 0

/datum/reagent/toxin/batrachotoxin
	name = "Batrachotoxin"
	id = "batrachotoxin"
	description = "A highly toxic chemical, extracted from poisonous frogs."
	taste_mult = 0.6
	reagent_state = LIQUID
	color = "#CF3600"
	strength = 25
	metabolism = REM * 1

/datum/reagent/toxin/batrachotoxin/affect_blood(var/mob/living/human/M, var/alien, var/removed)
	..()
	M.adjustBrainLoss(6.5 * removed)

/datum/reagent/toxin/food_poisoning
	name = "Food Poisoning"
	id = "food_poisoning"
	description = "A highly toxic chemical."
	taste_mult = 0.3
	reagent_state = LIQUID
	color = "#CF3600"
	strength = 10
	metabolism = REM

/datum/reagent/toxin/food_poisoning/affect_blood(var/mob/living/human/M, var/alien, var/removed)
	..()
	if (!M.crab)
		M.adjustToxLoss(5 * removed)
		if (prob(30))
			M << "<span class = 'warning'>You feel sick...</span>"

/datum/reagent/toxin/cholera
	name = "Cholera"
	id = "cholera"
	description = "A toxic bacteria."
	taste_mult = FALSE
	reagent_state = LIQUID
	color = "#CF3600"
	strength = 0
	taste_description = "mud"
	metabolism = REM

/datum/reagent/toxin/cholera/affect_blood(var/mob/living/human/M, var/alien, var/removed)
	if (ishuman(M))
		var/mob/living/human/H = M
		if(H.disease_type != "cholera") //force cholera.
			H.disease_type = "cholera"
			H.disease = 1
	return

/datum/reagent/toxin/typhus
	name = "Typhus"
	id = "typhus"
	description = "A transmissable bacteria."
	taste_mult = FALSE
	reagent_state = LIQUID
	color = "#CF3600"
	strength = 0
	taste_description = "body odour"
	metabolism = REM

/datum/reagent/toxin/typhus/affect_blood(var/mob/living/human/M, var/alien, var/removed)
	if (ishuman(M))
		var/mob/living/human/H = M
		if(H.disease_type != "typhus") //force typhus.
			H.disease_type = "typhus"
			H.disease = 1
	return

/datum/reagent/toxin/plague
	name = "Plague"
	id = "plague"
	description = "Deadly virus."
	taste_mult = FALSE
	reagent_state = LIQUID
	color = "#202020"
	strength = 100
	taste_description = "death"
	metabolism = REM

/datum/reagent/toxin/plague/affect_blood(var/mob/living/human/M, var/alien, var/removed)
	if (ishuman(M))
		var/mob/living/human/H = M
		if(H.disease_type != "plague") //force plague.
			H.disease_type = "plague"
			H.disease = 1
	return

/datum/reagent/toxin/potassium_chloride
	name = "Potassium Chloride"
	id = "potassium_chloride"
	description = "A delicious salt that stops the heart when injected into cardiac muscle."
	taste_description = "salt"
	reagent_state = SOLID
	color = "#FFFFFF"
	strength = FALSE
	overdose = REAGENTS_OVERDOSE

/datum/reagent/toxin/potassium_chloride/overdose(var/mob/living/human/M, var/alien)
	..()
	if (ishuman(M))
		var/mob/living/human/H = M
		if (H.stat != TRUE)
			if (H.losebreath >= 10)
				H.losebreath = max(10, H.losebreath - 10)
			H.adjustOxyLoss(2)
			H.Weaken(10)
		M.add_chemical_effect(CE_NOPULSE, TRUE)


/datum/reagent/toxin/potassium_chlorophoride
	name = "Potassium Chlorophoride"
	id = "potassium_chlorophoride"
	description = "A specific chemical based on Potassium Chloride to stop the heart for surgery. Not safe to eat!"
	taste_description = "salt"
	reagent_state = SOLID
	color = "#FFFFFF"
	strength = 10
	overdose = 20

/datum/reagent/toxin/potassium_chlorophoride/affect_blood(var/mob/living/human/M, var/alien, var/removed)
	..()
	if (ishuman(M))
		var/mob/living/human/H = M
		if (H.stat != TRUE)
			if (H.losebreath >= 10)
				H.losebreath = max(10, M.losebreath-10)
			H.adjustOxyLoss(2)
			H.Weaken(10)
		M.add_chemical_effect(CE_NOPULSE, TRUE)

/datum/reagent/toxin/zombiepowder
	name = "Zombie Powder"
	id = "zombiepowder"
	description = "A strong neurotoxin that puts the subject into a death-like state."
	taste_description = "death"
	reagent_state = SOLID
	color = "#669900"
	metabolism = REM
	strength = 3

/datum/reagent/toxin/zombiepowder/affect_blood(var/mob/living/human/M, var/alien, var/removed)
	..()
	M.status_flags |= FAKEDEATH
	M.adjustOxyLoss(3 * removed)
	M.Weaken(10)
	M.silent = max(M.silent, 10)
	M.tod = stationtime2text()
	M.add_chemical_effect(CE_NOPULSE, TRUE)

/datum/reagent/toxin/zombiepowder/Destroy()
	if (holder && holder.my_atom && ismob(holder.my_atom))
		var/mob/M = holder.my_atom
		M.status_flags &= ~FAKEDEATH
	..()

/datum/reagent/toxin/fertilizer //Reagents used for plant fertilizers.
	name = "fertilizer"
	id = "fertilizer"
	description = "A chemical mix good for growing plants with."
	taste_description = "plant food"
	taste_mult = 0.5
	reagent_state = LIQUID
	strength = 0.5 // It's not THAT poisonous.
	color = "#664330"

/datum/reagent/toxin/fertilizer/eznutrient
	name = "EZ Nutrient"
	id = "eznutrient"

/datum/reagent/toxin/fertilizer/left4zed
	name = "Left-4-Zed"
	id = "left4zed"

/datum/reagent/toxin/fertilizer/robustharvest
	name = "Robust Harvest"
	id = "robustharvest"
/*
/datum/reagent/toxin/plantbgone
	name = "Plant-B-Gone"
	id = "plantbgone"
	description = "A harmful toxic mixture to kill plantlife. Do not ingest!"
	taste_mult = TRUE
	reagent_state = LIQUID
	color = "#49002E"
	strength = 4

/datum/reagent/toxin/plantbgone/touch_turf(var/turf/T)
	if (istype(T, /turf/wall))
		var/turf/wall/W = T
		if (locate(/obj/effect/overlay/wallrot) in W)
			for (var/obj/effect/overlay/wallrot/E in W)
				qdel(E)
			W.visible_message("<span class='notice'>The fungi are completely dissolved by the solution!</span>")

/datum/reagent/toxin/plantbgone/touch_obj(var/obj/O, var/volume)
	if (istype(O, /obj/effect/plant))
		qdel(O)
*/
/datum/reagent/acid/polyacid
	name = "Polytrinic acid"
	id = "pacid"
	description = "Polytrinic acid is a an extremely corrosive chemical substance."
	taste_description = "acid"
	reagent_state = LIQUID
	color = "#8E18A9"
	power = 10
	meltdose = 4

/datum/reagent/lexorin
	name = "Lexorin"
	id = "lexorin"
	description = "Lexorin temporarily stops respiration. Causes tissue damage."
	taste_description = "acid"
	reagent_state = LIQUID
	color = "#C8A5DC"
	overdose = REAGENTS_OVERDOSE

/datum/reagent/lexorin/affect_blood(var/mob/living/human/M, var/alien, var/removed)
	M.take_organ_damage(3 * removed, FALSE)
	if (M.losebreath < 15)
		M.losebreath++

/datum/reagent/slimejelly
	name = "Slime Jelly"
	id = "slimejelly"
	description = "A gooey semi-liquid produced from one of the deadliest lifeforms in existence. SO REAL."
	taste_description = "slime"
	taste_mult = 1.3
	reagent_state = LIQUID
	color = "#801E28"

/datum/reagent/slimejelly/affect_blood(var/mob/living/human/M, var/alien, var/removed)
	if (prob(10))
		M << "<span class='danger'>Your insides are burning!</span>"
		M.adjustToxLoss(rand(100, 300) * removed)
	else if (prob(40))
		M.heal_organ_damage(25 * removed, FALSE)

/datum/reagent/soporific
	name = "Soporific"
	id = "stoxin"
	description = "An effective hypnotic used to treat insomnia."
	taste_description = "bitterness"
	reagent_state = LIQUID
	color = "#009CA8"
	metabolism = REM * 0.5
	overdose = REAGENTS_OVERDOSE

/datum/reagent/soporific/affect_blood(var/mob/living/human/M, var/alien, var/removed)
	var/effective_dose = dose
	if (issmall(M))
		effective_dose *= 2

	if (effective_dose < 1)
		if (effective_dose == metabolism * 2 || prob(5))
			M.emote("yawn")
	else if (effective_dose < 1.5)
		M.eye_blurry = max(M.eye_blurry, 10)
	else if (effective_dose < 5)
		if (prob(50))
			M.Weaken(2)
		M.drowsyness = max(M.drowsyness, 20)
	else
		M.sleeping = max(M.sleeping, 20)
		M.drowsyness = max(M.drowsyness, 60)
	M.add_chemical_effect(CE_PULSE, -1)

/datum/reagent/chloralhydrate
	name = "Chloral Hydrate"
	id = "chloralhydrate"
	description = "A powerful sedative."
	taste_description = "bitterness"
	reagent_state = SOLID
	color = "#000067"
	metabolism = REM * 0.5
	overdose = REAGENTS_OVERDOSE * 0.5

/datum/reagent/chloralhydrate/affect_blood(var/mob/living/human/M, var/alien, var/removed)
	var/effective_dose = dose
	if (issmall(M))
		effective_dose *= 2

	if (effective_dose == metabolism)
		M.confused += 2
		M.drowsyness += 2
	else if (effective_dose < 2)
		M.Weaken(30)
		M.eye_blurry = max(M.eye_blurry, 10)
	else
		M.sleeping = max(M.sleeping, 30)

	if (effective_dose > 1)
		M.adjustToxLoss(removed)

/* Drugs */

/datum/reagent/peyote
	name = "Peyote"
	id = "peyote"
	description = "A hallucinogen extracted from the Peyote cactus."
	taste_description = "bitterness"
	taste_mult = 0.4
	reagent_state = LIQUID
	color = "#6AAF6A"
	metabolism = REM * 0.5
	overdose = REAGENTS_OVERDOSE

/datum/reagent/peyote/affect_blood(var/mob/living/human/M, var/alien, var/removed)
	M.druggy = max(M.druggy, 15)
	if (prob(25) && isturf(M.loc) && M.canmove && !M.restrained())
		step(M, pick(cardinal))
	if (prob(7))
		M.emote(pick("twitch", "drool", "moan", "giggle"))
	M.add_chemical_effect(CE_PULSE, -1)
	M.add_chemical_effect(CE_STABLE)
	M.add_chemical_effect(CE_PAINKILLER, 15)
	M.adjustBrainLoss(-0.5 * removed)
	M.mood += removed*10

/datum/reagent/thc
	name = "THC"
	id = "thc"
	description = "THC is the principal psychoactive constituent of cannabis."
	taste_description = "nothing"
	taste_mult = 0.4
	reagent_state = LIQUID
	color = "#6AAF6A"
	metabolism = REM * 0.5
	overdose = REAGENTS_OVERDOSE

/datum/reagent/thc/affect_blood(var/mob/living/human/M, var/alien, var/removed)
	M.druggy = max(M.druggy, 30)
	if (prob(25) && isturf(M.loc) && M.canmove && !M.restrained())
		step(M, pick(cardinal))
	if (prob(7))
		M.emote(pick("twitch", "drool", "moan", "giggle"))
	M.add_chemical_effect(CE_PULSE, -2)
	M.add_chemical_effect(CE_STABLE)
	M.add_chemical_effect(CE_PAINKILLER, 25)
	M.adjustBrainLoss(-0.1 * removed)
	M.mood += removed*20

/datum/reagent/serotrotium
	name = "Serotrotium"
	id = "serotrotium"
	description = "A chemical compound that promotes concentrated production of the serotonin neurotransmitter in humans."
	taste_description = "bitterness"
	reagent_state = LIQUID
	color = "#202040"
	metabolism = REM * 0.25
	overdose = REAGENTS_OVERDOSE

/datum/reagent/serotrotium/affect_blood(var/mob/living/human/M, var/alien, var/removed)
	if (prob(7))
		M.emote(pick("twitch", "drool", "moan", "gasp"))
	return

/datum/reagent/cryptobiolin
	name = "Cryptobiolin"
	id = "cryptobiolin"
	description = "Cryptobiolin causes confusion and dizzyness."
	taste_description = "sourness"
	reagent_state = LIQUID
	color = "#000055"
	metabolism = REM * 0.5
	overdose = REAGENTS_OVERDOSE

/datum/reagent/cryptobiolin/affect_blood(var/mob/living/human/M, var/alien, var/removed)
	M.make_dizzy(4)
	M.confused = max(M.confused, 20)

/datum/reagent/impedrezene
	name = "Impedrezene"
	id = "impedrezene"
	description = "Impedrezene is a narcotic that impedes one's ability by slowing down the higher brain cell functions."
	taste_description = "numbness"
	reagent_state = LIQUID
	color = "#C8A5DC"
	overdose = REAGENTS_OVERDOSE

/datum/reagent/impedrezene/affect_blood(var/mob/living/human/M, var/alien, var/removed)
	M.jitteriness = max(M.jitteriness - 5, FALSE)
	if (prob(80))
		M.adjustBrainLoss(0.1 * removed)
	if (prob(50))
		M.drowsyness = max(M.drowsyness, 3)
	if (prob(10))
		M.emote("drool")

/datum/reagent/mindbreaker
	name = "Lysergic acid diethylamide"
	id = "mindbreaker"
	description = "A powerful hallucinogen, it can cause fatal effects in users."
	taste_description = "sourness"
	reagent_state = LIQUID
	color = "#B31008"
	metabolism = REM * 0.25
	overdose = REAGENTS_OVERDOSE

/datum/reagent/mindbreaker/affect_blood(var/mob/living/human/M, var/alien, var/removed)
	M.hallucination = max(M.hallucination, 100)

/datum/reagent/psilocybin
	name = "Psilocybin"
	id = "psilocybin"
	description = "A strong psycotropic derived from certain species of mushroom."
	taste_description = "mushroom"
	color = "#E700E7"
	overdose = REAGENTS_OVERDOSE
	metabolism = REM * 0.5

/datum/reagent/psilocybin/affect_blood(var/mob/living/human/M, var/alien, var/removed)
	M.druggy = max(M.druggy, 30)

	var/effective_dose = dose
	if (issmall(M)) effective_dose *= 2
	if (effective_dose < 1)
		M.apply_effect(3, STUTTER)
		M.make_dizzy(5)
		if (prob(5))
			M.emote(pick("twitch", "giggle"))
	else if (effective_dose < 2)
		M.apply_effect(3, STUTTER)
		M.make_jittery(5)
		M.make_dizzy(5)
		M.druggy = max(M.druggy, 35)
		if (prob(10))
			M.emote(pick("twitch", "giggle"))
	else
		M.apply_effect(3, STUTTER)
		M.make_jittery(10)
		M.make_dizzy(10)
		M.druggy = max(M.druggy, 40)
		if (prob(15))
			M.emote(pick("twitch", "giggle"))

/datum/reagent/nicotine
	name = "Nicotine"
	id = "nicotine"
	description = "A highly addictive stimulant extracted from the tobacco plant."
	taste_description = "bitterness"
	reagent_state = LIQUID
	color = "#181818"

/datum/reagent/nicotine/affect_blood(var/mob/living/human/M, var/alien, var/removed)
	..()
	M.add_chemical_effect(CE_PULSE, TRUE)
	M.add_chemical_effect(CE_SPEEDBOOST, TRUE)
	M.mood += removed*16


/datum/reagent/toxin/bleach
	name = "Bleach"
	id = "bleach"
	description = "A highly poisonous liquid. Smells strongly of bleach."
	reagent_state = LIQUID
	taste_description = "bleach"
	color = "#707c13"
	strength = 15
	metabolism = REM

/datum/reagent/toxin/solanine
	name = "Solanine"
	id = "solanine"
	description = "Potatoes natural defense."
	taste_description = "starch"
	reagent_state = LIQUID
	color = "#D3D3D3"
	strength = 5

/datum/reagent/toxin/chlorobenzalmalononitrile
    name = "CS powder"
    id = "chlorobenzalmalononitrile"
    description = "A Nerve-Agent that works similar to Pepper Spray but higher in potency."
    taste_description = "the Sun's piss"
    taste_mult = 10
    reagent_state = GAS
    touch_met = 30
    overdose = REAGENTS_OVERDOSE
    color = "#545454"
    var/agony_dose = 0.5
    var/agony_amount = 4
    var/discomfort_message = "<span class='danger'>You feel like the world is turning fuzzy</span>"
/datum/reagent/toxin/chlorobenzalmalononitrile/affect_touch(var/mob/living/human/M, var/alien, var/removed)
    var/eyes_covered = 0
    var/mouth_covered = 0
    var/no_pain = 0
    var/obj/item/eye_protection
    var/obj/item/face_protection
    var/list/protection
    if(ishuman(M))
        var/mob/living/human/H = M
        protection = list(H.head, H.wear_mask)
        if(H.species && (H.species.flags & NO_PAIN))
            no_pain = 1 //TODO: living-level can_feel_pain() proc
    else
        protection = list(M.wear_mask)

    for(var/obj/item/I in protection)
        if(I)
            if(I.body_parts_covered & EYES)
                eyes_covered = 1
                eye_protection = I.name
            if((I.body_parts_covered & FACE) && !(I.item_flags & FLEXIBLEMATERIAL))
                mouth_covered = 1
                face_protection = I.name

    var/message
    if(eyes_covered)
        if(!mouth_covered)
            message = SPAN_WARNING("Your [eye_protection] protects your eyes from the nerve gas agent!")
    else
        message = SPAN_WARNING("YOUR EYES ARE BURNING!!")
        if(mouth_covered)
            M.eye_blurry = max(M.eye_blurry, 15)
            M.make_dizzy(500)
        else
            M.eye_blurry = max(M.eye_blurry, 25)
            M.make_dizzy(1000)

    if(mouth_covered)
        if(!message)
            message = SPAN_WARNING("Your [face_protection] protects you from the nerve gas agent!")
    else if(!no_pain)
        message = SPAN_DANGER("Your face and throat feel like it's being roasted to death!")
        if(prob(30))
            M.emote("cough")
        M.apply_effect(30, AGONY, 0)
/datum/reagent/toxin/chlorobenzalmalononitrile/affect_ingest(var/mob/living/human/M, var/alien, var/removed)
    if(ishuman(M))
        var/mob/living/human/H = M
        if(H.species && (H.species.flags & NO_PAIN))
            return
    if(dose < agony_dose)
        if(prob(5) || dose == metabolism) //dose == metabolism is a very hacky way of forcing the message the first time this procs
            to_chat(M, discomfort_message)
    if(dose == metabolism)
        to_chat(M, SPAN_DANGER("You feel the blood rushing through your veins like lava!"))
    else
        M.apply_effect(agony_amount, AGONY, 0)
        if(prob(5))
            M.visible_message("<span class='warning'>[M] [pick("dry heaves!","coughs!","splutters!")]</span>", SPAN_DANGER("You feel like your insides are melting!"))
    affect_touch(M, alien, removed)
/datum/reagent/toxin/chlorobenzalmalononitrile/overdose(var/mob/living/human/M, var/alien, var/removed)
	M.adjustOxyLoss(5)
	M.take_organ_damage(5)
	if(M.losebreath < 15)
		M.losebreath++

