// ============================================================
// Weather, night and murk at sea (docs/craft-core.md)
// ------------------------------------------------------------
// A lookout sees less far in bad weather. The murk at a place is what the
// weather over it takes off a lookout's range, in tiles, plus the
// interference of any hazard the sea chart holds there. A ship sees another
// when the distance is within her range less the worse murk of the two
// places. By night a ship running dark shows nothing to see: she is made
// out only within SEA_DARK_NIGHT_RANGE. Radar is not a lookout and sees
// through all of it.
// ============================================================

#define SEA_MURK_WET 10
#define SEA_MURK_SMOG 20
#define SEA_MURK_EXTREME 25
#define SEA_LOOKOUT_FLOOR 5
#define SEA_DARK_NIGHT_RANGE 10

// Tiles the weather and the chart's hazards take off a lookout at this turf.
/proc/sea_murk_at(turf/T)
	. = 0
	if (!T)
		return
	var/area/A = get_area(T)
	if (A)
		switch (A.weather)
			if (WEATHER_WET)
				. += SEA_MURK_WET
			if (WEATHER_SMOG)
				. += SEA_MURK_SMOG
			if (WEATHER_EXTREME)
				. += SEA_MURK_EXTREME
	var/datum/chart/sea/S = sea_charts["[T.z]"]
	if (S && S.hazards.len)
		var/list/at = S.chart_position(T)
		if (at)
			. += S.interference_at(at[1], at[2])

// What is in the air at this turf, for the helm, or null in clear weather.
/proc/sea_murk_name(turf/T)
	if (!T)
		return null
	var/datum/chart/sea/S = sea_charts["[T.z]"]
	if (S && S.hazards.len)
		var/list/at = S.chart_position(T)
		for (var/datum/chart_hazard/H in (at ? S.hazards_at(at[1], at[2]) : list()))
			if (H.interference > 0)
				return H.name
	var/area/A = get_area(T)
	if (A)
		switch (A.weather)
			if (WEATHER_WET)
				return "rain or snow"
			if (WEATHER_SMOG)
				return "smog"
			if (WEATHER_EXTREME)
				return "a storm"
	return null

/proc/sea_night()
	return time_of_day == "Night" || time_of_day == "Dark Night"

// How far her lookout sees where she lies.
/datum/craft/proc/lookout_range()
	var/base = token ? token.sensor_range : CHART_SENSOR_RANGE
	return max(min(base, SEA_LOOKOUT_FLOOR), base - sea_murk_at(centre()))

// TRUE when her lookout can make out the other ship.
/datum/craft/proc/sights(datum/craft/other)
	var/turf/here = centre()
	var/turf/there = other ? other.centre() : null
	if (!here || !there || here.z != there.z)
		return FALSE
	var/base = token ? token.sensor_range : CHART_SENSOR_RANGE
	var/reach = max(min(base, SEA_LOOKOUT_FLOOR), base - max(sea_murk_at(here), sea_murk_at(there)))
	if (other.running_dark && sea_night())
		reach = min(reach, SEA_DARK_NIGHT_RANGE)
	return get_dist(here, there) <= reach
