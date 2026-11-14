// Water turf questions in one place.
//
// Every water tile is a /turf/floor/beach/water, and that includes frozen
// water (/ice). Salt water already says so with the turf's `salty` var.
// - is_liquid_water(): water that is not frozen.
// - is_open_water(): liquid water or a flooded trench, the tiles boats float
//   on and people wade in.
// - is_open_sea(): the surface of deep salt water, not the sea layer below it.

/proc/is_liquid_water(turf/T)
	return istype(T, /turf/floor/beach/water) && !istype(T, /turf/floor/beach/water/ice)

/proc/is_open_water(turf/T)
	return is_liquid_water(T) || istype(T, /turf/floor/trench/flooded)

/proc/is_open_sea(turf/T)
	return istype(T, /turf/floor/beach/water/deep/saltwater) && !istype(T, /turf/floor/beach/water/deep/saltwater/underwater)
