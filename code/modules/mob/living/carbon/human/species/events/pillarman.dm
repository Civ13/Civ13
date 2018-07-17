// poor stats with the exception of strength & survival
/mob/living/carbon/human/pillarman
	takes_less_damage = TRUE
	movement_speed_multiplier = 2.40
	size_multiplier = 1.50
	has_hunger_and_thirst = FALSE
	has_pain = FALSE

	var/next_pose = -1
	var/energy = 0.75

	var/absorbing = FALSE

	var/next_shoot_burning_blood = -1

	var/frozen = FALSE

/mob/living/carbon/human/pillarman/dummy
	status_flags = GODMODE|CANPUSH

/mob/living/carbon/human/pillarman/New(_loc, new_species, snowflake = FALSE)
	..(_loc, new_species)

	var/oloc = loc
	job_master.EquipRank(src, "Pillar Man")
	if (snowflake)
		spawn (2)
			loc = oloc
			setStat("strength", 400)
			setStat("engineering", 250)
			setStat("rifle", 250)
			setStat("mg", 250)
			setStat("smg", 250)
			setStat("pistol", 250)
			setStat("heavyweapon", 250)
			setStat("medical", 250)
			setStat("shotgun", 250)
			setStat("survival", 100)
			setStat("stamina", 200)

/mob/living/carbon/human/pillarman/proc/may_absorb()
	return energy <= 1.40

/mob/living/carbon/human/pillarman/proc/absorb(var/mob/living/carbon/human/H)
	if (!istype(H))
		return FALSE
	if (H.type == type)
		return FALSE
	if (absorbing)
		return FALSE
	absorbing = TRUE
	visible_message("<span class = 'danger'>[src] starts to absorb [H] through his fingers!</span>")
	playsound(get_turf(src), 'sound/effects/bloodsuck.ogg', 100)
	if (do_after(src, 25, H))
		visible_message("<span class = 'danger'>[src] absorbs [H] through his fingers!</span>")
		var/absorbed = 0.50
		if (istype(H, /mob/living/carbon/human/vampire))
			absorbed *= 2
		energy = min(1.50, energy+absorbed)
		drip(-500)
		for (var/datum/reagent/blood/B in vessel.reagent_list)
			B.volume = min(B.volume, vessel.maximum_volume)
		H.crush()
	else
		H.adjustBruteLoss(rand(20,30))
	absorbing = FALSE

/mob/living/carbon/human/pillarman/proc/shoot_burning_blood()

	visible_message("<span class = 'danger'>[src] ejects burning blood from their veins!</span>")
	next_shoot_burning_blood = world.time + 10

	var/steps = 0
	var/turf/T = get_step(src, dir)

	while (!T.density && !locate_dense_type(T.contents, /obj/structure) && steps < 10)
		T = get_step(T, dir)
		++steps

	var/obj/O = new/obj/burning_blood(get_turf(src))
	O.throw_at(T, 10, 1, src)

	return TRUE

/mob/living/carbon/human/pillarman/Life()
	..()

	nutrition = max_nutrition
	water = max_water

	// suppress pain and shock
	traumatic_shock = 0
	shock_stage = 0
	analgesic = 100

	// takes 625 ticks (21 minutse) for us to start starving, if we don't consume any blood
	// while blood == 0, we don't heal either

	// update: now it takes 3x as many ticks because we use blood when healing
	// too
	energy = max(0, energy - (0.0008/3))
	if (energy <= 0)
		if (prob(10))
			adjustBruteLoss(72)
			src << "<span class = 'danger'>You're starving from a lack of life energy!</span>"
		return

	var/loss = getTotalLoss()

	var/heal_damage = (14 * (energy * energy)) + 2
	adjustBruteLoss(-heal_damage*getStatCoeff("strength")*PILLARMAN_HEAL_DAMAGE_MULTIPLIER)
	adjustFireLoss(-heal_damage*getStatCoeff("strength")*PILLARMAN_HEAL_DAMAGE_MULTIPLIER)
	adjustToxLoss(-heal_damage*getStatCoeff("strength")*PILLARMAN_HEAL_DAMAGE_MULTIPLIER)
	adjustOxyLoss((-heal_damage*getStatCoeff("strength")*PILLARMAN_HEAL_DAMAGE_MULTIPLIER)/10)

	// removes broken heart meme
	for (var/obj/item/organ/I in internal_organs)
		I.damage = 0

	var/healedLoss = loss - getTotalLoss()
	if (healedLoss > 0)
		if (energy >= 0.25)
			energy -= ((healedLoss/4500) * getStatCoeff("strength"))

	if (istype(loc, /turf))
		var/area/A = get_area(src)
		if (A.location == AREA_OUTSIDE && A.weather != WEATHER_RAIN)
			for (var/atom/movable/lighting_overlay/LO in loc)
				if (list("Early Morning", "Morning", "Afternoon", "Midday").Find(LO.TOD))
					frozen = TRUE
					return


	frozen = FALSE

/mob/living/carbon/human/pillarman/Move()
	if (frozen)
		src << "<span class = 'danger'>You're frozen in place by the sunlight!</span>"
		return FALSE
	..()

/mob/living/carbon/human/pillarman/Stat()
	. = ..()
	if (. && client.status_tabs)
		stat("")
		stat(stat_header("Pillar Man"))
		stat("")
		stat("Energy:", "[round(energy*100)]%")

/mob/living/carbon/human/pillarman/verb/pose()
	set category = "Emote"
	emote("pose")