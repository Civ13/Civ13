// Gunfire follows the hills (docs/terrain-height.md, "Gunfire"). A shot leaves
// the muzzle at the firer's height above its ground and flies in a straight
// line to the aim point above the target's ground. A ridge rising above that
// line stops it. From higher ground the line passes over people, cover and
// unroofed walls well below it, and above a roof it passes over the building.
// Flat ground keeps the old rules: a standing shot at a standing target is level.
// Muzzle and aim heights sit just under the line-of-sight eye and head tops
// (los_terrain.dm), so a target seen over a crest can be shot over it.

#define PROJECTILE_MUZZLE_STANDING 1.4
#define PROJECTILE_MUZZLE_LOW 0.4
#define PROJECTILE_ROOF_TOP 3
#define PROJECTILE_HEIGHT_EPSILON 0.001
// height_enter verdicts.
#define PROJECTILE_HEIGHT_CLEAR 0
#define PROJECTILE_HEIGHT_GROUND 1
#define PROJECTILE_HEIGHT_OVER 2

// Absolute height of the shot over the starting tile; null when heights do not
// apply to this shot (flat map, shells, shrapnel, aircraft guns).
/obj/item/projectile/var/tmp/height_start = null
// Height change per tile of distance from the starting tile.
/obj/item/projectile/var/tmp/height_slope = 0
/obj/item/projectile/var/tmp/datum/terrain_heights/height_map = null
// Ground and line height over the turf handleTurf is working on.
/obj/item/projectile/var/tmp/height_ground = 0
/obj/item/projectile/var/tmp/height_line = null

/proc/projectile_aim_height(atom/A)
	if (ismob(A))
		var/mob/M = A
		if (M.lying || M.prone || M.resting)
			return PROJECTILE_MUZZLE_LOW
	return PROJECTILE_MUZZLE_STANDING

// TRUE when start lies under an airborne aircraft frame: its guns fire from the
// air, above the hills.
/proc/projectile_from_airborne_aircraft(turf/start)
	if (!airborne_aircraft.len)
		return FALSE
	for (var/obj/structure/vehicleparts/frame/F in start)
		var/obj/structure/vehicleparts/axis/aircraft/A = F.axis
		if (istype(A) && A.airborne())
			return TRUE
	return FALSE

// Plans the shot's height line from start to the original target.
/obj/item/projectile/proc/height_plan(turf/start)
	height_start = null
	height_line = null
	height_map = null
	if (is_shrapnel || istype(src, /obj/item/projectile/shell) || !start || !map || !map.terrain_height_file)
		return
	var/datum/terrain_heights/H = map.terrain_heights()
	if (!H || !H.rows_by_z["[start.z]"])
		return
	var/turf/target = get_turf(original)
	if (!target || target.z != start.z || target == start || projectile_from_airborne_aircraft(start))
		return
	var/muzzle = firer ? projectile_aim_height(firer) : PROJECTILE_MUZZLE_STANDING
	var/aim = ismob(original) ? projectile_aim_height(original) : muzzle
	var/dx = target.x - start.x
	var/dy = target.y - start.y
	height_start = H.at(start.x, start.y, start.z) + muzzle
	height_slope = (H.at(target.x, target.y, target.z) + aim - height_start) / sqrt(dx * dx + dy * dy)
	height_map = H

// Works out the line over T for handleTurf: clear (ordinary rules, with
// height_passes_over for what stands on T), the ground rises above the line, or
// the line passes above a roofed tile and everything under the roof.
/obj/item/projectile/proc/height_enter(turf/T)
	height_line = null
	if (isnull(height_start) || !T || !starting || T == starting || T.z != starting.z)
		return PROJECTILE_HEIGHT_CLEAR
	var/dx = T.x - starting.x
	var/dy = T.y - starting.y
	var/line = height_start + height_slope * sqrt(dx * dx + dy * dy)
	height_ground = height_map.at(T.x, T.y, T.z)
	if (height_ground > line + PROJECTILE_HEIGHT_EPSILON)
		return PROJECTILE_HEIGHT_GROUND
	if (los_turf_roofed(T))
		return height_ground + PROJECTILE_ROOF_TOP < line - PROJECTILE_HEIGHT_EPSILON ? PROJECTILE_HEIGHT_OVER : PROJECTILE_HEIGHT_CLEAR
	height_line = line
	return PROJECTILE_HEIGHT_CLEAR

// TRUE when the line over the current open-sky turf passes above something top
// levels tall on its ground with a body's height to spare. A level shot over
// flat ground never does, so cover works there as before; height advantage
// takes it away.
/obj/item/projectile/proc/height_passes_over(top)
	if (isnull(height_line))
		return FALSE
	return height_ground + top < height_line - PROJECTILE_MUZZLE_STANDING - PROJECTILE_HEIGHT_EPSILON

#undef PROJECTILE_ROOF_TOP
#undef PROJECTILE_HEIGHT_EPSILON
