// Era helpers. The current era is map.ordinal_age; with no map nothing past
// the first era is unlocked. Use these instead of writing out one branch per
// era with the same options repeated in each.

/proc/current_era()
	return map ? map.ordinal_age : null

// TRUE when the current era is at least `age`.
/proc/era_at_least(age)
	return map && map.ordinal_age >= age

// TRUE when the current era is between `low` and `high`, both included.
/proc/era_between(low, high)
	return map && map.ordinal_age >= low && map.ordinal_age <= high

// The options unlocked in the current era, in the order given. Each option maps
// to the first era it appears in, or to list(first, last) when it is retired
// later. Options mapped to null are always offered.
//   era_options(list("none" = null, "tunic" = 1, "pistol" = list(4, 6)))
/proc/era_options(list/options)
	var/list/unlocked = list()
	for (var/option in options)
		var/when = options[option]
		if (isnull(when))
			unlocked += option
		else if (islist(when))
			if (era_between(when[1], when[2]))
				unlocked += option
		else if (era_at_least(when))
			unlocked += option
	return unlocked

// The value for the current era. `by_era` maps "N" (exactly era N) or "N+"
// (era N and later) to a value; an exact entry wins over the highest "N+"
// entry at or below the current era. With no match, or no map, returns `fallback`.
//   era_pick(list("0" = "bone", "1" = "bronze", "3+" = "steel"), "iron")
/proc/era_pick(list/by_era, fallback = null)
	if (!map)
		return fallback
	var/age = map.ordinal_age
	if ("[age]" in by_era)
		return by_era["[age]"]
	var/best = null
	var/best_from = -1
	for (var/key in by_era)
		if (copytext(key, -1) != "+")
			continue
		var/from = text2num(copytext(key, 1, -1))
		if (from <= age && from > best_from)
			best_from = from
			best = by_era[key]
	return best_from >= 0 ? best : fallback
