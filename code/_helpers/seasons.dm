// Questions about the current season that work for both season schemes
// (code/__defines/seasons.dm). Ask these instead of comparing season names,
// so a map on the wet/dry cycle is not missed by a check written for spring.

// The four-season cycle is running (not the wet/dry cycle or a fixed season name).
/proc/season_is_temperate()
	return season == SEASON_SPRING || season == SEASON_SUMMER || season == SEASON_FALL || season == SEASON_WINTER

// Spring or the wet season: snowmelt and rain swell rivers.
/proc/season_is_wet()
	return season == SEASON_SPRING || findtext(season, "Wet")

// Rain soaks the ground here: always outside dry climates, and in dry climates
// during winter, spring or the wet season. Rain then makes mud and can put out
// an oil fire.
/proc/rain_soaks_ground(area/A)
	if (!A || !(A.climate in list("semiarid", "jungle", "desert", "savanna")))
		return TRUE
	return season == SEASON_WINTER || season_is_wet()
