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
	
	// Apply modifiers
	if (stats[lowertext(statname)] && stats[lowertext(statname)][1])
		switch (statname)
			if ("strength")
				return (stats[lowertext(statname)][1]/100)*mood_modifier*str_mod
			if ("dexterity")
				return (stats[lowertext(statname)][1]/100)*mood_modifier*dex_mod
			if ("crafting")
				return (stats[lowertext(statname)][1]/100)*mood_modifier*craft_mod
			else
				return (stats[lowertext(statname)][1]/100)*mood_modifier
	else
		return FALSE

/mob/living/human/proc/getLesserStatCombinedCoeff(var/list/statnames = list())
	. = 1 - (statnames.len/10)
	for (var/statname in statnames)
		. += stats[lowertext(statname)][1]/1000

/mob/living/human/proc/setStat(statname, statval)

	statname = lowertext(statname)
	if (!stats.Find(statname))
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

/mob/living/human/proc/adaptStat(statname, multiplier = 1)
	statname = lowertext(statname)
	if (!stats.Find(statname))
		return

	var/increase_multiple = 0.001 // 1 / 1000, to prevent crazy ugly decimals

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

	else
		stats[statname][1] *= (1 + round(multiplier/100, increase_multiple))
		stats[statname][2] *= (1 + round(multiplier/100, increase_multiple))

	// stats may not go over 250
	for (var/sname in stats)
		stats[sname][1] = min(stats[sname][1], 250.00)
		stats[sname][2] = min(stats[sname][1], 250.00)