#define CHEMNERF 2 // divide the power of all chems by this for BALANCE - Kachnov

var/mob/living/human/next_gas_eye_message = -1
var/mob/living/human/next_gas_skin_message = -1
var/mob/living/human/next_gas_lung_message = -1
var/mob/living/human/next_gas_flesh_message = -1

/datum/reagent/proc/mask_check(var/mob/living/human/m)
	if (m && istype(m))
		if (m.wear_mask && istype(m.wear_mask, /obj/item/clothing/mask/gas))
			return TRUE
	return FALSE

/datum/reagent/proc/eye_damage(var/mob/living/human/m, var/severity = TRUE) // damage eyes
	if (mask_check(m)) return
	for (var/obj/item/clothing/C in m.get_equipped_items())
		if (C.body_parts_covered & EYES)
			return
	if (m && istype(m) && severity)
		var/base = ((rand(2,3)) * severity)/CHEMNERF
		if (base >= 2)
			if (world.time >= next_gas_eye_message)
				m << "<span class = 'danger'>The gas burns your eyes!</span>"
			next_gas_eye_message = world.time + 10
			if (m.stat != DEAD)
				m.emote("scream")
			m.adjustFireLossByPart(base, "eyes")
			m.Weaken(rand(2,3))
			m.eye_blurry = max(m.eye_blurry+2, FALSE)

/datum/reagent/proc/external_damage(var/mob/living/human/m, var/severity = TRUE) // damage skin
	if (m && istype(m) && severity)
		var/base = ((rand(2,3)) * severity)/CHEMNERF
		if (base >= 2)
			if (world.time >= next_gas_skin_message)
				m << "<span class = 'danger'>The gas burns your skin!</span>"
			next_gas_skin_message = world.time + 10
			if (prob(50))
				if (m.stat != DEAD)
					m.emote("scream")
		var/burnlist = "l_arm,r_arm,l_leg,r_leg,l_hand,r_hand,feet,chest,groin,head,"
		for (var/obj/item/clothing/C in m.get_equipped_items())
			if (C.permeability_coefficient == TRUE || !C.body_parts_covered)
				continue
			if (C.body_parts_covered & HEAD)
				burnlist = replacetext(burnlist,"head,","")
			if (C.body_parts_covered & UPPER_TORSO)
				burnlist = replacetext(burnlist,"chest,","")
			if (C.body_parts_covered & LOWER_TORSO)
				burnlist = replacetext(burnlist,"groin,","")
			if (C.body_parts_covered & LEGS)
				burnlist = replacetext(burnlist,"legs,","")
			if (C.body_parts_covered & FEET)
				burnlist = replacetext(burnlist,"feet,","")
			if (C.body_parts_covered & ARMS)
				burnlist = replacetext(burnlist,"arms,","")
			if (C.body_parts_covered & HANDS)
				burnlist = replacetext(burnlist,"hands,","")
		var/list/burnparts = splittext(burnlist, ",")
//		world.log << "[burnparts]"
		for (var/pts in burnparts)
			if (pts == "head")
				m.adjustFireLossByPart(base, "eyes")
			else if (pts == "chest")
				m.adjustFireLossByPart(base, "chest")
			else if (pts == "groin")
				m.adjustFireLossByPart(base, "groin")
			else if (pts == "legs")
				m.adjustFireLossByPart(base, "l_leg")
				m.adjustFireLossByPart(base, "r_leg")
			else if (pts == "arms")
				m.adjustFireLossByPart(base, "l_arm")
				m.adjustFireLossByPart(base, "r_arm")
			else if (pts == "hands")
				m.adjustFireLossByPart(base, "l_hand")
				m.adjustFireLossByPart(base, "r_hand")
			else if (pts == "feet")
				m.adjustFireLossByPart(base, "l_foot")
				m.adjustFireLossByPart(base, "r_foot")
/datum/reagent/proc/internal_damage(var/mob/living/human/m, var/severity = TRUE) // damage things like lungs
	if (mask_check(m)) return
	if (m && istype(m) && severity)
		var/base = ((rand(2,3)) * severity)/CHEMNERF
		if (base >= 2)
			if (world.time >= next_gas_lung_message)
				m << "<span class = 'danger'>The gas burns your lungs!</span>"
			next_gas_lung_message = world.time + 10
			if (m.stat != DEAD)
				m.emote("scream")
			m.adjustFireLossByPart(base, "chest")
			if (prob(70))
				m.Weaken(rand(3,4))

/datum/reagent/proc/suffocation(var/mob/living/human/m, var/severity = TRUE)
	if (mask_check(m)) return
	if (m && istype(m) && severity)
		var/base = ((rand(2,3)) * severity)/CHEMNERF
		if (base >= 2)
			if (world.time >= next_gas_lung_message)
				m << "<span class = 'danger'>You can't breathe!</span>"
			next_gas_lung_message = world.time + 10
			if (m.stat != DEAD)
				m.emote("gasp")
			m.adjustOxyLoss(base)


/datum/reagent/proc/open_wound_damage(var/mob/living/human/m, var/severity = TRUE) // damage wounded skin
	if (m && istype(m) && severity)
		var/base = ((m.getBruteLoss() + m.getFireLoss())/10) * severity
		base += rand(1,2)
		base /= CHEMNERF
		if (base >= 1)
			if (world.time >= next_gas_flesh_message)
				m << "<span class = 'danger'>The gas burns the flesh on your open wounds!</span>"
			next_gas_flesh_message = world.time + 10
			if (prob(50))
				if (m.stat != DEAD)
					m.emote("scream")
			m.adjustFireLoss(base)

/proc/get_severity(var/amount)
	switch (amount)
		if (0)
			return FALSE
		if (1 to 5)
			return TRUE
		if (6 to 10)
			return 2
		if (11 to INFINITY)
			return 3
//blue cross
/datum/reagent/toxin/xylyl_bromide
	name = "Xylyl Bromide"
	id = "xylyl_bromide"
	description = "A lacrimant. Won't kill you but will make you cry a lot."
	taste_mult = 1.5
	reagent_state = GAS
	color = "#ffd700"
	strength = 30
	touch_met = 5
	alpha = 51
//	meltdose = 4

/datum/reagent/toxin/xylyl_bromide/touch_mob(var/mob/living/L, var/amount)
	if (istype(L))
		if (mask_check(L)) return
		L.eye_blurry += (amount/10)
		L.Weaken(10)
		if (prob(10))
			L.emote("cough")


/datum/reagent/toxin/mustard_gas
	name = "Mustard Gas"
	id = "mustard_gas"
	description = "A deadly gas that causes burns inside and out."
	reagent_state = GAS
	color = "#A2CD5A"
	strength = 30
	touch_met = 5
//	meltdose = 4

/datum/reagent/toxin/mustard_gas/touch_mob(var/mob/living/L, var/amount)
	if (istype(L))
		eye_damage(L, get_severity(amount))
		external_damage(L, get_severity(amount))
		internal_damage(L, get_severity(amount))
		open_wound_damage(L, get_severity(amount))
/datum/reagent/toxin/mustard_gas/white_phosphorus
	name = "White Phosphorus Gas"
	id = "white_phosphorus_gas"
	description = "A deadly white gas that burns you up like a torch."
	reagent_state = GAS
	color = "#FFFFFF"
	strength = 30
	touch_met = 5
//	meltdose = 4

/datum/reagent/toxin/white_phosphorus/touch_mob(var/mob/living/L, var/amount)
	if (istype(L))
		eye_damage(L, get_severity(amount)*3)
		external_damage(L, get_severity(amount)*3)
		open_wound_damage(L, get_severity(amount)*3)
//green cross
/datum/reagent/toxin/chlorine_gas
	name = "Chlorine Gas"
	id = "chlorine_gas"
	description = "A deadly gas that destroys your lungs."
	reagent_state = GAS
	color = "#ffd700"
	strength = 30
	touch_met = 5
	alpha = 128
//	meltdose = 4

/datum/reagent/toxin/chlorine_gas/touch_mob(var/mob/living/L, var/amount)
	if (istype(L))
		eye_damage(L, get_severity(amount/2))
		internal_damage(L, get_severity(amount)*2)

/datum/reagent/toxin/phosgene_gas
	name = "Phosgene Gas"
	id = "phosgene_gas"
	description = "A deadly gas that causes suffocation."
	reagent_state = GAS
	color = "#eaeaea"
	strength = 30
	touch_met = 5
	alpha = 25
/datum/reagent/toxin/phosgene_gas/touch_mob(var/mob/living/L, var/amount)
	if (istype(L))
		suffocation(L, get_severity(amount)*4)


/datum/reagent/toxin/zyklon_b
	name = "Zyklon B"
	id = "zyklon_b"
	description = "A gas used for delousing. Would require unrealistically high concentrations to harm a human."
	reagent_state = GAS
	color = "#00a0b0"
	strength = FALSE
	touch_met = FALSE
	alpha = 50
//	meltdose = 4

/datum/reagent/toxin/zyklon_b/touch_mob(var/mob/living/L, var/amount)
	if (istype(L))
		internal_damage(L, get_severity(amount)*4)
	if (istype(L, /mob/living/simple_animal/cockroach) || istype(L, /mob/living/simple_animal/mosquito) || istype(L, /mob/living/simple_animal/fly))
		L.death()

/datum/reagent/toxin/zyklon_b/affect_ingest(var/mob/living/human/M, var/alien, var/removed)

	..(M, alien, removed)

/datum/reagent/toxin/zyklon_b/affect_touch(var/mob/living/human/M, var/alien, var/removed)


	..(M, alien, removed)

/datum/reagent/toxin/zyklon_b/affect_blood(var/mob/living/human/M, var/alien, var/removed)

	..(M, alien, removed)