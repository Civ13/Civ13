//Updates the mob's health from organs and mob damage variables
/mob/living/carbon/human/updatehealth()

	next_calculate_tally = world.time - 1

	if (status_flags & GODMODE)
		health = maxHealth
		stat = CONSCIOUS
		return

	var/total_burn  = FALSE
	var/total_brute = FALSE
	for (var/obj/item/organ/external/O in organs)	//hardcoded to streamline things a bit
		if ((O.status & ORGAN_ROBOT) && !O.vital)
			continue //*non-vital* robot limbs don't count towards shock and crit
		total_brute += O.brute_dam
		total_burn  += O.burn_dam

	var/oxy_l = ((species.flags & NO_BREATHE) ? FALSE : getOxyLoss())
	var/tox_l = ((species.flags & NO_POISON) ? FALSE : getToxLoss())
	var/clone_l = getCloneLoss()

	health = maxHealth - oxy_l - tox_l - clone_l - total_burn - total_brute

	//TODO: fix husking
	if ( ((maxHealth - total_burn) < config.health_threshold_dead) && stat == DEAD)
		ChangeToHusk()

	return

/mob/living/carbon/human/adjustBrainLoss(var/amount)

	if (status_flags & GODMODE)	return FALSE	//godmode

	if (species && species.has_organ["brain"])
		var/obj/item/organ/brain/sponge = internal_organs_by_name["brain"]
		if (sponge)
			sponge.take_damage(amount)
			brainloss = sponge.damage
		else
			brainloss = 200
	else
		brainloss = FALSE

/mob/living/carbon/human/setBrainLoss(var/amount)

	if (status_flags & GODMODE)	return FALSE	//godmode

	if (species && species.has_organ["brain"])
		var/obj/item/organ/brain/sponge = internal_organs_by_name["brain"]
		if (sponge)
			sponge.damage = min(max(amount, FALSE),(maxHealth*2))
			brainloss = sponge.damage
		else
			brainloss = 200
	else
		brainloss = FALSE

/mob/living/carbon/human/getBrainLoss()

	if (status_flags & GODMODE)	return FALSE	//godmode

	if (species && species.has_organ["brain"])
		var/obj/item/organ/brain/sponge = internal_organs_by_name["brain"]
		if (sponge)
			brainloss = min(sponge.damage,maxHealth*2)
		else
			brainloss = 200
	else
		brainloss = FALSE
	return brainloss

//These procs fetch a cumulative total damage from all organs
/mob/living/carbon/human/getBruteLoss()
	var/amount = FALSE
	for (var/obj/item/organ/external/O in organs)
		if (O.status & ORGAN_ROBOT)
			continue //robot limbs don't count towards shock and crit
		amount += O.brute_dam
	return amount

/mob/living/carbon/human/getFireLoss()
	var/amount = FALSE
	for (var/obj/item/organ/external/O in organs)
		if (O.status & ORGAN_ROBOT)
			continue //robot limbs don't count towards shock and crit
		amount += O.burn_dam
	return amount


/mob/living/carbon/human/adjustBruteLoss(var/amount)
	amount = amount*species.brute_mod
	if (ishuman(src))
		var/mob/living/carbon/human/H = src
		if (H.takes_less_damage)
			amount /= H.getStatCoeff("strength")
	if (amount > 0)
		take_overall_damage(amount, FALSE)
	else
		heal_overall_damage(-amount, FALSE)

/mob/living/carbon/human/adjustFireLoss(var/amount)
	amount = amount*species.burn_mod
	if (ishuman(src))
		var/mob/living/carbon/human/H = src
		if (H.takes_less_damage)
			amount /= H.getStatCoeff("strength")
	if (amount > 0)
		take_overall_damage(0, amount)
	else
		heal_overall_damage(0, -amount)

/mob/living/carbon/human/proc/adjustBruteLossByPart(var/amount, var/organ_name, var/obj/damage_source = null)
	amount = amount*species.brute_mod
	if (organ_name in organs_by_name)
		var/obj/item/organ/external/O = get_organ(organ_name)

		if (amount > 0)
			O.take_damage(amount, 0, sharp=is_sharp(damage_source), edge = damage_source ? damage_source.edge : 0, used_weapon=damage_source)
		else
			//if you don't want to heal robot organs, they you will have to check that yourself before using this proc.
			O.heal_damage(-amount, 0, internal=0, robo_repair=(O.status & ORGAN_ROBOT))

/mob/living/carbon/human/proc/adjustFireLossByPart(var/amount, var/organ_name, var/obj/damage_source = null)
	amount = amount*species.burn_mod
	if (organ_name in organs_by_name)
		var/obj/item/organ/external/O = get_organ(organ_name)

		if (amount > 0)
			O.take_damage(amount, amount, sharp=is_sharp(damage_source), edge=damage_source ? damage_source.edge : 0, used_weapon=damage_source)
		else
			//if you don't want to heal robot organs, they you will have to check that yourself before using this proc.
			O.heal_damage(-amount, -amount, internal=0, robo_repair=(O.status & ORGAN_ROBOT))

/mob/living/carbon/human/Stun(amount)
	handle_zoom_stuff(1)
	..()

/mob/living/carbon/human/Weaken(amount)
	if (HULK in mutations)	return
	// 60% chance Vampires won't be affected; 96% Pillar Men won't be
	if (takes_less_damage && prob(15 + ceil(getStatCoeff("strength") * 9)))
		return
	// failing that, addition 50%/77% chance to get less weakened
	else if (prob(5 + ceil(getStatCoeff("strength") * 9)))
		amount /= pick(2,3)

	..()

/mob/living/carbon/human/Paralyse(amount)
	if (HULK in mutations)	return
	// Notify our AI if they can now control the suit.
	..()

/mob/living/carbon/human/getCloneLoss()
	if (species.flags & (NO_SCAN))
		cloneloss = FALSE
	return ..()

/mob/living/carbon/human/setCloneLoss(var/amount)
	if (species.flags & (NO_SCAN))
		cloneloss = FALSE
	else
		..()

/mob/living/carbon/human/adjustCloneLoss(var/amount)
	..()

	if (species.flags & (NO_SCAN))
		cloneloss = FALSE
		return

	var/heal_prob = max(0, 80 - getCloneLoss())
	var/mut_prob = min(80, getCloneLoss()+10)
	if (amount > 0)
		if (prob(mut_prob))
			var/list/obj/item/organ/external/candidates = list()
			for (var/obj/item/organ/external/O in organs)
				if (!(O.status & ORGAN_MUTATED))
					candidates |= O
			if (candidates.len)
				var/obj/item/organ/external/O = pick(candidates)
				O.mutate()
				src << "<span class = 'notice'>Something is not right with your [O.name]...</span>"
				return
	else
		if (prob(heal_prob))
			for (var/obj/item/organ/external/O in organs)
				if (O.status & ORGAN_MUTATED)
					O.unmutate()
					src << "<span class = 'notice'>Your [O.name] is shaped normally again.</span>"
					return

	if (getCloneLoss() < 1)
		for (var/obj/item/organ/external/O in organs)
			if (O.status & ORGAN_MUTATED)
				O.unmutate()
				src << "<span class = 'notice'>Your [O.name] is shaped normally again.</span>"

// Defined here solely to take species flags into account without having to recast at mob/living level.
/mob/living/carbon/human/getOxyLoss()
	if (species.flags & NO_BREATHE)
		oxyloss = FALSE
	return ..()

/mob/living/carbon/human/adjustOxyLoss(var/amount)
	if (species.flags & NO_BREATHE)
		oxyloss = FALSE
	else
		amount = amount*species.oxy_mod
		..(amount)

/mob/living/carbon/human/setOxyLoss(var/amount)
	if (species.flags & NO_BREATHE)
		oxyloss = FALSE
	else
		..()

/mob/living/carbon/human/getToxLoss()
	if (species.flags & NO_POISON)
		toxloss = FALSE
	return ..()

/mob/living/carbon/human/adjustToxLoss(var/amount)
	if (species.flags & NO_POISON)
		toxloss = FALSE
	else
		amount = amount*species.toxins_mod
		..(amount)

/mob/living/carbon/human/setToxLoss(var/amount)
	if (species.flags & NO_POISON)
		toxloss = FALSE
	else
		..()

////////////////////////////////////////////

//Returns a list of damaged organs
/mob/living/carbon/human/proc/get_damaged_organs(var/brute, var/burn)
	var/list/obj/item/organ/external/parts = list()
	for (var/obj/item/organ/external/O in organs)
		if ((brute && O.brute_dam) || (burn && O.burn_dam))
			parts += O
	return parts

//Returns a list of damageable organs
/mob/living/carbon/human/proc/get_damageable_organs()
	var/list/obj/item/organ/external/parts = list()
	for (var/obj/item/organ/external/O in organs)
		if (O.is_damageable())
			parts += O
	return parts

//Heals ONE external organ, organ gets randomly selected from damaged ones.
//It automatically updates damage overlays if necesary
//It automatically updates health status
/mob/living/carbon/human/heal_organ_damage(var/brute, var/burn)
	var/list/obj/item/organ/external/parts = get_damaged_organs(brute,burn)
	if (!parts.len)	return
	var/obj/item/organ/external/picked = pick(parts)
	if (picked.heal_damage(brute,burn))
		UpdateDamageIcon()
	updatehealth()


/*
In most cases it makes more sense to use apply_damage() instead! And make sure to check armour if applicable.
*/
//Damages ONE external organ, organ gets randomly selected from damagable ones.
//It automatically updates damage overlays if necesary
//It automatically updates health status
/mob/living/carbon/human/take_organ_damage(var/brute, var/burn, var/sharp = FALSE, var/edge = FALSE)
	var/list/obj/item/organ/external/parts = get_damageable_organs()
	if (!parts.len)	return
	var/obj/item/organ/external/picked = pick(parts)
	if (picked.take_damage(brute,burn,sharp,edge))
		UpdateDamageIcon()
	updatehealth()
	speech_problem_flag = TRUE


//Heal MANY external organs, in random order
/mob/living/carbon/human/heal_overall_damage(var/brute, var/burn)
	var/list/obj/item/organ/external/parts = get_damaged_organs(brute,burn)

	var/update = FALSE
	while (parts.len && (brute>0 || burn>0) )
		var/obj/item/organ/external/picked = pick(parts)

		var/brute_was = picked.brute_dam
		var/burn_was = picked.burn_dam

		update |= picked.heal_damage(brute,burn)

		brute -= (brute_was-picked.brute_dam)
		burn -= (burn_was-picked.burn_dam)

		parts -= picked
	updatehealth()
	speech_problem_flag = TRUE
	if (update)	UpdateDamageIcon()

// damage MANY external organs, in random order
/mob/living/carbon/human/take_overall_damage(var/brute, var/burn, var/sharp = FALSE, var/edge = FALSE, var/used_weapon = null)
	if (status_flags & GODMODE)	return	//godmode
	var/list/obj/item/organ/external/parts = get_damageable_organs()
	var/update = FALSE
	while (parts.len && (brute>0 || burn>0) )
		var/obj/item/organ/external/picked = pick(parts)

		var/brute_was = picked.brute_dam
		var/burn_was = picked.burn_dam

		update |= picked.take_damage(brute,burn,sharp,edge,used_weapon)
		brute	-= (picked.brute_dam - brute_was)
		burn	-= (picked.burn_dam - burn_was)

		parts -= picked
	updatehealth()
	if (update)	UpdateDamageIcon()


////////////////////////////////////////////

/*
This function restores the subjects blood to max.
*/
/mob/living/carbon/human/proc/restore_blood()
	if (species.flags & NO_BLOOD)
		return
	if (vessel.total_volume < species.blood_volume)
		vessel.add_reagent("blood", species.blood_volume - vessel.total_volume)

/*
This function restores all organs.
*/
/mob/living/carbon/human/restore_all_organs()
	for (var/obj/item/organ/external/current_organ in organs)
		current_organ.rejuvenate()

/mob/living/carbon/human/proc/HealDamage(zone, brute, burn)
	var/obj/item/organ/external/E = get_organ(zone)
	if (istype(E, /obj/item/organ/external))
		if (E.heal_damage(brute, burn))
			UpdateDamageIcon()
	else
		return FALSE
	return

/mob/living/carbon/human/proc/get_organ(var/zone)
	if (!zone)	zone = "chest"
	if (zone in list( "eyes", "mouth" ))
		zone = "head"
	return organs_by_name[zone]

/mob/living/carbon/human/apply_damage(var/damage = FALSE, var/damagetype = BRUTE, var/def_zone = null, var/blocked = FALSE, var/sharp = FALSE, var/edge = FALSE, var/obj/used_weapon = null)

	//visible_message("Hit debug. [damage] | [damagetype] | [def_zone] | [blocked] | [sharp] | [used_weapon]")

	//Handle other types of damage
	if (!stat && damagetype != BRUTE && damagetype != BURN)
		if (damagetype == HALLOSS && !(species && (species.flags & NO_PAIN)))
			if ((damage > 25 && prob(20)) || (damage > 50 && prob(60)))
				emote("scream")

		..(damage, damagetype, def_zone, blocked)
		return TRUE

	//Handle BRUTE and BURN damage
	handle_suit_punctures(damagetype, damage, def_zone)

	if (blocked >= 2)	return FALSE

	var/obj/item/organ/external/organ = null
	if (isorgan(def_zone))
		organ = def_zone
	else
		if (!def_zone)	def_zone = ran_zone(def_zone)
		organ = get_organ(check_zone(def_zone))
	if (!organ)	return FALSE

	if (blocked)
		damage = (damage/(blocked+1))

	switch(damagetype)
		if (BRUTE)
			damageoverlaytemp = 20
			damage = damage*species.brute_mod
			if (organ.take_damage(damage, FALSE, sharp, edge, used_weapon))
				UpdateDamageIcon()
			receive_damage()

		if (BURN)
			damageoverlaytemp = 20
			damage = damage*species.burn_mod
			if (organ.take_damage(0, damage, sharp, edge, used_weapon))
				UpdateDamageIcon()

	// Will set our damageoverlay icon to the next level, which will then be set back to the normal level the next mob.Life().
	updatehealth()
	return TRUE
