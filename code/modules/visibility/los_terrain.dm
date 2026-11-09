// Height-aware line of sight (docs/terrain-height.md#line-of-sight). On a map
// with hills, ground between the eye and a target hides the target when it
// rises above the sight line: ridges hide what lies behind them and a viewer
// on higher ground sees further down the far slope. Flat maps, and levels
// without heights, skip all of this.
//
// Heights are fixed map data, so the terrain answer for one eye position never
// changes. It is computed once per eye position (tile, half-tile offset,
// posture, view radius) and kept in a small shared cache, then each target is
// one list read. The sweep walks rings outward from the eye: each cell's
// sight-line floor comes from the two cells of the previous ring that the ray
// from the eye passes between (an interpolated horizon, like XDraw), so the
// whole view costs one pass over its cells instead of one ray per target.

// Eye height above the ground, in height levels.
#define LOS_EYE_STANDING 1.5
#define LOS_EYE_LOW 0.5
// The eye moves in steps of this many pixels inside a tile (half a tile).
// Each step refreshes the viewer, so a walker refreshes twice per tile.
#define LOS_EYE_OFFSET_QUANTUM 16
// Bare ground counts as seen when this far above it is.
#define LOS_GROUND_TOP 0.25
// Hidden ground with at most this many hidden neighbours is shown (despeckle).
#define LOS_SPECKLE_NEIGHBOURS 2
// Terrain answers kept for recent eye positions.
#define LOS_TERRAIN_CACHE_MAX 96
// A target is seen when its top reaches the sight-line floor within this much.
#define LOS_TERRAIN_EPSILON 0.001

var/global/list/los_terrain_cache = list()
var/global/datum/terrain_heights/los_terrain_cache_source = null

// The extra eye steps pause while the server is busy (world.cpu, the share of
// each tick used): presentation refreshes are the main sight cost in battles.
#define LOS_EYE_OFFSET_PAUSE_CPU 85
#define LOS_EYE_OFFSET_RESUME_CPU 60
var/global/los_eye_offsets_paused = FALSE

/proc/los_eye_offsets_allowed()
	if (los_eye_offsets_paused)
		if (world.cpu < LOS_EYE_OFFSET_RESUME_CPU)
			los_eye_offsets_paused = FALSE
	else if (world.cpu > LOS_EYE_OFFSET_PAUSE_CPU)
		los_eye_offsets_paused = TRUE
	return !los_eye_offsets_paused

// Quantized eye offset in pixels (0, 16 or 32) for one step offset; 0 (the
// tile centre) while eye steps are paused.
/proc/los_eye_quantized(step)
	if (!los_eye_offsets_allowed())
		return 0
	return round(step / LOS_EYE_OFFSET_QUANTUM + 0.5) * LOS_EYE_OFFSET_QUANTUM

/proc/los_eye_bucket(mob/M)
	if (!M)
		return null
	return "[los_eye_quantized(M.step_x)],[los_eye_quantized(M.step_y)]"

/proc/los_eye_level(mob/M)
	if (!M)
		return LOS_EYE_STANDING
	if (M.resting || M.lying || M.prone)
		return LOS_EYE_LOW
	return LOS_EYE_STANDING

// Height of an atom's top above its ground, in levels. A target is seen over
// the terrain when its top is. People and tall things show over a crest
// before the ground they stand on does.
/proc/los_target_top(atom/A)
	if (isturf(A))
		return A.opacity ? 3 : LOS_GROUND_TOP
	if (ismob(A))
		var/mob/M = A
		if (M.resting || M.lying || M.prone)
			return 0.5
		return ishuman(M) ? 1.5 : 1
	if (A.opacity)
		return root_tree_family(A) ? 5 : 3
	return A.density ? 1 : 0.5

/datum/los_terrain_field
	should_save = FALSE
	var/radius = 0
	var/side = 0
	var/eye = 0
	// TRUE when every ground cell in the view equals the eye's ground.
	var/flat = FALSE
	// Flat lists, index (i + radius) * side + (j + radius) + 1 for the cell
	// (i, j) relative to the eye tile: ground height and the lowest top height
	// a target there needs to be seen (null = always seen).
	var/list/ground
	var/list/required

/datum/los_terrain_field/proc/index(i, j)
	return (i + radius) * side + (j + radius) + 1

// TRUE when a target on the cell (i, j), whose top is top levels above its
// ground, is above the terrain's sight-line floor. Cells beyond the field have
// no terrain answer and are left to the other sight rules.
/datum/los_terrain_field/proc/visible(i, j, top)
	if (abs(i) > radius || abs(j) > radius)
		return TRUE
	var/n = index(i, j)
	var/need = required[n]
	if (isnull(need))
		return TRUE
	return ground[n] + top >= need - LOS_TERRAIN_EPSILON

// Fills the field for an eye at the tile (x, y, z) shifted by (fx, fy) tiles,
// each within half a tile. Returns FALSE for flat ground.
/datum/los_terrain_field/proc/build(datum/terrain_heights/H, x, y, z, fx, fy, eye_level, view_radius)
	radius = max(1, view_radius)
	side = radius * 2 + 1
	var/list/rows = H.rows_by_z["[z]"]
	var/maxx = H.maxx
	var/maxy = H.maxy
	ground = new /list(side * side)
	required = new /list(side * side)
	var/list/floor_h = new /list(side * side)
	var/base = 0
	if (x >= 1 && x <= maxx && y >= 1 && y <= maxy)
		base = text2ascii(rows[maxy - y + 1], x)
		base = base >= 97 ? base - 87 : base - 48
	flat = TRUE
	var/n = 1
	for (var/i = -radius, i <= radius, i++)
		var/cx = x + i
		for (var/j = -radius, j <= radius, j++)
			var/cy = y + j
			var/g = 0
			if (cx >= 1 && cx <= maxx && cy >= 1 && cy <= maxy)
				g = text2ascii(rows[maxy - cy + 1], cx)
				g = g >= 97 ? g - 87 : g - 48
			if (g != base)
				flat = FALSE
			ground[n] = g
			floor_h[n] = g
			n++
	if (flat)
		ground = null
		required = null
		return FALSE
	eye = base + eye_level
	// One pass over rings 2..radius (rings 0 and 1 are always seen). Inlined:
	// a proc call per cell doubled the cost of a fresh field.
	var/list/hidden_flag = new /list(side * side)
	var/list/hidden = list()
	for (var/k = 2, k <= radius, k++)
		var/km = k - 1
		var/top_row = 2 * k
		var/left_col = 4 * k + 1
		var/right_col = 6 * k
		for (var/c = 0, c < 8 * k, c++)
			// Walk the ring: bottom row, top row, left column, right column.
			var/i
			var/j
			if (c <= top_row)
				i = c - k
				j = -k
			else if (c <= left_col)
				i = c - top_row - 1 - k
				j = k
			else if (c <= right_col)
				i = -k
				j = c - left_col - k
			else
				i = k
				j = c - right_col - k
			// The ray from the eye to this cell crosses the previous ring's
			// column (or row) between two cells; their sight-line floor (the
			// higher of ground and their own floor), interpolated and projected
			// out from the eye, is this cell's floor.
			var/d
			var/dp
			var/cross
			var/lo
			var/a
			var/b
			if (abs(i) >= abs(j))
				var/s = i > 0 ? 1 : -1
				d = i - fx
				dp = d - s
				cross = fy + (j - fy) * dp / d
				lo = round(cross)
				var/col = (i - s + radius) * side + radius + 1
				a = floor_h[col + clamp(lo, -km, km)]
				b = floor_h[col + clamp(lo + 1, -km, km)]
			else
				var/s = j > 0 ? 1 : -1
				d = j - fy
				dp = d - s
				cross = fx + (i - fx) * dp / d
				lo = round(cross)
				var/row = j - s + radius + 1
				a = floor_h[(clamp(lo, -km, km) + radius) * side + row]
				b = floor_h[(clamp(lo + 1, -km, km) + radius) * side + row]
			var/need = eye + (a + (b - a) * (cross - lo) - eye) * d / dp
			n = (i + radius) * side + j + radius + 1
			required[n] = need
			var/g = ground[n]
			if (need > g)
				floor_h[n] = need
				if (g + LOS_GROUND_TOP < need - LOS_TERRAIN_EPSILON)
					hidden_flag[n] = TRUE
					hidden += n
	// A small dip one level below its rim hides at grazing angles and leaves
	// scattered black specks across an open slope. Ground hidden with at most
	// LOS_SPECKLE_NEIGHBOURS hidden neighbours is shown instead; real shadows
	// behind ridges are wide and keep their shape.
	var/list/clear = list()
	for (var/h in hidden)
		var/hi = round((h - 1) / side)
		var/hj = (h - 1) % side
		var/count = 0
		for (var/di = max(0, hi - 1), di <= min(side - 1, hi + 1), di++)
			for (var/dj = max(0, hj - 1), dj <= min(side - 1, hj + 1), dj++)
				if (hidden_flag[di * side + dj + 1])
					count++
		// The count includes the cell itself.
		if (count - 1 <= LOS_SPECKLE_NEIGHBOURS)
			clear += h
	for (var/h in clear)
		required[h] = ground[h]
	return TRUE

// The shared terrain answer for a body's eye, or null when the body's level
// has no heights or the ground in view is flat.
/proc/los_terrain_for(mob/body, view_radius)
	if (!body || !map || !map.terrain_height_file || !isturf(body.loc))
		return null
	var/datum/terrain_heights/H = map.terrain_heights()
	if (!H || !H.rows_by_z["[body.z]"])
		return null
	if (los_terrain_cache_source != H)
		los_terrain_cache = list()
		los_terrain_cache_source = H
	// The eye tile is the tile centre nearest the eye; the rest is (fx, fy).
	var/qx = los_eye_quantized(body.step_x)
	var/qy = los_eye_quantized(body.step_y)
	var/tile_x = body.x + round(qx / 32 + 0.5)
	var/tile_y = body.y + round(qy / 32 + 0.5)
	var/fx = body.x + qx / 32 - tile_x
	var/fy = body.y + qy / 32 - tile_y
	var/eye_level = los_eye_level(body)
	var/key = "[tile_x],[tile_y],[body.z]|[fx],[fy]|[eye_level]|[view_radius]"
	var/datum/los_terrain_field/F = los_terrain_cache[key]
	if (!F)
		F = new
		F.build(H, tile_x, tile_y, body.z, fx, fy, eye_level, view_radius)
		if (los_terrain_cache.len >= LOS_TERRAIN_CACHE_MAX)
			los_terrain_cache.Cut(1, round(LOS_TERRAIN_CACHE_MAX / 2) + 1)
		los_terrain_cache[key] = F
	if (F.flat)
		return null
	return list(F, tile_x, tile_y)

// Grading changed a tile's level: drop every cached answer (grading is rare)
// and refresh the viewers around it.
/proc/los_terrain_heights_changed(turf/T)
	los_terrain_cache = list()
	if (T)
		los_invalidate(T, TRUE)

// Height-aware sight for one target against a snapshot's terrain answer.
/proc/los_terrain_target_visible(datum/los_snapshot/S, atom/target)
	if (!S || !S.terrain || !target)
		return TRUE
	return S.terrain.visible(target.x - S.terrain_tile_x, target.y - S.terrain_tile_y, los_target_top(target))
