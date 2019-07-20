/mob/living/carbon/human/var/stored_tally = 0
/mob/living/carbon/human/var/next_calculate_tally = -1

/mob/living/carbon/human/movement_delay()

	if (world.time <= next_calculate_tally)
		return stored_tally

	var/tally = 0

	if (species.slowdown)
		tally = species.slowdown

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
	switch (mood)
		if (0 to 20)
			tally += 1
		if (20 to 40)
			tally += 0.7
		if (40 to 60)
			tally += 0.4
	if (wear_suit)
		var/obj/item/clothing/WS = wear_suit
		tally += WS.slowdown
		if (WS.accessories.len)
			for (var/obj/item/clothing/accessory/AC in WS.accessories)
				tally += AC.slowdown
	if (w_uniform)
		var/obj/item/clothing/WU = w_uniform
		tally += WU.slowdown
		if (WU.accessories.len)
			for (var/obj/item/clothing/accessory/AC in WU.accessories)
				tally += AC.slowdown
	if (shoes)
		tally += shoes.slowdown
	if (l_hand)
		if (istype(l_hand, /obj/item/weapon/shield))
			tally += l_hand.slowdown
	if (r_hand)
		if (istype(r_hand, /obj/item/weapon/shield))
			tally += r_hand.slowdown
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

	/* this is removed until coats protect from the cold, instead of ignoring it.
	   also, I'm reasonably sure that in real life being cold does not make you vastly slower - Kachnov
	if (bodytemperature < 283.222)
		tally += (283.222 - bodytemperature) / 10 * 1.75*/

	handle_stance()
	tally += max(2 * stance_damage, FALSE) //damaged/missing feet or legs is slow

	if (chem_effects.Find(CE_SPEEDBOOST))
		tally -= 0.10

	stored_tally = tally

	next_calculate_tally = world.time + 10
	if (werewolf)
		tally *= 0.7
	if (!isnull(riding_mob))
		return 0
	else
		return tally

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
