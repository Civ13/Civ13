// If you add a more comprehensive system, just untick this file.
// WARNING: Only works for up to 17 z-levels!
var/z_levels = FALSE // Each bit represents a connection between adjacent levels.  So the first bit means levels TRUE and 2 are connected.
/*
// If the height is more than TRUE, we mark all contained levels as connected.
/obj/effect/landmark/map_data/New()
	ASSERT(height > 1)
	// Due to the offsets of how connections are stored v.s. how z-levels are indexed, some magic number silliness happened.

	for (var/i = (height-1); i--;)
		z_levels |= (1 << (z+i-1))
*/
// The storage of connections between adjacent levels means some bitwise magic is needed.
proc/HasAbove(var/z)
	if (z >= world.maxz || z > 16 || z < 1)
		return FALSE
	return z_levels & (1 << (z - 1))

proc/HasBelow(var/z)
	if (z > world.maxz || z > 17 || z < 2)
		return FALSE
	return z_levels & (1 << (z - 2))

// Thankfully, no bitwise magic is needed here.
proc/GetAbove(var/atom/atom, var/obj/lift_controller/optional_lift_master)

	var/area/area = get_area(atom)
	var/area_lift_master = area.lift_master()
	if (!area_lift_master)
		var/turf/turf = get_turf(atom)
		if (!turf)
			return null
		return HasAbove(turf.z) ? get_step(turf, UP) : null
	else
		var/obj/lift_controller/lift = optional_lift_master

		if (!lift)
			lift = area_lift_master

		return lift_get_corresponding_atom(atom, lift)

proc/GetBelow(var/atom/atom, var/obj/lift_controller/optional_lift_master)

	if (istype(atom, /obj/skybox))
		var/obj/skybox/skybox = atom
		return skybox.GetBelow()

	else if (istype(atom, /turf/open))
		var/turf/open/O = atom
		if (O.skybox)
			return O.skybox.GetBelow()

	var/area/area = get_area(atom)
	var/area_lift_master = area.lift_master()
	if (!area_lift_master)
		var/turf/turf = get_turf(atom)
		if (!turf)
			world << "No turf"
			return null
		return HasBelow(turf.z) ? get_step(turf, DOWN) : null
	else
		var/obj/lift_controller/lift = optional_lift_master

		if (!lift)
			lift = area_lift_master

		return lift_get_corresponding_atom(atom, lift)


// most reliable with turfs
/proc/lift_get_corresponding_atom(var/atom/atom, var/obj/lift_controller/lift)

	var/area/corresponding = lift.corresponding_area
	var/obj/lift_controller/corresponding_lift = lift.target

	var/offset_x = atom.x - lift.x
	var/offset_y = atom.y - lift.y

	for (var/turf/turf in corresponding)
		var/corresponding_offset_x = turf.x - corresponding_lift.x
		var/corresponding_offset_y = turf.y - corresponding_lift.y

		if (corresponding_offset_x == offset_x)
			if (corresponding_offset_y == offset_y)
				if (istype(atom, /turf))
					return turf
				else
					for (var/atom/movable/am in turf)
						if (am.type == atom.type)
							return am
	return null

// for in game debugging
/turf/proc/GetBelowMemberFunction()
	return GetBelow(src)

/turf/proc/GetAboveMemberFunction()
	return GetAbove(src)
