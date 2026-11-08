// Canopy shelter: standing under a pitched canopy (tent) keeps the rain off
// and blocks the wind, so it is a little warmer than the open air.
// Idea from CM-SS13's tents (cmss13-devs/cmss13, AGPL-3.0), which give cold
// protection to people inside; reimplemented for Civ13's canopies.

#define CANOPY_WARMTH_C 5
#define CANOPY_WARMTH_CAP_C 15

/proc/under_canopy(turf/T)
	if (!T)
		return FALSE
	return locate(/obj/structure/tent) in T

// Air temperature (Celsius) felt under a canopy on T: up to 5 C warmer when
// it is cold, never above 15 C, and unchanged when it is already mild.
/proc/canopy_shelter_temperature(turf/T, loc_temp)
	if (!under_canopy(T) || loc_temp >= CANOPY_WARMTH_CAP_C)
		return loc_temp
	return min(loc_temp + CANOPY_WARMTH_C, CANOPY_WARMTH_CAP_C)

#undef CANOPY_WARMTH_C
#undef CANOPY_WARMTH_CAP_C
