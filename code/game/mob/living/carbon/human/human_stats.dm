/mob/living/human/proc/getStat(statname)
	return stats[lowertext(statname)][1]*mood_modifier

/mob/living/human/proc/getMaxStat(statname)
	return stats[lowertext(statname)][2]

/mob/living/human/proc/getStatCoeff(statname)
	var/str_mod = 1
	var/dex_mod = 1
	var/craft_mod = 1
	var/found_trait = FALSE // Failsafe for if someone has multiple traits

	if (find_trait("Dwarfism") && !found_trait)
		found_trait = TRUE
		str_mod = 0.7
		craft_mod = 1.5
	if (find_trait("Short") && !found_trait)
		found_trait = TRUE
		str_mod = 0.85
		craft_mod = 1.15
	if (find_trait("Tall") && !found_trait)
		found_trait = TRUE
		str_mod = 1.15
		dex_mod = 0.85
	if (find_trait("Gigantism") && !found_trait)
		found_trait = TRUE
		str_mod = 1.5
		dex_mod = 0.7
	var/med_mod = 1
	if (find_trait("Tinkerer"))
		str_mod *= 0.9
		craft_mod *= 1.1
	if (find_trait("Steady Hands"))
		med_mod *= 1.15
	if (find_trait("Butterfingers"))
		craft_mod *= 0.9
		med_mod *= 0.9

	// Apply modifiers
	if (stats[lowertext(statname)] && stats[lowertext(statname)][1])
		switch (statname)
			if ("strength")
				return (stats[lowertext(statname)][1]/100)*mood_modifier*str_mod
			if ("dexterity")
				return (stats[lowertext(statname)][1]/100)*mood_modifier*dex_mod
			if ("crafting")
				return (stats[lowertext(statname)][1]/100)*mood_modifier*craft_mod
			if ("medical")
				return (stats[lowertext(statname)][1]/100)*mood_modifier*med_mod
			if ("magic")
				return (stats[lowertext(statname)][1]/100)
			else
				return (stats[lowertext(statname)][1]/100)*mood_modifier
	else
		return FALSE



/mob/living/human/proc/setStat(statname, statval)

	statname = lowertext(statname)
	if (!stats.Find(statname))
		return
	// Persistent worlds: no magic skill off the magic whitelist (magic_whitelist.dm).
	if (statname == "magic" && !magic_allowed())
		stats[statname] = list(0, 0)
		return

	// randomness
	statval += rand(-5,5)

	// realism + balancing
	if (gender == FEMALE)
		if (statname == "strength")
			statval -= 15
		else
			statval += pick(round(15/stats.len), ceil(15/stats.len))
		if (statname == "dexterity")
			statval += 15
		else
			statval += pick(round(15/stats.len), ceil(15/stats.len))

	// crafting, medical, philosophy: more age benefits you
	if (list("crafting", "medical", "philosophy").Find(statname))
		switch (age)
			if (0 to 15) // how did you even get here?
				statval -= 3
			if (16 to 19)
				statval -= 2
			if (20 to 24)
				PASS
			if (25 to 29)
				statval += 2
			if (30 to 35)
				statval += 3
			if (36 to 39)
				statval += 4
			if (40 to 45)
				statval += 5
			if (46 to 55)
				statval += 6
			if (56 to INFINITY)
				statval += 7
	// dexterity, strength: more age hurts
	else if (list("dexterity", "strength").Find(statname))
		switch (age)
			if (0 to 15) // how did you even get here?
				statval -= rand(8,10)
			if (16 to 19)
				statval -= rand(4,5)
			if (20 to 24)
				PASS
			if (25 to 29)
				statval += rand(4,5)
			if (30 to 35)
				statval += rand(2,3)
			if (36 to 39)
				statval -= rand(3,4)
			if (40 to 45)
				statval -= rand(5,6)
			if (46 to 55)
				statval -= rand(8,10)
			if (56 to INFINITY)
				statval -= rand(9,12)

	stats[statname] = list(statval, statval)

// variety_key names the exact thing done (a recipe, a surgery step, a crop):
// on book-research worlds new things teach more than repeats (learning_by_doing.dm).
/mob/living/human/proc/adaptStat(statname, multiplier = 1, variety_key = null)
	statname = lowertext(statname)
	ensure_late_stats()
	if (!stats.Find(statname))
		return
	// Persistent worlds: no magic skill gains off the magic whitelist (magic_whitelist.dm).
	if (statname == "magic" && multiplier > 0 && !magic_allowed())
		return
	if (multiplier > 0)
		multiplier *= trait_skill_gain_mult(statname) * skill_variety_mult(statname, variety_key) * skill_master_mult(statname) * rested_learning_multiplier(statname)
		var/gain_cap = skill_gain_cap(statname)
		if (gain_cap)
			multiplier = min(multiplier, gain_cap)

	var/increase_multiple = 0.001 // 1 / 1000, to prevent crazy ugly decimals
	var/before_value = stats[statname][1]
	var/before_max = stats[statname][2]

	if (list("dexterity").Find(statname))
		stats[statname][1] *= (1 + round(multiplier/100, increase_multiple))
		stats[statname][2] *= (1 + round(multiplier/100, increase_multiple))

	else if (list("rifle", "pistol", "bows", "machinegun" ).Find(statname))
		stats[statname][1] *= (1 + round(multiplier/150, increase_multiple))
		stats[statname][2] *= (1 + round(multiplier/150, increase_multiple))

	else if (statname == "swords")
		stats[statname][1] *= (1 + round(multiplier/150, increase_multiple))
		stats[statname][2] *= (1 + round(multiplier/150, increase_multiple))

	else if (statname == "crafting")
		stats[statname][1] *= (1 + round(multiplier/500, increase_multiple))
		stats[statname][2] *= (1 + round(multiplier/500, increase_multiple))

	else if (statname == "medical")
		stats[statname][1] *= (1 + round(multiplier/100, increase_multiple))
		stats[statname][2] *= (1 + round(multiplier/100, increase_multiple))

	else if (statname == "farming")
		stats[statname][1] *= (1 + round(multiplier/200, increase_multiple))
		stats[statname][2] *= (1 + round(multiplier/200, increase_multiple))

	else if (statname == "magic")
		stats[statname][1] *= (1 + round(multiplier/100, increase_multiple))
		stats[statname][2] *= (1 + round(multiplier/100, increase_multiple))

	else if (list("strength", "stamina").Find(statname))
		stats[statname][1] *= (1 + round(multiplier/150, increase_multiple))
		stats[statname][2] *= (1 + round(multiplier/150, increase_multiple))

	else if (list("throwing", "hunting", "swimming", "unarmed").Find(statname))
		stats[statname][1] *= (1 + round(multiplier/200, increase_multiple))
		stats[statname][2] *= (1 + round(multiplier/200, increase_multiple))

	else if (statname == "philosophy")
		stats[statname][1] *= (1 + round(multiplier/100, increase_multiple))
		stats[statname][2] *= (1 + round(multiplier/100, increase_multiple))

	// stats may not go over 250, magic 100
	var/cap = (statname == "magic") ? 100.00 : 250.00
	stats[statname][1] = min(stats[statname][1], cap)
	stats[statname][2] = min(stats[statname][2], cap)
	// One gain stops at the next skill milestone, so each is reached and paid in turn.
	if (multiplier > 0)
		var/ceiling = skill_mastery_ceiling(statname, before_value)
		if (ceiling)
			stats[statname][1] = min(stats[statname][1], max(ceiling, before_value))
			stats[statname][2] = min(stats[statname][2], max(ceiling, before_max))
	// Reaching a milestone in a skill teaches its scholarship (learning_by_doing.dm).
	if (multiplier > 0)
		note_skill_mastery(statname)
		