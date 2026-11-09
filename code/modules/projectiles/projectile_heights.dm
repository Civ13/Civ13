// Gunfire follows the hills (docs/terrain-height.md, "Gunfire"). A shot leaves
// the muzzle at the firer's height above its ground and flies in a straight
// line to the aim point above the target's ground. A ridge rising above that
// line stops it. From higher ground the line passes over people, cover and
// unroofed walls well below it, and above a roof it passes over the building.
// Flat ground keeps the old rules: a standing shot at a standing target is level.
// Muzzle and aim heights sit just under the line-of-sight eye and head tops
// (los_terrain.dm), so a target seen over a crest can be shot over it.
//
// Bullet drop: the shot is not straight but an arc that leaves the muzzle
// slightly above the aim line, crosses it again at the weapon's zero range and
// falls below it beyond. Where you click on a target sets the aim height (the
// feet at the bottom of the sprite, the head at the top), so a long shot needs
// a higher click to hold over the drop. A tile has depth: within the target's
// tile the arc covers half its slope either side of the centre, so a steep shot
// down from high ground forgives more drop than a flat one.

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
// Ground and line height over the turf handleTurf is working on, the arc's
// half rise or fall across that tile, and whether it ends in the ground there.
/obj/item/projectile/var/tmp/height_ground = 0
/obj/item/projectile/var/tmp/height_line = null
/obj/item/projectile/var/tmp/height_span = 0
/obj/item/projectile/var/tmp/height_buries = FALSE
// Drop: the arc crosses the aim line again drop_zero tiles out and falls
// drop_rate * d * (d - drop_zero) levels below it at d tiles. Rifles by default.
/obj/item/projectile/var/drop_zero = 12
/obj/item/projectile/var/drop_rate = 0.0052
/obj/item/projectile/bullet/pistol
	drop_zero = 7
	drop_rate = 0.0153
/obj/item/projectile/bullet/pellet
	drop_zero = 6
	drop_rate = 0.0208
/obj/item/projectile/arrow
	drop_zero = 5
	drop_rate = 0.03
// Round balls from smoothbores drop like shot.
/obj/item/projectile/bullet/rifle/musketball
	drop_zero = 6
	drop_rate = 0.0208
/obj/item/projectile/bullet/rifle/musketball_pistol
	drop_zero = 5
	drop_rate = 0.025

// Aim height above a mob's ground from the click's height on its sprite
// (p_y, 1 to 32 pixels; the default 16 is mid-body). The top of the sprite
// aims a little under the head's top, leaving room for the arc's rise. A body
// lying down is aimed at its middle wherever it is clicked.
/proc/projectile_click_aim(mob/M, p_y)
	if (M.lying || M.prone || M.resting)
		return 0.25
	return clamp(p_y, 1, 32) / 32 * (ishuman(M) ? 1.5 : 1) * 0.85

// The arc's height over the starting tile's ground plane at d tiles.
/obj/item/projectile/proc/height_at(d)
	return height_start + height_slope * d - drop_rate * d * (d - drop_zero)

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
	var/aim = ismob(original) ? projectile_click_aim(original, p_y) : muzzle
	var/dx = target.x - start.x
	var/dy = target.y - start.y
	height_start = H.at(start.x, start.y, start.z) + muzzle
	height_slope = (H.at(target.x, target.y, target.z) + aim - height_start) / sqrt(dx * dx + dy * dy)
	height_map = H

// Works out the arc over T for handleTurf: clear (ordinary rules, with
// height_passes_over and height_misses for what stands on T), the ground rises
// above the whole arc across the tile, or the arc passes above a roofed tile
// and everything under the roof. When the arc reaches the ground inside T,
// height_buries is set: what stands on T can still be hit, then it stops.
/obj/item/projectile/proc/height_enter(turf/T)
	height_line = null
	height_buries = FALSE
	if (isnull(height_start) || !T || !starting || T == starting || T.z != starting.z)
		return PROJECTILE_HEIGHT_CLEAR
	var/dx = T.x - starting.x
	var/dy = T.y - starting.y
	var/d = sqrt(dx * dx + dy * dy)
	var/line = height_at(d)
	height_span = abs(height_slope - drop_rate * (2 * d - drop_zero)) / 2
	height_ground = height_map.at(T.x, T.y, T.z)
	if (height_ground > line + height_span + PROJECTILE_HEIGHT_EPSILON)
		return PROJECTILE_HEIGHT_GROUND
	height_buries = height_ground > line + PROJECTILE_HEIGHT_EPSILON
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

// TRUE when the arc passes wholly above the aimed-at mob on this tile (held
// over too far). Falling short is the ground's job: height_enter.
/obj/item/projectile/proc/height_misses(mob/living/L)
	if (isnull(height_line))
		return FALSE
	return height_line - height_span > height_ground + los_target_top(L) + PROJECTILE_HEIGHT_EPSILON

#undef PROJECTILE_ROOF_TOP
#undef PROJECTILE_HEIGHT_EPSILON
