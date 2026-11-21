// Cool cellars: the earth keeps a room underground at a steady, cool
// temperature. Weather never reaches it and the seasons only move it a little,
// so food keeps longer down there and it is the coolest place in summer.
// A fire in the room still warms it (get_temp in weather.dm).

#define CELLAR_TEMPERATURE 12      // degrees C the earth holds a cellar at
#define CELLAR_SEASON_SHARE 0.15   // how much of the surface season reaches it
#define CELLAR_WARMEST 18          // even under a desert a cellar stays below this
#define CELLAR_DECAY_SHARE 0.6     // food ages this much as fast in a cellar
#define CELLAR_DECAY_FLOOR 60      // but never as slowly as a cold ice house (50)

// On the map's underground level or in its compiled caves.
/proc/turf_in_cool_cellar(atom/A)
	var/turf/T = get_turf(A)
	if (!T)
		return FALSE
	if (istype(T.loc, /area/caribbean/void/caves))
		return TRUE
	return underground_depth_of(T.z) > 0

// The cellar temperature for a surface season temperature: close to
// CELLAR_TEMPERATURE, a little colder in winter and a little warmer in summer.
/proc/cool_cellar_temperature(season_temp)
	return min(CELLAR_WARMEST, round(CELLAR_TEMPERATURE + (season_temp - CELLAR_TEMPERATURE) * CELLAR_SEASON_SHARE))

// One food decay step, slowed when the food sits in a cellar. Steps that are
// already as slow as a freezer stay as they are.
/proc/cool_cellar_decay_step(atom/food, step)
	if (step <= CELLAR_DECAY_FLOOR || !turf_in_cool_cellar(food))
		return step
	return max(CELLAR_DECAY_FLOOR, round(step * CELLAR_DECAY_SHARE))

#undef CELLAR_TEMPERATURE
#undef CELLAR_SEASON_SHARE
#undef CELLAR_WARMEST
#undef CELLAR_DECAY_SHARE
#undef CELLAR_DECAY_FLOOR
