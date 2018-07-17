/mob/living/carbon/human/var/stored_tally = 0
/mob/living/carbon/human/var/next_calculate_tally = -1

/mob/living/carbon/human/movement_delay()

	if (world.time <= next_calculate_tally)
		return stored_tally

	var/tally = 0

	if (species.slowdown)
		tally = species.slowdown

	if (embedded_flag)
		handle_embedded_objects() //Moving with objects stuck in you can cause bad times.

	var/health_deficiency = (maxHealth - health)
	if (health_deficiency >= 40) tally += (health_deficiency / 25)

	if (!(species && (species.flags & NO_PAIN)))
		if (halloss >= 10) tally += (halloss / 10) //halloss shouldn't slow you down if you can't even feel it

	switch (nutrition)
		if (-INFINITY to 50)
			tally += 1.50
		if (50 to 75)
			tally += 1.25
		if (75 to 100)
			tally += 1.00
		if (100 to 150)
			tally += 0.75
		if (150 to 220)
			tally += 0.50

	switch (water)
		if (-INFINITY to 50)
			tally += 1.50
		if (50 to 75)
			tally += 1.25
		if (75 to 100)
			tally += 1.00
		if (100 to 150)
			tally += 0.75
		if (150 to 192)
			tally += 0.50

	if (wear_suit)
		tally += wear_suit.slowdown

	if (buckled && istype(buckled, /obj/structure/bed/chair/wheelchair))
		for (var/organ_name in list("l_hand","r_hand","l_arm","r_arm"))
			var/obj/item/organ/external/E = get_organ(organ_name)
			if (!E || E.is_stump())
				tally += 3
			if (E.status & ORGAN_SPLINTED)
				tally += 0.4
			else if (E.status & ORGAN_BROKEN)
				tally += 1.2
	else
		if (shoes)
			tally += shoes.slowdown

		for (var/organ_name in list("l_foot","r_foot","l_leg","r_leg"))
			var/obj/item/organ/external/E = get_organ(organ_name)
			if (!E || E.is_stump())
				tally += 4
			else if (E.status & ORGAN_SPLINTED)
				tally += 0.5
			else if (E.status & ORGAN_BROKEN)
				tally += 1.5

	var/obj/item/organ/external/E = get_organ("chest")
	if (!E || ((E.status & ORGAN_BROKEN) && E.brute_dam > E.min_broken_damage) || (E.status & ORGAN_MUTATED))
		tally += 3

	if (shock_stage >= 10) tally += 0.5

	if (aiming && aiming.aiming_at) tally += 5 // Iron sights make you slower, it's a well-known fact.

	if (FAT in mutations)
		tally += 1.5

	/* this is removed until coats protect from the cold, instead of ignoring it.
	   also, I'm reasonably sure that in real life being cold does not make you vastly slower - Kachnov
	if (bodytemperature < 283.222)
		tally += (283.222 - bodytemperature) / 10 * 1.75*/

	handle_stance()
	tally += max(2 * stance_damage, FALSE) //damaged/missing feet or legs is slow

	if (mRun in mutations)
		tally = max(tally, 0)

	if (chem_effects.Find(CE_SPEEDBOOST))
		tally -= 0.10

	stored_tally = tally

	next_calculate_tally = world.time + 10

	return tally

/mob/living/carbon/human/Process_Spacemove(var/check_drift = FALSE)
	return FALSE

/mob/living/carbon/human/slip_chance(var/prob_slip = 5)
	if (!..())
		return FALSE

	//Check hands and mod slip
	if (!l_hand)	prob_slip -= 2
	else if (l_hand.w_class <= 2)	prob_slip -= 1
	if (!r_hand)	prob_slip -= 2
	else if (r_hand.w_class <= 2)	prob_slip -= 1

	return prob_slip

/mob/living/carbon/human/Check_Shoegrip()
	if (species.flags & NO_SLIP)
		return TRUE
	if (shoes && (shoes.item_flags & NOSLIP) && istype(shoes, /obj/item/clothing/shoes/magboots))  //magboots + dense_object = no floating
		return TRUE
	return FALSE
