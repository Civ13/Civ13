// Lobbed arrows (docs/terrain-height.md, "Lobbed arrows"). A bow set to lob
// sends the arrow up in a high arc that comes down on the clicked tile instead
// of flying straight at it. On the way it passes over people, cover, walls and
// roofs; only a hillside rising above the arc stops it. Where it comes down it
// can hit someone standing there (the aimed-at person first), lands on a roof
// if the tile is roofed, and otherwise sticks in the ground. A lob is slower
// than a direct shot and lands less precisely: the landing tile scatters
// around the aim point, more with distance and with an unsteady aim.

// The arc rises this many levels over the straight line from bow to landing
// point at its middle, plus LOB_APEX_PER_TILE for every tile of distance.
#define LOB_APEX_BASE 3
#define LOB_APEX_PER_TILE 0.5
// The arc comes down this high over the landing tile's ground.
#define LOB_LAND_HEIGHT 0.5
// Flight time in deciseconds: LOB_FLIGHT_BASE plus LOB_FLIGHT_PER_TILE per tile.
#define LOB_FLIGHT_BASE 3
#define LOB_FLIGHT_PER_TILE 0.6

/obj/item/projectile/var/tmp/lobbed = FALSE
/obj/item/projectile/var/tmp/turf/lob_landing = null
/obj/item/projectile/var/tmp/atom/lob_aimed = null
/obj/item/projectile/var/tmp/lob_distance = 0
/obj/item/projectile/var/tmp/lob_steps = 0
/obj/item/projectile/var/tmp/lob_apex = 0
/obj/item/projectile/var/tmp/lob_start_height = 0
/obj/item/projectile/var/tmp/lob_land_height = 0
/obj/item/projectile/var/tmp/datum/terrain_heights/lob_heights = null
/obj/item/projectile/var/tmp/lob_launch_time = 0
/obj/item/projectile/var/tmp/lob_flight_time = 0
// Chance to hit the aimed-at person on the landing tile; others there get 60% of it.
/obj/item/projectile/var/tmp/lob_hit_chance = 70

// Standard deviation of the landing point, in tiles, for a lob of distance
// tiles fired with the bow's dispersion for this shot.
/proc/lob_scatter(distance, dispersion)
	return 0.25 + distance * 0.08 + abs(dispersion) / 25

// Roughly normal random offset with standard deviation sd (sum of four uniforms).
/proc/lob_random_offset(sd)
	return round((rand() + rand() + rand() + rand() - 2) * 1.732 * sd, 1)

// Ground height under T on a hill map, or 0 without heights.
/obj/item/projectile/proc/lob_ground(turf/T)
	if (!lob_heights || !T)
		return 0
	return lob_heights.at(T.x, T.y, T.z)

// Turns this launched projectile into a lob at target, scattering the landing
// tile by spread tiles (standard deviation). Returns FALSE if it cannot lob.
/obj/item/projectile/proc/lob_plan(atom/target, spread = 0)
	var/turf/aim = get_turf(target)
	if (!starting || !aim || aim.z != starting.z)
		return FALSE
	var/lx = clamp(aim.x + lob_random_offset(spread), 1, world.maxx)
	var/ly = clamp(aim.y + lob_random_offset(spread), 1, world.maxy)
	var/turf/landing = locate(lx, ly, aim.z)
	if (!landing || landing == starting)
		landing = aim
	if (landing == starting)
		return FALSE
	lob_landing = landing
	lob_aimed = ismob(target) ? target : null
	original = landing
	dispersion = 0 // the scatter is in the landing tile; fly straight to it
	var/dx = landing.x - starting.x
	var/dy = landing.y - starting.y
	lob_distance = sqrt(dx * dx + dy * dy)
	lob_steps = max(abs(dx), abs(dy))
	lob_apex = LOB_APEX_BASE + lob_distance * LOB_APEX_PER_TILE
	lob_heights = null
	if (map && map.terrain_height_file)
		var/datum/terrain_heights/H = map.terrain_heights()
		if (H && H.rows_by_z["[starting.z]"])
			lob_heights = H
	lob_start_height = lob_ground(starting) + PROJECTILE_MUZZLE_STANDING
	lob_land_height = lob_ground(landing) + LOB_LAND_HEIGHT
	lob_flight_time = LOB_FLIGHT_BASE + lob_distance * LOB_FLIGHT_PER_TILE
	lob_launch_time = world.time
	kill_count = max(kill_count, lob_steps + 3)
	height_start = null // the direct-fire height line does not apply
	lobbed = TRUE
	return TRUE

// Absolute height of the arc d tiles from the start.
/obj/item/projectile/proc/lob_height_at(d)
	var/f = lob_distance ? clamp(d / lob_distance, 0, 1) : 1
	return lob_start_height + (lob_land_height - lob_start_height) * f + 4 * lob_apex * f * (1 - f)

// TRUE once enough of the flight time has passed for the next tile.
/obj/item/projectile/proc/lob_ready()
	if (!lob_flight_time)
		return TRUE
	return permutated.len < 1 + lob_steps * (world.time - lob_launch_time) / lob_flight_time

// handleTurf for a lob: fly over T, strike a hillside rising above the arc, or
// come down on the landing tile.
/obj/item/projectile/proc/lob_enter(turf/T)
	if (T == starting)
		forceMove(T)
		permutated += T
		return TRUE
	var/dx = T.x - starting.x
	var/dy = T.y - starting.y
	var/d = sqrt(dx * dx + dy * dy)
	var/landing = T == lob_landing || d >= lob_distance
	if (lob_heights && lob_ground(T) > (landing ? lob_land_height : lob_height_at(d)))
		T.visible_message(SPAN_WARNING("\The [name] strikes the hillside."))
		return lob_stop(T)
	if (landing)
		return lob_land(T)
	forceMove(T)
	permutated += T
	return TRUE

/obj/item/projectile/proc/lob_stop(turf/T)
	bumped = TRUE
	loc = null
	on_impact(T)
	qdel(src)
	return FALSE

// Where an arrow coming down from above strikes someone.
/proc/lob_hit_zone()
	return pickweight(list("head" = 3, "chest" = 4, "l_arm" = 2, "r_arm" = 2, "groin" = 1, "l_leg" = 1, "r_leg" = 1))

/obj/item/projectile/proc/lob_land(turf/T)
	forceMove(T)
	permutated += T
	if (los_turf_roofed(T))
		T.visible_message(SPAN_WARNING("\The [name] clatters onto the roof."))
		return lob_stop(T)
	if (T.density)
		T.visible_message(SPAN_WARNING("\The [name] strikes \the [T]."))
		return lob_stop(T)
	var/list/targets = list()
	if (isliving(lob_aimed) && lob_aimed.loc == T)
		targets += lob_aimed
	for (var/mob/living/L in T)
		if (!(L in targets))
			targets += L
	var/firer_dist = firer ? get_dist(firer, T) : 0
	for (var/mob/living/L in targets)
		if (L == firer || is_firer_mount(L))
			continue
		if (!prob(L == lob_aimed ? lob_hit_chance : lob_hit_chance * 0.6))
			continue
		def_zone = lob_hit_zone()
		// Distance 1: the zone was already rolled; attack_mob only applies it.
		if (attack_mob(L, 1))
			bumped = TRUE
			loc = null
			on_impact(L, FALSE)
			qdel(src)
			return FALSE
	if (firer_dist)
		T.visible_message(SPAN_WARNING("\The [name] drops out of the sky and sticks in the ground."))
	return lob_stop(T)

// The arrow grows and rises toward the top of its arc and shrinks as it falls.
/obj/item/projectile/proc/lob_update_icon()
	var/f = lob_steps ? clamp(permutated.len / lob_steps, 0, 1) : 1
	var/rise = sin(180 * f)
	pixel_y += round(20 * rise, 1)
	var/matrix/M = matrix()
	M.Scale(1 + 0.5 * rise)
	M.Turn(-(angle + 90))
	transform = M

#undef LOB_APEX_BASE
#undef LOB_APEX_PER_TILE
#undef LOB_LAND_HEIGHT
#undef LOB_FLIGHT_BASE
#undef LOB_FLIGHT_PER_TILE
