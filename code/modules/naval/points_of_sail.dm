// ============================================================
// Points of sail
// ------------------------------------------------------------
// Every sailing craft asks here how the wind stands to her bow. A sailing
// ship is fastest with the wind across her (a beam or broad reach), a little
// slower running dead before it, slow close-hauled, and cannot point into
// it at all: heading upwind she beats, tacking across the wind, and makes
// good only a third of her reach speed. Ships here sail the four compass
// headings and the wind blows from one of them, so a heading is a beam
// reach, a run or a beat; close-hauled and broad reaches are for headings
// and winds that sit between them.
//
// The wind is the map's (weather_systems.dm). Ocean currents, when they
// come, add to the water a ship sails through and belong beside this.
// ============================================================

// The direction the wind blows from.
/proc/wind_from_dir()
	return weather_wind_from_dir(map?.winddirection)

// The angle from the bow to where the wind blows from, to the nearest point
// of sail: SAIL_POINT_BEATING (into the wind) to SAIL_POINT_RUNNING (dead
// before it).
/proc/point_of_sail(heading, wind_from = null)
	if (!wind_from)
		wind_from = wind_from_dir()
	if (!(heading in alldirs))
		return SAIL_POINT_BEAM
	var/off = abs(dir2angle(heading) - dir2angle(wind_from))
	if (off > 180)
		off = 360 - off
	if (off < 23)
		return SAIL_POINT_BEATING
	if (off < 68)
		return SAIL_POINT_CLOSE
	if (off < 113)
		return SAIL_POINT_BEAM
	if (off < 158)
		return SAIL_POINT_BROAD
	return SAIL_POINT_RUNNING

// How many times longer a step under sail takes on this heading than on a
// beam reach.
/proc/sail_delay_factor(heading, wind_from = null)
	switch (point_of_sail(heading, wind_from))
		if (SAIL_POINT_BEATING)
			return SAIL_DELAY_BEATING
		if (SAIL_POINT_CLOSE)
			return SAIL_DELAY_CLOSE
		if (SAIL_POINT_RUNNING)
			return SAIL_DELAY_RUNNING
	return SAIL_DELAY_REACH

// What a sailor calls it.
/proc/point_of_sail_name(heading, wind_from = null)
	switch (point_of_sail(heading, wind_from))
		if (SAIL_POINT_BEATING)
			return "beating into the wind"
		if (SAIL_POINT_CLOSE)
			return "close-hauled"
		if (SAIL_POINT_BEAM)
			return "on a beam reach"
		if (SAIL_POINT_BROAD)
			return "on a broad reach"
	return "running before the wind"

// Tenths of a second a sail step takes on a beam reach in wind of this
// strength (0 calm to 4 gale, weather_wind_at()).
/proc/sail_step_delay(strength)
	switch (strength)
		if (0)
			return 40
		if (1)
			return 15
		if (2)
			return 11
		if (3)
			return 7
	return 4

// A sail step at this place and heading: the wind's strength there (a storm
// overhead brings a gale) and how it stands to the bow.
/proc/sail_step_time(atom/A, heading)
	return sail_step_delay(weather_wind_at(A)) * sail_delay_factor(heading)
