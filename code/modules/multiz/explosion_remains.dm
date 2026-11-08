// What an explosion, a demolished wall or a pried-up floor leaves behind.
// The area base turf is earth, which is right on the ground but wrong in the
// air: on an upper level (a Reichstag roof, a building storey) it put a patch
// of diggable dirt in the sky that players tunnelled down through. Above the
// ground the remains are bare plating instead, and open air is never replaced.
#define ABOVE_GROUND_SAMPLE_STEP 4
// A compiled level counts as above the ground when at least 1/20 of it is open air.
#define ABOVE_GROUND_OPEN_RATIO 20

var/list/above_ground_level_cache = list()

// TRUE for a level that is above the ground: one whose layout is partly open
// air, such as a building storey or a building level added over the surface.
// The lowest level, a dug cave and practice rooms have nothing below them.
// Levels are only ever appended, so each level is sampled once.
/proc/multiz_level_is_above_ground(z)
	if (!z || z > world.maxz || z == building_allocating_z || orbit_world() || !multiz_level_below(z))
		return FALSE
	var/key = "[z]"
	var/cached = above_ground_level_cache[key]
	if (!isnull(cached))
		return cached
	var/open = 0
	var/total = 0
	for (var/x = 1 to world.maxx step ABOVE_GROUND_SAMPLE_STEP)
		for (var/y = 1 to world.maxy step ABOVE_GROUND_SAMPLE_STEP)
			total++
			if (building_open_turf(locate(x, y, z)))
				open++
	. = (total && open * ABOVE_GROUND_OPEN_RATIO >= total) ? TRUE : FALSE
	above_ground_level_cache[key] = .

// TRUE when T is above the ground: its level is above the ground and the turf
// below is not earth or rock (a stacked map can keep a cave under part of it).
/proc/turf_is_above_ground(turf/T)
	if (!T || !multiz_level_is_above_ground(T.z))
		return FALSE
	var/turf/below = locate(T.x, T.y, multiz_level_below(T.z))
	if (!below)
		return FALSE
	if (istype(below, /turf/floor/dirt/underground) || istype(below, /turf/wall/rockwall) || istype(below.loc, /area/caribbean/void/caves))
		return FALSE
	return TRUE

// The turf type a destroyed floor or wall becomes.
/turf/proc/destroyed_turf_type()
	if (turf_is_above_ground(src))
		return /turf/floor/plating
	return get_base_turf_by_area(src)

// Replaces a destroyed floor or wall. Returns FALSE when nothing changes.
/turf/proc/become_destroyed_turf()
	if (building_open_turf(src))
		return FALSE
	var/remains = destroyed_turf_type()
	if (!remains || type == remains)
		return FALSE
	ChangeTurf(remains)
	return TRUE

// Scorches the ground where a shell lands. Floors above the ground, open air
// and beaches keep their turf; only the blast itself acts on them.
/turf/proc/scorch_ground()
	if (building_open_turf(src) || istype(src, /turf/floor/beach) || turf_is_above_ground(src))
		return FALSE
	ChangeTurf(/turf/floor/dirt/burned)
	return TRUE

// Open air has no floor for a blast to destroy.
/turf/floor/broken_floor/ex_act(severity)
	return FALSE

#undef ABOVE_GROUND_SAMPLE_STEP
#undef ABOVE_GROUND_OPEN_RATIO
