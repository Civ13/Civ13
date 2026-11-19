// Strength and dexterity in unarmed physical contests: grabs, resisting,
// blocking, dodging and disarming. Between equals every chance is what it
// was before; a stronger or nimbler side shifts it, within bounds.

#define PHYSICAL_CONTEST_MIN_RATIO 0.5
#define PHYSICAL_CONTEST_MAX_RATIO 2
#define PHYSICAL_CONTEST_MIN_CHANCE 1
#define PHYSICAL_CONTEST_MAX_CHANCE 95

// How strong and nimble this mob is for a contest, 1 being an average person.
// Mobs without stats count as average.
/mob/living/proc/physical_power(str_weight, dex_weight)
	return 1

/mob/living/human/physical_power(str_weight, dex_weight)
	var/total = str_weight + dex_weight
	if (total <= 0)
		return 1
	var/strength = max(0.1, getStatCoeff("strength"))
	var/dexterity = max(0.1, getStatCoeff("dexterity"))
	return (strength * str_weight + dexterity * dex_weight) / total

// Attacker's power over defender's, weighted by how much each stat matters,
// bounded so stats tilt a contest without deciding it outright.
/proc/physical_contest_ratio(mob/living/attacker, mob/living/defender, str_weight, dex_weight)
	var/a = istype(attacker) ? attacker.physical_power(str_weight, dex_weight) : 1
	var/d = istype(defender) ? defender.physical_power(str_weight, dex_weight) : 1
	if (d <= 0)
		return PHYSICAL_CONTEST_MAX_RATIO
	return clamp(a / d, PHYSICAL_CONTEST_MIN_RATIO, PHYSICAL_CONTEST_MAX_RATIO)

// A base percent chance scaled by a contest ratio and kept in bounds.
/proc/physical_contest_chance(base, ratio)
	return clamp(base * ratio, PHYSICAL_CONTEST_MIN_CHANCE, PHYSICAL_CONTEST_MAX_CHANCE)

#undef PHYSICAL_CONTEST_MIN_RATIO
#undef PHYSICAL_CONTEST_MAX_RATIO
#undef PHYSICAL_CONTEST_MIN_CHANCE
#undef PHYSICAL_CONTEST_MAX_CHANCE
