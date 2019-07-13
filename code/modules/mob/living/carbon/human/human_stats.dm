/mob/living/carbon/human/proc/getStat(statname)
	return stats[lowertext(statname)][1]*mood_modifier

/mob/living/carbon/human/proc/getMaxStat(statname)
	return stats[lowertext(statname)][2]

/mob/living/carbon/human/proc/getStatCoeff(statname)
	if (stats[lowertext(statname)] && stats[lowertext(statname)][1])
		return (stats[lowertext(statname)][1]/100)*mood_modifier
	else
		return 0


/mob/living/carbon/human/proc/getLesserStatCombinedCoeff(var/list/statnames = list())
	. = 1 - (statnames.len/10)
	for (var/statname in statnames)
		. += stats[lowertext(statname)][1]/1000

/mob/living/carbon/human/proc/setStat(statname, statval)

	statname = lowertext(statname)
	if (!stats.Find(statname))
		return

	// randomness
	statval += rand(-5,5)

	// realism + balancing
	if (gender == FEMALE)
		switch (statname)
			if ("strength")
				statval -= 15
			else
				statval += pick(round(15/stats.len), ceil(15/stats.len))

	// crafting, medical: more age benefits you
	if (list("crafting", "medical").Find(statname))
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
	// all other stats: more age hurts
	else
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
				statval -= rand(2,3)
			if (36 to 39)
				statval -= rand(4,5)
			if (40 to 45) // dadbod
				statval -= rand(6,7)
			if (46 to 55)
				statval -= rand(8,10)
			if (56 to INFINITY)
				statval -= rand(9,12)

	stats[statname] = list(statval, statval)

/mob/living/carbon/human/proc/adaptStat(statname, multiplier = 1)
	statname = lowertext(statname)
	if (!stats.Find(statname))
		return

	var/increase_multiple = 0.001 // 1 / 1000, to prevent crazy ugly decimals

	if (list("dexterity").Find(statname))
		stats[statname][1] *= (1 + round(multiplier/100, increase_multiple))
		stats[statname][2] *= (1 + round(multiplier/100, increase_multiple))

	else if (list("rifle", "pistol", "bows", "mg" ).Find(statname))
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

	else
		stats[statname][1] *= (1 + round(multiplier/100, increase_multiple))
		stats[statname][2] *= (1 + round(multiplier/100, increase_multiple))

	// stats may not go over 250
	for (var/sname in stats)
		stats[sname][1] = min(stats[sname][1], 250.00)
		stats[sname][2] = min(stats[sname][1], 250.00)