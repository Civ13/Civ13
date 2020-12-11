/datum/reagent/acetone
	name = "Acetone"
	id = "acetone"
	description = "A colorless liquid solvent used in chemical synthesis."
	taste_description = "acid"
	reagent_state = LIQUID
	color = "#808080"
	metabolism = REM * 0.2

/datum/reagent/acetone/affect_blood(var/mob/living/human/M, var/alien, var/removed)
	M.adjustToxLoss(removed * 3)

/datum/reagent/acetone/touch_obj(var/obj/O)	//I copied this wholesale from ethanol and could likely be converted into a shared proc. ~Techhead
	if (istype(O, /obj/item/weapon/paper))
		var/obj/item/weapon/paper/paperaffected = O
		paperaffected.clearpaper()
		usr << "The solution dissolves the ink on the paper."
		return
	if (istype(O, /obj/item/weapon/book))
		if (volume < 5)
			return
		var/obj/item/weapon/book/affectedbook = O
		affectedbook.dat = null
		usr << "<span class='notice'>The solution dissolves the ink on the book.</span>"
	return

/datum/reagent/hexachloroetane
	name = "Hexachloroetane"
	id = "hexachloroetane"
	taste_description = "camphor"
	taste_mult = 2
	description = "A crystalline substance used in the production of smoke bombs."
	reagent_state = SOLID
	color = "#ffffff"
	metabolism = REM * 0.5

/datum/reagent/napalm
	name = "Napalm"
	id = "napalm"
	taste_description = "gasoline"
	taste_mult = 4
	description = "A compound of gasoline and a gelling agent."
	reagent_state = LIQUID
	color = "#ffffe0"

/datum/reagent/napalm/affect_blood(var/mob/living/human/M, var/alien, var/removed)
	..()
	M.adjustToxLoss(10)

/datum/reagent/gasoline/touch_mob(var/mob/living/L, var/amount)
	if (istype(L))
		L.adjust_fire_stacks(amount / 2)
/datum/reagent/ammonia
	name = "Ammonia"
	id = "ammonia"
	taste_description = "mordant"
	taste_mult = 2
	description = "A caustic substance commonly used in fertilizer or household cleaners."
	reagent_state = LIQUID
	color = "#404030"
	metabolism = REM * 0.5

/datum/reagent/ammonia/affect_blood(var/mob/living/human/M, var/alien, var/removed)
	M.adjustToxLoss(removed * 1.5)

/datum/reagent/ethanol
	name = "Ethanol" //Parent class for all alcoholic reagents.
	id = "ethanol"
	description = "A well-known alcohol with a variety of applications."
	taste_description = "alcohol"
	reagent_state = LIQUID
	color = "#404030"
	touch_met = 5
	var/nutriment_factor = FALSE
	var/toxicity = TRUE

	var/druggy = FALSE
	var/adj_temp = FALSE
	var/targ_temp = 310
	var/halluci = FALSE
	metabolism = REM*3
//purified ethanol (for engines)
/datum/reagent/ethanol/pethanol
	name = "Purified Ethanol"
	id = "pethanol"
	taste_description = "pure alcohol"
	strength = 10

/datum/reagent/ethanol/touch_mob(var/mob/living/L, var/amount)
	if (istype(L))
		L.adjust_fire_stacks(amount / 15)

/datum/reagent/ethanol/affect_blood(var/mob/living/human/M, var/alien, var/removed)
	if (issmall(M)) removed *= 2
	M.adjustToxLoss(removed * 2 * toxicity)
	// apparently this doesn't get called, so moving thirstcode to affect_ingest()
	return

/datum/reagent/ethanol/affect_ingest(var/mob/living/human/M, var/alien, var/removed)
	if (issmall(M)) removed *= 2
	M.bladder += removed
	var/strength_mod = 2
	M.add_chemical_effect(CE_PAINKILLER, 20)
	if (M.water < 0)
		M.water += rand(40,50)
	M.water += removed * 40
	M.addictions["alcohol"] += 0.02

	M.radiation -= 1 * removed

	M.add_chemical_effect(CE_ALCOHOL, TRUE)

	if (dose * strength_mod >= strength) // Early warning
		M.make_dizzy(6) // It is decreased at the speed of 3 per tick
	if (dose * strength_mod >= strength * 2) // Slurring
		M.slurring = max(M.slurring, 30)
	if (dose * strength_mod >= strength * 3) // Confusion - walking in random directions
		M.confused = max(M.confused, 20)
	if (dose * strength_mod >= strength * 4) // Blurry vision
		M.eye_blurry = max(M.eye_blurry, 10)
	if (dose * strength_mod >= strength * 5) // Drowsyness - periodically falling asleep
		M.drowsyness = max(M.drowsyness, 20)
	if (dose * strength_mod >= strength * 6) // Toxic dose
		M.add_chemical_effect(CE_ALCOHOL_TOXIC, toxicity)
	if (dose * strength_mod >= strength * 7) // Pass out
		M.paralysis = max(M.paralysis, 20)
		M.sleeping  = max(M.sleeping, 30)
/*
	if (druggy != 0)
		M.druggy = max(M.druggy, druggy)*/

	if (adj_temp > 0 && M.bodytemperature < targ_temp) // 310 is the normal bodytemp. 310.055
		M.bodytemperature = min(targ_temp, M.bodytemperature + (adj_temp * TEMPERATURE_DAMAGE_COEFFICIENT))
	if (adj_temp < 0 && M.bodytemperature > targ_temp)
		M.bodytemperature = min(targ_temp, M.bodytemperature - (adj_temp * TEMPERATURE_DAMAGE_COEFFICIENT))

	if (halluci)
		M.hallucination = max(M.hallucination, halluci)

/datum/reagent/ethanol/touch_obj(var/obj/O)
	if (istype(O, /obj/item/weapon/paper))
		var/obj/item/weapon/paper/paperaffected = O
		paperaffected.clearpaper()
		usr << "The solution dissolves the ink on the paper."
		return
	if (istype(O, /obj/item/weapon/book))
		if (volume < 5)
			return
		var/obj/item/weapon/book/affectedbook = O
		affectedbook.dat = null
		usr << "<span class='notice'>The solution dissolves the ink on the book.</span>"
	return

/datum/reagent/hydrazine
	name = "Hydrazine"
	id = "hydrazine"
	description = "A toxic, colorless, flammable liquid with a strong ammonia-like odor, in hydrate form."
	taste_description = "sweet tasting metal"
	reagent_state = LIQUID
	color = "#808080"
	metabolism = REM * 0.2
	touch_met = 5

/datum/reagent/hydrazine/affect_blood(var/mob/living/human/M, var/alien, var/removed)
	M.adjustToxLoss(4 * removed)

/datum/reagent/hydrazine/affect_touch(var/mob/living/human/M, var/alien, var/removed) // Hydrazine is both toxic and flammable.
	M.adjust_fire_stacks(removed / 12)
	M.adjustToxLoss(0.2 * removed)

/datum/reagent/acid
	name = "Sulphuric acid"
	id = "sacid"
	description = "A very corrosive mineral acid with the molecular formula H2SO4."
	taste_description = "acid"
	reagent_state = LIQUID
	color = "#DB5008"
	metabolism = REM * 2
	touch_met = 50 // It's acid!
	var/power = 5
	var/meltdose = 10 // How much is needed to melt

/datum/reagent/acid/affect_blood(var/mob/living/human/M, var/alien, var/removed)
	if (issmall(M)) removed *= 2
	M.take_organ_damage(0, removed * power * 2)

/datum/reagent/acid/affect_touch(var/mob/living/human/M, var/alien, var/removed) // This is the most interesting
	if (ishuman(M))
		var/mob/living/human/H = M
		if (H.head)
		/*	if (H.head.unacidable)
				H << "<span class='danger'>Your [H.head] protects you from the acid.</span>"
				remove_self(volume)
				return*/
			if (removed > meltdose)
				H << "<span class='danger'>Your [H.head] melts away!</span>"
				qdel(H.head)
				H.update_inv_head(1)
				H.update_hair(1)
				removed -= meltdose
		if (removed <= 0)
			return

		if (H.wear_mask)
		/*	if (H.wear_mask.unacidable)
				H << "<span class='danger'>Your [H.wear_mask] protects you from the acid.</span>"
				remove_self(volume)
				return*/
			if (removed > meltdose)
				H << "<span class='danger'>Your [H.wear_mask] melts away!</span>"
				qdel(H.wear_mask)
				H.update_inv_wear_mask(1)
				H.update_hair(1)
				removed -= meltdose
		if (removed <= 0)
			return


		if (removed <= 0)
			return

	if (volume < meltdose) // Not enough to melt anything
		M.take_organ_damage(0, removed * power * 0.2) //burn damage, since it causes chemical burns. Acid doesn't make bones shatter, like brute trauma would.
		return

/datum/reagent/acid/touch_obj(var/obj/O)
	if (O.unacidable)
		return
	if (istype(O, /obj/item))
		var/obj/effect/decal/cleanable/molten_item/I = new/obj/effect/decal/cleanable/molten_item(O.loc)
		I.desc = "Looks like this was \an [O] some time ago."
		for (var/mob/M in viewers(5, O))
			M << "<span class='warning'>\The [O] melts.</span>"
		qdel(O)
		remove_self(meltdose) // 10 units of acid will not melt EVERYTHING on the tile

/datum/reagent/acid/hydrochloric //Like sulfuric, but less toxic and more acidic.
	name = "Hydrochloric Acid"
	id = "hclacid"
	description = "A very corrosive mineral acid with the molecular formula HCl."
	taste_description = "stomach acid"
	reagent_state = LIQUID
	color = "#808080"
	power = 3
	meltdose = 8
/datum/reagent/acid/hydrogen_chloride
	name = "Hydrogen Chloride"
	id = "hydrogen_chloride"
	description = "A somewhat corrosive mineral acid."
	taste_description = "stomach acid"
	reagent_state = LIQUID
	color = "#808080"
	power = 1
	meltdose = 30
/datum/reagent/sodium
	name = "Sodium"
	id = "sodium"
	description = "A chemical element, readily reacts with water."
	taste_description = "salty metal"
	reagent_state = SOLID
	color = "#808080"

/datum/reagent/sugar
	name = "Sugar"
	id = "sugar"
	description = "The organic compound commonly known as table sugar and sometimes called saccharose. This white, odorless, crystalline powder has a pleasing, sweet taste."
	taste_description = "sugar"
	taste_mult = 1.8
	reagent_state = SOLID
	color = "#FFFFFF"

/datum/reagent/cocaine
	name = "Cocaine"
	id = "cocaine"
	description = "A recreational drug made from coca leaves,tastes great ."
	taste_description = "very powdery and sweet"
	reagent_state = SOLID
	color = "#FFFFFF"


/datum/reagent/sugar/affect_blood(var/mob/living/human/M, var/alien, var/removed)
	M.nutrition += removed * 2
	M.bowels += removed/12