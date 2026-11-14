// Player changes to where floodwater goes (docs/river-flood.md, "Ground
// changes"). Grading a tile, or building or breaking a dirt, sandbag or stone
// half-wall, marks the 48 x 48 window around it. On the next river tick a
// priority flood inside that window, seeded from the window's edge and its
// water, works out new thresholds from today's ground, and the tiles whose
// threshold differs from the map's flood file go into a sparse override table.
// A ring of wall keeps the inside dry until the river tops its crest; a cut
// through a ridge lets the water in. Overrides are never saved: graded tiles
// and walls mark their windows again as they load.

#define FLOOD_CELL 16
#define FLOOD_WINDOW_MARGIN 16
// Windows recomputed per river tick; more wait for the next.
#define FLOOD_WINDOWS_PER_TICK 6

// Levels a finished half-wall holds the water above the ground it stands on.
/obj/structure/window/barrier
	var/flood_crest = 1

/obj/structure/window/barrier/concrete
	flood_crest = 1.5

// Stakes with gaps: the water runs through.
/obj/structure/window/barrier/palisade
	flood_crest = 0

/obj/structure/window/barrier/incomplete
	flood_crest = 0

// civ13.dme includes this file after barriers/sandbag.dm, whose New() does not call ..().
/obj/structure/window/barrier/New()
	..()
	if (flood_crest && isturf(loc))
		flood_ground_changed(loc)

/obj/structure/window/barrier/Destroy()
	if (flood_crest && isturf(loc))
		flood_ground_changed(loc)
	return ..()

/datum/river_flood
	// turf -> threshold where today's ground differs from the flood file.
	var/list/overrides = list()
	// "cell x,cell y" -> TRUE for windows waiting to be recomputed.
	var/list/dirty_windows = list()

/proc/flood_ground_changed(turf/T)
	if (!T || !map)
		return
	var/datum/river_flood/F = map.river_flood()
	if (!F || T.z != F.z_level)
		return
	F.dirty_windows["[round((T.x - 1) / FLOOD_CELL)],[round((T.y - 1) / FLOOD_CELL)]"] = TRUE

// The height floodwater must reach to stand on a tile: its ground, graded, plus
// the crest of any finished half-wall on it.
/proc/flood_tile_ground(turf/T)
	. = terrain_height_at(T)
	var/crest = 0
	for (var/obj/structure/window/barrier/B in T)
		if (B.flood_crest > crest)
			crest = B.flood_crest
	. += crest

// A tile's threshold after player changes (null for water or none).
/datum/river_flood/proc/effective_threshold(turf/T)
	if (overrides.len)
		var/o = overrides[T]
		if (!isnull(o))
			return o
	return threshold_at(T.x, T.y)

/datum/river_flood/proc/process_windows(limit = FLOOD_WINDOWS_PER_TICK)
	. = 0
	for (var/key in dirty_windows.Copy())
		if (. >= limit)
			return
		dirty_windows -= key
		var/list/parts = splittext(key, ",")
		var/gx = text2num(parts[1])
		var/gy = text2num(parts[2])
		recompute_window(max(1, gx * FLOOD_CELL + 1 - FLOOD_WINDOW_MARGIN), max(1, gy * FLOOD_CELL + 1 - FLOOD_WINDOW_MARGIN), \
			min(maxx, (gx + 1) * FLOOD_CELL + FLOOD_WINDOW_MARGIN), min(maxy, (gy + 1) * FLOOD_CELL + FLOOD_WINDOW_MARGIN))
		.++

// Priority flood inside one window. Levels come in half steps, so a bucket per
// half level serves as the priority queue.
/datum/river_flood/proc/recompute_window(x0, y0, x1, y1)
	var/w = x1 - x0 + 1
	var/h = y1 - y0 + 1
	var/list/level = new /list(w * h)
	var/list/ground = new /list(w * h)
	var/list/buckets = list()
	for (var/y in y0 to y1)
		for (var/x in x0 to x1)
			var/i = (y - y0) * w + (x - x0) + 1
			if (!reach_at(x, y))
				level[i] = -1 // sea side or no river: a wall to this flood
				continue
			var/turf/T = locate(x, y, z_level)
			var/threshold = threshold_at(x, y)
			if (isnull(threshold))
				level[i] = 0 // the river itself
				flood_bucket_push(buckets, 0, i)
				continue
			ground[i] = flood_tile_ground(T)
			// The map's own edge lets no water in; a window edge inside the map does.
			if ((x == x0 && x0 > 1) || (x == x1 && x1 < maxx) || (y == y0 && y0 > 1) || (y == y1 && y1 < maxy))
				// Water from outside the window arrives at the edge as before.
				var/edge = effective_threshold(T)
				level[i] = max(edge, ground[i])
				flood_bucket_push(buckets, level[i], i)
	var/b = 0
	while (++b <= buckets.len)
		var/list/queue = buckets[b]
		if (!queue)
			continue
		var/current = (b - 1) / 2
		var/q = 1
		while (q <= queue.len)
			var/i = queue[q++]
			var/x = (i - 1) % w
			var/y = round((i - 1) / w)
			for (var/d in 1 to 4)
				var/nx = x + (d == 2 ? 1 : (d == 4 ? -1 : 0))
				var/ny = y + (d == 1 ? 1 : (d == 3 ? -1 : 0))
				if (nx < 0 || ny < 0 || nx >= w || ny >= h)
					continue
				var/n = ny * w + nx + 1
				if (!isnull(level[n]))
					continue
				var/next = max(current, ground[n])
				level[n] = next
				if (next == current)
					queue += n
				else
					flood_bucket_push(buckets, next, n)
	for (var/y in (y0 > 1 ? y0 + 1 : y0) to (y1 < maxy ? y1 - 1 : y1))
		for (var/x in (x0 > 1 ? x0 + 1 : x0) to (x1 < maxx ? x1 - 1 : x1))
			var/i = (y - y0) * w + (x - x0) + 1
			var/value = level[i]
			if (isnull(value) || value < 0 || isnull(ground[i]))
				continue
			var/turf/T = locate(x, y, z_level)
			if (value == threshold_at(x, y))
				overrides -= T
			else
				overrides[T] = value
	flood_draw_revision++

/proc/flood_bucket_push(list/buckets, value, i)
	var/b = round(value * 2) + 1
	if (buckets.len < b)
		buckets.len = b
	var/list/queue = buckets[b]
	if (!queue)
		queue = list()
		buckets[b] = queue
	queue += i

#undef FLOOD_CELL
#undef FLOOD_WINDOW_MARGIN
#undef FLOOD_WINDOWS_PER_TICK
