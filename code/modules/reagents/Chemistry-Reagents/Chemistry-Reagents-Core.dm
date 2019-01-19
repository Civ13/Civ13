/datum/reagent/blood
	data = new/list("donor" = null, "viruses" = null, "species" = "Human", "blood_DNA" = null, "blood_type" = null, "blood_colour" = "#A10808", "resistances" = null, "trace_chem" = null, "antibodies" = list())
	name = "Blood"
	id = "blood"
	reagent_state = LIQUID
	metabolism = REM * 5
	color = "#C80000"
	taste_description = "iron"
	taste_mult = 1.3

/datum/reagent/blood/initialize_data(var/newdata)
	..()
	if (data && data["blood_colour"])
		color = data["blood_colour"]
	return

/datum/reagent/blood/get_data() // Just in case you have a reagent that handles data differently.
	var/t = data.Copy()
	if (t["virus2"])
		var/list/v = t["virus2"]
		t["virus2"] = v.Copy()
	return t

/datum/reagent/blood/touch_turf(var/turf/T)
	if (!istype(T) || volume < 3)
		return
	if (!data["donor"] || istype(data["donor"], /mob/living/carbon/human))
		blood_splatter(T, src, TRUE)

/datum/reagent/blood/affect_ingest(var/mob/living/carbon/M, var/alien, var/removed)

	var/effective_dose = dose
	if (issmall(M)) effective_dose *= 2

	if (effective_dose > 5)
		M.adjustToxLoss(removed)
	if (effective_dose > 15)
		M.adjustToxLoss(removed)


/datum/reagent/blood/affect_touch(var/mob/living/carbon/M, var/alien, var/removed)
	return


/datum/reagent/blood/affect_blood(var/mob/living/carbon/M, var/alien, var/removed)
	M.inject_blood(src, volume)
	remove_self(volume)

// pure concentrated antibodies
/datum/reagent/antibodies
	data = list("antibodies"=list())
	name = "Antibodies"
	taste_description = "slime"
	id = "antibodies"
	reagent_state = LIQUID
	color = "#0050F0"

/datum/reagent/antibodies/affect_blood(var/mob/living/carbon/M, var/alien, var/removed)
	if (data)
		M.antibodies |= data["antibodies"]
	..()

#define WATER_LATENT_HEAT 19000 // How much heat is removed when applied to a hot turf, in J/unit (19000 makes 120 u of water roughly equivalent to 4L)
/datum/reagent/water
	name = "Water"
	id = "water"
	description = "A ubiquitous chemical substance that is composed of hydrogen and oxygen."
	reagent_state = LIQUID
	color = "#0064C877"
	metabolism = REM * 10
	taste_description = "water"

/datum/reagent/water/touch_turf(var/turf/T)
	if (!istype(T))
		return
	if (volume >= 10)
		T.wet_floor(1)

/datum/reagent/water/touch_obj(var/obj/O)


/datum/reagent/water/touch_mob(var/mob/living/L, var/amount)
	if (istype(L))
		var/needed = L.fire_stacks * 10
		if (amount > needed)
			L.fire_stacks = FALSE
			L.ExtinguishMob()
			remove_self(needed)
		else
			L.adjust_fire_stacks(-(amount / 10))
			remove_self(amount)

/datum/reagent/water/affect_blood(var/mob/living/carbon/M, var/alien, var/removed)
	if (M.water < 0)
		M.water += rand(40,50)
	M.water += removed * 15