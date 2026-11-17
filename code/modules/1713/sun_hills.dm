// Hills lit by the sun (docs/sun-and-shadows.md). On maps with both a sun
// (sun_shadows.dm) and a height file (terrain_height.dm), the slope shading is
// lit from the sun's direction instead of the fixed north-west, and higher
// ground casts shadows away from the sun: long when it is low, short when it is
// high. Both reuse the baked slope sprites (icons/turf/terrain_shade.dmi): a
// corner in cast shadow takes a dark light level and the Gouraud blend between
// corners softens the edge.
//
// Cost: one sun's corner lights for a 500x350 map take a few seconds of CPU, so
// they are worked out in the background while the previous phase is showing and
// cached as row strings (a few hundred KB each; at most SUN_HILL_TABLES kept per
// z-level). A phase change then re-shades the tiles around players at once and
// the rest of the map in small batches. Player grading patches only the strip of
// corners whose shadow the graded tile can change.
//
// At night the hills keep the last sun, unseen in the dark, until morning.

// One height level is this many tiles tall when shadows are cast.
#define SUN_LEVEL_TILES 1
// No shadow reaches further than this many tiles.
#define SUN_SHADOW_RANGE 24
// Same as terrain_height.dm (undefined there), so lights match the baked sprites.
#define SUN_RELIEF 1.6
#define SUN_LIGHT_STEP 0.22
// Tables of corner lights kept per z-level (the current sun and the next).
#define SUN_HILL_TABLES 3
// Tiles around each player re-shaded first on a phase change.
#define SUN_HILL_NEAR 20
// Tiles re-shaded per background batch before yielding a tick.
#define SUN_HILL_BATCH 400

// The sun the hills show now, list(azimuth, elevation) or null for the fixed
// north-west light (before the first sunny phase, and on maps without a sun).
var/global/list/sun_hill_angles = null
// Bumped by every phase change; an older pass stops when it sees a newer one.
var/global/sun_hill_serial = 0
// TRUE while a pass is re-shading.
var/global/sun_hills_busy = FALSE

// "z|azimuth|elevation" -> list of (maxy + 1) strings of (maxx + 1) light chars a-e.
/datum/terrain_heights/var/list/sun_rows_by_key = list()

/proc/sun_hill_key(z, list/angles)
	return "[z]|[angles[1]]|[angles[2]]"

// The corner lights for the hills' current sun on z, or null for the fixed light.
/datum/terrain_heights/proc/sun_hill_rows(z)
	return sun_hill_angles ? sun_rows_by_key[sun_hill_key(z, sun_hill_angles)] : null

// One corner's light under a sun. corner_level() reads the graded heights.
// march: the sun's step per tile (east +, south +) and the levels its ray
// climbs per tile; top: the highest corner on the map.
/datum/terrain_heights/proc/sun_corner_char(list/rows, cy, cx, list/angles, top)
	var/h0 = corner_level(rows, cy, cx)
	var/el = angles[2]
	var/east = sin(angles[1])
	var/south = -cos(angles[1])
	var/rise = tan(el) / SUN_LEVEL_TILES
	// Cast shadow: march toward the sun until the ray clears the highest ground.
	var/reach = min(SUN_SHADOW_RANGE, ceil((top - h0) / rise))
	for (var/k in 1 to reach)
		var/px = round(cx + k * east, 1)
		var/py = round(cy + k * south, 1)
		if (px < 0 || px > maxx || py < 0 || py > maxy)
			break
		if (corner_level(rows, py, px) - h0 > k * rise)
			return "a"
	var/gx = (corner_level(rows, cy, min(cx + 1, maxx)) - corner_level(rows, cy, max(cx - 1, 0))) / 2
	var/gy = (corner_level(rows, min(cy + 1, maxy), cx) - corner_level(rows, max(cy - 1, 0), cx)) / 2
	var/nx = -gx * SUN_RELIEF
	var/ny = -gy * SUN_RELIEF
	var/light_z = sin(el)
	var/intensity = (nx * east * cos(el) + ny * south * cos(el) + light_z) / sqrt(nx * nx + ny * ny + 1) - light_z
	return ascii2text(99 + clamp(floor(intensity / SUN_LIGHT_STEP + 0.5), -2, 2))

// The highest corner of z (heights only rise by grading, so callers refresh it).
/datum/terrain_heights/proc/sun_top(z)
	var/list/rows = rows_by_z["[z]"]
	. = 0
	for (var/row in rows)
		for (var/i in 1 to length(row))
			var/level = terrain_height_levels[text2ascii(row, i)]
			if (level > .)
				. = level

// Works out (or returns the cached) corner lights for a sun on z. Yields.
/datum/terrain_heights/proc/sun_light_rows(z, list/angles)
	var/key = sun_hill_key(z, angles)
	if (sun_rows_by_key[key])
		return sun_rows_by_key[key]
	var/list/rows = rows_by_z["[z]"]
	if (!rows || !angles)
		return null
	var/width = maxx + 1
	// Corner heights once, so the march reads a flat list instead of four rows.
	var/list/corner = new /list(width * (maxy + 1))
	var/top = 0
	for (var/cy in 0 to maxy)
		for (var/cx in 0 to maxx)
			var/h = corner_level(rows, cy, cx)
			corner[cy * width + cx + 1] = h
			if (h > top)
				top = h
		CHECK_TICK
	var/el = angles[2]
	var/east = sin(angles[1])
	var/south = -cos(angles[1])
	var/light_x = east * cos(el)
	var/light_y = south * cos(el)
	var/light_z = sin(el)
	var/rise = tan(el) / SUN_LEVEL_TILES
	var/list/out = list()
	for (var/cy in 0 to maxy)
		var/list/chars = list()
		for (var/cx in 0 to maxx)
			var/h0 = corner[cy * width + cx + 1]
			var/shadow = FALSE
			var/reach = min(SUN_SHADOW_RANGE, ceil((top - h0) / rise))
			for (var/k in 1 to reach)
				var/px = round(cx + k * east, 1)
				var/py = round(cy + k * south, 1)
				if (px < 0 || px > maxx || py < 0 || py > maxy)
					break
				if (corner[py * width + px + 1] - h0 > k * rise)
					shadow = TRUE
					break
			if (shadow)
				chars += "a"
				continue
			var/gx = (corner[cy * width + min(cx + 1, maxx) + 1] - corner[cy * width + max(cx - 1, 0) + 1]) / 2
			var/gy = (corner[min(cy + 1, maxy) * width + cx + 1] - corner[max(cy - 1, 0) * width + cx + 1]) / 2
			var/nx = -gx * SUN_RELIEF
			var/ny = -gy * SUN_RELIEF
			var/intensity = (nx * light_x + ny * light_y + light_z) / sqrt(nx * nx + ny * ny + 1) - light_z
			chars += ascii2text(99 + clamp(floor(intensity / SUN_LIGHT_STEP + 0.5), -2, 2))
		out += jointext(chars, "")
		CHECK_TICK
	// Another pass may have finished the same sun while this one yielded.
	if (sun_rows_by_key[key])
		return sun_rows_by_key[key]
	sun_rows_by_key[key] = out
	sun_hill_prune(z)
	return out

// Keeps the hills' current sun and the newest others, at most SUN_HILL_TABLES per z.
/datum/terrain_heights/proc/sun_hill_prune(z)
	var/prefix = "[z]|"
	var/list/mine = list()
	for (var/key in sun_rows_by_key)
		if (findtext(key, prefix) == 1)
			mine += key
	var/keep_current = sun_hill_angles ? sun_hill_key(z, sun_hill_angles) : null
	var/i = 1
	while (mine.len > SUN_HILL_TABLES && i <= mine.len)
		var/key = mine[i]
		if (key == keep_current)
			i++
			continue
		sun_rows_by_key -= key
		mine.Cut(i, i + 1)

// A graded tile changes the corners around it and the shadows it casts: redo,
// in every cached sun, the corners whose light can depend on it, and re-shade
// the tiles whose sprite changed. Called from set_level.
/datum/terrain_heights/proc/sun_heights_changed(x, y, z)
	var/prefix = "[z]|"
	var/r = maxy - y + 1
	var/list/rows = rows_by_z["[z]"]
	var/top = null
	for (var/key in sun_rows_by_key)
		if (findtext(key, prefix) != 1)
			continue
		var/list/parts = splittext(key, "|")
		var/list/angles = list(text2num(parts[2]), text2num(parts[3]))
		if (isnull(top))
			top = sun_top(z)
		// The tile's own corners and their neighbours (slope), and every corner
		// up to SUN_SHADOW_RANGE tiles away from the sun (cast shadow).
		var/far_x = round(-SUN_SHADOW_RANGE * sin(angles[1]), 1)
		var/far_y = round(SUN_SHADOW_RANGE * cos(angles[1]), 1)
		var/cx1 = max(0, x - 3 + min(0, far_x))
		var/cx2 = min(maxx, x + 2 + max(0, far_x))
		var/cy1 = max(0, r - 3 + min(0, far_y))
		var/cy2 = min(maxy, r + 2 + max(0, far_y))
		var/list/lights = sun_rows_by_key[key]
		for (var/cy in cy1 to cy2)
			var/list/chars = list()
			for (var/cx in cx1 to cx2)
				chars += sun_corner_char(rows, cy, cx, angles, top)
			var/old = lights[cy + 1]
			lights[cy + 1] = copytext(old, 1, cx1 + 1) + jointext(chars, "") + copytext(old, cx2 + 2)
		if (sun_hill_angles && sun_same_angles(angles, sun_hill_angles) && terrain_shading_applied)
			// Tile (tx, ty) reads corner rows ty..ty+1 (north first) and columns tx-1..tx.
			sun_hills_reshade_box(z, cx1, maxy - cy2, cx2 + 1, maxy - cy1 + 1)

// Re-shades a box of tiles for the hills' current sun. Returns tiles changed.
/proc/sun_hills_reshade_box(z, x1, y1, x2, y2, serial = 0)
	var/datum/terrain_heights/H = map ? map.terrain_heights() : null
	if (!H)
		return 0
	. = 0
	var/work = 0
	for (var/y in max(1, y1) to min(H.maxy, y2))
		for (var/x in max(1, x1) to min(H.maxx, x2))
			if (serial && serial != sun_hill_serial)
				return
			var/turf/T = locate(x, y, z)
			if (!T || istype(T, /turf/floor/beach/water) || T.terrain_smoothed())
				continue
			var/key = H.shade_key(x, y, z)
			var/image/shade = (key && key != "cccc") ? terrain_shade_image(key, T.terrain_shade_snowy()) : null
			if (shade != T.terrain_shade_overlay)
				T.terrain_shade_set(shade, T.terrain_terrace_overlay)
				.++
			if (serial && ++work >= SUN_HILL_BATCH)
				work = 0
				sleep(world.tick_lag)

// The hills follow a new sun: work out its lights if they are not ready, show
// them around players at once, then across the rest of the map in batches, and
// start on the next phase's sun. Called from sun_shadows_phase.
/proc/sun_hills_phase(list/angles, next_tod)
	set waitfor = FALSE
	if (!angles || sun_same_angles(angles, sun_hill_angles) || !map || !map.terrain_height_file)
		return
	var/datum/terrain_heights/H = map.terrain_heights()
	if (!H || !terrain_shading_applied)
		return
	var/serial = ++sun_hill_serial
	sun_hills_busy = TRUE
	for (var/zkey in H.rows_by_z)
		H.sun_light_rows(text2num(zkey), angles)
		if (serial != sun_hill_serial)
			return
	sun_hill_angles = angles
	for (var/zkey in H.rows_by_z)
		var/z = text2num(zkey)
		for (var/client/C in clients)
			var/turf/eye = get_turf(C.eye || C.mob)
			if (eye && eye.z == z)
				sun_hills_reshade_box(z, eye.x - SUN_HILL_NEAR, eye.y - SUN_HILL_NEAR, eye.x + SUN_HILL_NEAR, eye.y + SUN_HILL_NEAR, serial)
		sun_hills_reshade_box(z, 1, 1, H.maxx, H.maxy, serial)
		if (serial != sun_hill_serial)
			return
	sun_hills_busy = FALSE
	// Ready the next sun while this one shows.
	var/list/next = next_tod ? sun_angles(next_tod) : null
	if (next)
		for (var/zkey in H.rows_by_z)
			H.sun_light_rows(text2num(zkey), next)

#undef SUN_LEVEL_TILES
#undef SUN_SHADOW_RANGE
#undef SUN_RELIEF
#undef SUN_LIGHT_STEP
#undef SUN_HILL_TABLES
#undef SUN_HILL_NEAR
#undef SUN_HILL_BATCH
