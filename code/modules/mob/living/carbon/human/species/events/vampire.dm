// normal stats with the exception of strength & survival
/mob/living/carbon/human/vampire
	takes_less_damage = TRUE
	movement_speed_multiplier = 2.00
	has_hunger_and_thirst = FALSE
	has_pain = FALSE

	var/blood = 0.75

	color = "#FFB2B2"

	var/absorbing = FALSE

/mob/living/carbon/human/vampire/dummy
	status_flags = GODMODE|CANPUSH

/mob/living/carbon/human/vampire/New(_loc, new_species, clothes = TRUE, snowflake = FALSE)
	..(_loc, new_species)

	var/oloc = loc
	job_master.EquipRank(src, "Vampire")
	if (!clothes)
		for (var/obj/item/clothing/I in contents)
			drop_from_inventory(I)
			qdel(I)
	if (snowflake)
		spawn (1)
			loc = oloc
			setStat("strength", 300)
			setStat("engineering", 150)
			setStat("rifle", 150)
			setStat("mg", 150)
			setStat("smg", 150)
			setStat("pistol", 150)
			setStat("heavyweapon", 150)
			setStat("medical", 150)
			setStat("shotgun", 150)
			setStat("survival", 100)
			setStat("stamina", 200)

/mob/living/carbon/human/vampire/proc/may_drink()
	return blood <= 1.40

/mob/living/carbon/human/vampire/proc/drink(var/mob/living/carbon/human/H)
	if (!istype(H))
		return FALSE
	if (H.type == type)
		return FALSE
	if (H.vessel.total_volume <= 0)
		src << "<span class = 'danger'>[H] has no blood left to offer us.</span>"
		return
	if (absorbing)
		return FALSE
	absorbing = TRUE
	visible_message("<span class = 'danger'>[src] starts to absorb [H]'s blood through his fingers!</span>")
	playsound(get_turf(src), 'sound/effects/bloodsuck.ogg', 100)
	for (var/v in 1 to 5)
		spawn ((v-1) * 10)
			if (do_after(src, 10, H, check_for_repeats = FALSE))
				visible_message("<span class = 'danger'>[src] absorbs [H]'s blood through his fingers!</span>")
				blood = min(1.50, blood+0.10)
				var/H_bloodloss = min(112, H.vessel.total_volume)
				H.drip(H_bloodloss)
				drip(-H_bloodloss)
				for (var/datum/reagent/blood/B in vessel.reagent_list)
					B.volume = min(B.volume, vessel.maximum_volume)
				H.adjustOxyLoss(7)
				if (H.vessel.total_volume <= 0)
					src << "<span class = 'danger'>[H] has no blood left to offer us.</span>"
					return
	spawn (50)
		absorbing = FALSE

/mob/living/carbon/human/vampire/Life()
	..()

	nutrition = max_nutrition
	water = max_water

	// suppress pain and shock
	traumatic_shock = 0
	shock_stage = 0
	analgesic = 100

	// takes 625 ticks (21 minutes) for us to start starving, if we don't consume any blood
	// while blood == 0, we don't heal either

	// update: now it takes twice as many ticks because we use blood when healing
	// too
	blood = max(0, blood - (0.0008/2))
	if (blood <= 0)
		if (prob(10))
			adjustBruteLoss(40)
			src << "<span class = 'danger'>You're starving from a lack of blood!</span>"
		return

	var/loss = getTotalLoss()

	var/heal_damage = (7 * (blood * blood)) + 2
	adjustBruteLoss(-heal_damage*getStatCoeff("strength")*VAMPIRE_HEAL_DAMAGE_MULTIPLIER)
	adjustFireLoss(-heal_damage*getStatCoeff("strength")*VAMPIRE_HEAL_DAMAGE_MULTIPLIER)
	adjustToxLoss(-heal_damage*getStatCoeff("strength")*VAMPIRE_HEAL_DAMAGE_MULTIPLIER)
	adjustOxyLoss((-heal_damage*getStatCoeff("strength")*VAMPIRE_HEAL_DAMAGE_MULTIPLIER)/10)

	// removes broken heart meme
	for (var/obj/item/organ/I in internal_organs)
		I.damage = 0

	var/healedLoss = loss - getTotalLoss()
	if (healedLoss > 0)
		if (blood >= 0.25)
			blood -= ((healedLoss/3000) * getStatCoeff("strength"))

	if (istype(loc, /turf))
		var/area/A = get_area(src)
		if (A.location == AREA_OUTSIDE && A.weather != WEATHER_RAIN)
			for (var/atom/movable/lighting_overlay/LO in loc)
				if (list("Early Morning", "Morning", "Afternoon", "Midday").Find(LO.TOD))
					emote("scream")
					visible_message("<span class = 'danger'>[src] turns into dust!</span>")
					for (var/obj/item/I in contents)
						drop_from_inventory(I)
					dust()

/mob/living/carbon/human/vampire/Stat()
	. = ..()
	if (.)
		stat("")
		stat(stat_header("Vampire"))
		stat("")
		stat("Blood:", "[round(blood*100)]%")