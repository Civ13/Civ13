// Trained skills raise the yield of renewable sources.
// Hunting scales the food from butchering; farming scales seeds and crops.
// Skills are 100 by default; each point above 100 adds 1% (capped at +100%).

#define HARVEST_SKILL_BASE 100
#define HARVEST_SKILL_MAX_BONUS 1

// Stats added after characters were first saved. A restored body keeps its
// saved stats list, so add the missing entry at the default value.
/mob/living/human/proc/ensure_late_stats()
	if (!islist(stats))
		return
	for (var/statname in list("hunting"))
		var/list/pair = stats[statname]
		if (!islist(pair) || pair.len != 2)
			stats[statname] = list(HARVEST_SKILL_BASE, HARVEST_SKILL_BASE)

/mob/living/human/after_load()
	..()
	ensure_late_stats()

// Extra yield fraction from a skill: 0 at 100 or below, 0.5 at 150, 1 at 200+.
// Uses the current value, so mood and injuries still matter.
/mob/living/human/proc/harvest_skill_bonus(statname)
	ensure_late_stats()
	var/list/pair = stats[statname]
	if (!islist(pair) || pair.len != 2)
		return 0
	var/current = pair[1] * mood_modifier
	return clamp((current - HARVEST_SKILL_BASE) / 100, 0, HARVEST_SKILL_MAX_BONUS)

// Scales a whole-number yield. The fractional part becomes a chance of one
// more, so small yields still benefit on average.
/proc/harvest_skill_amount(base, bonus)
	if (base <= 0 || bonus <= 0)
		return base
	var/extra = base * bonus
	var/whole = round(extra)
	if (prob((extra - whole) * 100))
		whole++
	return base + whole

/proc/harvest_skill_user_bonus(mob/user, statname)
	if (!ishuman(user))
		return 0
	var/mob/living/human/H = user
	return H.harvest_skill_bonus(statname)

#undef HARVEST_SKILL_BASE
#undef HARVEST_SKILL_MAX_BONUS
