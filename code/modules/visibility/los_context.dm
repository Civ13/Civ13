// Per-client geometric visibility. Snapshots are synchronous presentation inputs,
// never reusable authorization leases for gameplay actions.
#ifndef CIV13_GEOMETRIC_LOS_CORE
#define CIV13_GEOMETRIC_LOS_CORE 1
#endif
#ifndef CIV13_ROOT_TREE_PRESENTATION
#define CIV13_ROOT_TREE_PRESENTATION 1
#endif
#define LOS_DENY 0
#define LOS_WORLD 1
#define LOS_SURFACE 2
#define LOS_OWN_SLOT 3
#define LOS_SELF 4

/client/var/tmp/datum/los_context/los_context
var/global/list/los_active_contexts

// These primitives receive bounded eye-relative coordinates, including native
// 2px movement fractions. Closed contact blocks; no epsilon opens a corner crack.
/proc/los_axis_separates(nx, ny, ex, ey, ax, ay, bx, by, cx, cy)
	var/p = nx * ex + ny * ey
	var/q = nx * ax + ny * ay
	var/r = nx * bx + ny * by
	var/center = nx * cx + ny * cy
	var/radius = (abs(nx) + abs(ny)) * 0.5
	return max(p, q, r) < center - radius || center + radius < min(p, q, r)

/proc/los_triangle_hits_cell(ex, ey, ax, ay, bx, by, cx, cy)
	if (los_axis_separates(1, 0, ex, ey, ax, ay, bx, by, cx, cy))
		return FALSE
	if (los_axis_separates(0, 1, ex, ey, ax, ay, bx, by, cx, cy))
		return FALSE
	if (los_axis_separates(ey - ay, ax - ex, ex, ey, ax, ay, bx, by, cx, cy))
		return FALSE
	if (los_axis_separates(ay - by, bx - ax, ex, ey, ax, ay, bx, by, cx, cy))
		return FALSE
	if (los_axis_separates(by - ey, ex - bx, ex, ey, ax, ay, bx, by, cx, cy))
		return FALSE
	return TRUE

// SAT for conv(eye, target square) against the closed unit blocker square.
// Projection onto an arbitrary axis is the union of the eye projection and
// target-square interval. Normals to eye->all four corners contain both hull
// silhouette edges; x/y contain square hull edges and blocker square edges.
// Extra (non-hull) axes cannot separate intersecting convex sets.
/proc/los_hull_axis_separates(nx, ny, ex, ey, tx, ty, half_size, cx, cy)
	var/eye = nx * ex + ny * ey
	var/target = nx * tx + ny * ty
	var/extent = abs(nx) + abs(ny)
	var/target_radius = extent * half_size
	var/cell = nx * cx + ny * cy
	var/cell_radius = extent * 0.5
	return max(eye, target + target_radius) < cell - cell_radius || cell + cell_radius < min(eye, target - target_radius)

/proc/los_footprint_hits_cell(ex, ey, tx, ty, half_size, cx, cy)
	// Exact x/y SAT; strict inequalities preserve edge and corner contact.
	if (max(ex, tx+half_size) < cx-0.5 || min(ex, tx-half_size) > cx+0.5 || max(ey, ty+half_size) < cy-0.5 || min(ey, ty-half_size) > cy+0.5)
		return FALSE
	if (los_hull_axis_separates(ey-ty+half_size, tx-half_size-ex, ex, ey, tx, ty, half_size, cx, cy))
		return FALSE
	// A zero-size footprint is the eye-target segment: all four normals
	// coincide, so the first normal plus x/y completes its SAT.
	if (!half_size)
		return TRUE
	if (los_hull_axis_separates(ey-ty+half_size, tx+half_size-ex, ex, ey, tx, ty, half_size, cx, cy))
		return FALSE
	if (los_hull_axis_separates(ey-ty-half_size, tx+half_size-ex, ex, ey, tx, ty, half_size, cx, cy))
		return FALSE
	if (los_hull_axis_separates(ey-ty-half_size, tx-half_size-ex, ex, ey, tx, ty, half_size, cx, cy))
		return FALSE
	return TRUE

// Co-located world roots share the tile's visibility, including offset objects
// and multiple opaque owners. Native tile identity is separate from fractional
// geometry; blockers on OTHER tiles still occlude the target normally.
/proc/los_target_blocked(tx, ty, cx, cy, target_tile_x, target_tile_y, blocker_tile_x, blocker_tile_y, opaque_target)
	if (target_tile_x == blocker_tile_x && target_tile_y == blocker_tile_y)
		return FALSE
	if (opaque_target)
		if (los_footprint_hits_cell(0, 0, tx, ty, 0, cx, cy))
			return TRUE
		return FALSE
	return los_footprint_hits_cell(0, 0, tx, ty, 0.25, cx, cy)

// BYOND's one-argument round is floor, including negative fractional values.
// Expand the eye/footprint hull by the blocker's half-cell extent. Inclusive
// bin bounds retain edge/corner contact, not just centers inside the hull.
/proc/los_bucket_index(coordinate)
	return round(coordinate / 4)

/proc/los_bucket_lower(target_coordinate, half_size)
	return los_bucket_index(min(0, target_coordinate-half_size) - 0.5)

/proc/los_bucket_upper(target_coordinate, half_size)
	return los_bucket_index(max(0, target_coordinate+half_size) + 0.5)

// Rational slab intervals [low numerator, high numerator, positive denominator].
/proc/los_ray_axis(e, t, c)
	var/d = 2 * (t - e)
	if (!d)
		if (2*e < 2*c-1 || 2*e > 2*c+1)
			return null
		return list(-1, 2, 1)
	if (d > 0)
		return list(2*c-1-2*e, 2*c+1-2*e, d)
	return list(2*e-2*c-1, 2*e-2*c+1, -d)

/proc/los_ray_entry(ex, ey, tx, ty, cx, cy)
	var/list/u = los_ray_axis(ex, tx, cx)
	var/list/v = los_ray_axis(ey, ty, cy)
	if (!u || !v)
		return null
	var/lo_n = 0
	var/lo_d = 1
	var/hi_n = 1
	var/hi_d = 1
	if (u[1]*lo_d > lo_n*u[3])
		lo_n = u[1]
		lo_d = u[3]
	if (v[1]*lo_d > lo_n*v[3])
		lo_n = v[1]
		lo_d = v[3]
	if (u[2]*hi_d < hi_n*u[3])
		hi_n = u[2]
		hi_d = u[3]
	if (v[2]*hi_d < hi_n*v[3])
		hi_n = v[2]
		hi_d = v[3]
	if (lo_n*hi_d > hi_n*lo_d)
		return null
	return list(lo_n, lo_d)

/datum/los_cell
	should_save = FALSE
	var/cell_x
	var/cell_y
	var/tile_x
	var/tile_y
	var/atom/surface_owner
	var/owners = 0
	// Absolute top height on maps with hills (los_terrain.dm); null blocks
	// from any height.
	var/top

/datum/los_tree_bounds
	should_save = FALSE
	var/root_x
	var/root_y
	var/root_z
	var/step_x
	var/step_y
	var/bound_x
	var/bound_y
	var/bound_width
	var/bound_height
	var/left
	var/right
	var/bottom
	var/top
	var/list/cells

/datum/los_surface_cell
	should_save = FALSE
	var/cell_x
	var/cell_y
	var/half_x
	var/half_y

/datum/los_snapshot
	var/presentation = FALSE
	should_save = FALSE
	var/revision
	var/policy
	var/eye_x
	var/eye_y
	var/eye_z
	var/radius_x
	var/radius_y
	var/list/blockers = list()
	var/list/blocker_bins
	// Derived per capture by index_blockers(): static blockers by tile.
	var/list/blocker_grid
	var/list/loose_blockers
	var/grid_frac_x = 0
	var/grid_frac_y = 0
	var/grid_min_x = 0
	var/grid_min_y = 0
	var/grid_height = 0
	var/grid_size = 0
	var/list/clear_footprints = list()
	var/list/tree_bounds
	var/list/blocking_tiles
	// Height-aware terrain answer (los_terrain.dm), null on flat ground, and
	// the absolute tile its cells are relative to.
	var/datum/los_terrain_field/terrain
	var/terrain_tile_x = 0
	var/terrain_tile_y = 0
	// TRUE when some blocker's top is below the eye, so height can matter;
	// the eye's absolute height; the current query target's top (null: no
	// seeing over blockers for this query).
	var/see_over = FALSE
	var/eye_top = 0
	var/query_top

// The flat list remains authoritative and is retained for sparse scenes and
// snapshot fixtures. The grid is derived once per fresh capture, never shared.
// Static blockers sit on whole tiles, so one grid slot per tile holds them;
// blockers with a step offset, and any second cell on one tile, stay in the
// small loose list that every query scans in full.
/datum/los_snapshot/proc/index_blockers()
	blocker_bins = null
	blocking_tiles = null
	blocker_grid = null
	loose_blockers = null
	if(blockers.len <= 16)
		return
	grid_frac_x = eye_x - round(eye_x)
	grid_frac_y = eye_y - round(eye_y)
	grid_min_x = round(-radius_x - 2)
	grid_min_y = round(-radius_y - 2)
	grid_height = round(radius_y + 2) - grid_min_y + 1
	var/grid_width = round(radius_x + 2) - grid_min_x + 1
	blocker_grid = new /list(grid_width * grid_height)
	grid_size = blocker_grid.len
	loose_blockers = list()
	for(var/datum/los_cell/B in blockers)
		var/kx = round(B.cell_x + grid_frac_x + 0.5)
		var/ky = round(B.cell_y + grid_frac_y + 0.5)
		var/slot = (kx - grid_min_x) * grid_height + (ky - grid_min_y) + 1
		if(B.cell_x != B.tile_x || B.cell_y != B.tile_y || abs(B.cell_x + grid_frac_x - kx) > 0.001 || abs(B.cell_y + grid_frac_y - ky) > 0.001 || ky < grid_min_y || ky >= grid_min_y + grid_height || slot < 1 || slot > grid_size || blocker_grid[slot])
			loose_blockers += B
			continue
		blocker_grid[slot] = B

// Spatial bins for the tree surface pass, built only when a tree asks.
/datum/los_snapshot/proc/ensure_blocker_bins()
	if(blocker_bins || blockers.len <= 16)
		return blocker_bins
	blocker_bins = list()
	for(var/datum/los_cell/B in blockers)
		var/bin_key = "[los_bucket_index(B.cell_x)],[los_bucket_index(B.cell_y)]"
		var/list/bin = blocker_bins[bin_key]
		if(!bin)
			bin = list()
			blocker_bins[bin_key] = bin
		bin += B
	return blocker_bins

// Index-wise equality of the captured blocking geometry. capture() walks the
// viewport in one fixed order, so two captures of an unchanged scene produce
// the same blockers in the same order. Fresh cells are compared by value; no
// cell, bin or footprint cache is shared between the two snapshots.
/datum/los_snapshot/proc/same_geometry(datum/los_snapshot/other)
	if (!other || other.presentation != presentation || other.eye_x != eye_x || other.eye_y != eye_y || other.eye_z != eye_z || other.radius_x != radius_x || other.radius_y != radius_y)
		return FALSE
	if (blockers.len != other.blockers.len)
		return FALSE
	for (var/i = 1, i <= blockers.len, i++)
		var/datum/los_cell/A = blockers[i]
		var/datum/los_cell/B = other.blockers[i]
		if (!A || !B || A.tile_x != B.tile_x || A.tile_y != B.tile_y || A.cell_x != B.cell_x || A.cell_y != B.cell_y || A.surface_owner != B.surface_owner || A.owners != B.owners)
			return FALSE
	if (length(tree_bounds) != length(other.tree_bounds))
		return FALSE
	for (var/root in tree_bounds)
		var/datum/los_tree_bounds/R = tree_bounds[root]
		var/datum/los_tree_bounds/O = other.tree_bounds ? other.tree_bounds[root] : null
		if (!R || !O || R.root_x != O.root_x || R.root_y != O.root_y || R.root_z != O.root_z || R.step_x != O.step_x || R.step_y != O.step_y || R.bound_x != O.bound_x || R.bound_y != O.bound_y || R.bound_width != O.bound_width || R.bound_height != O.bound_height)
			return FALSE
	return TRUE

// True when one of the eight neighbours of this eye-relative native tile is
// open (holds no blocker) and its own quarter footprint is visible.
/datum/los_snapshot/proc/opaque_borders_visible(target_tile_x, target_tile_y)
	if (!blocking_tiles)
		blocking_tiles = list()
		for (var/datum/los_cell/B in blockers)
			blocking_tiles["[B.tile_x],[B.tile_y]"] = TRUE
	for (var/dx = -1, dx <= 1, dx++)
		for (var/dy = -1, dy <= 1, dy++)
			if (!dx && !dy)
				continue
			var/nx = target_tile_x + dx
			var/ny = target_tile_y + dy
			if (abs(nx) > radius_x + 0.5 || abs(ny) > radius_y + 0.5 || blocking_tiles["[nx],[ny]"])
				continue
			var/neighbour_key = "0|[nx],[ny]|[nx],[ny]"
			var/neighbour = clear_footprints[neighbour_key]
			if (isnull(neighbour))
				neighbour = LOS_WORLD
				if (blocks_target(nx, ny, nx, ny, FALSE))
					neighbour = LOS_DENY
				clear_footprints[neighbour_key] = neighbour
			if (neighbour != LOS_DENY)
				return TRUE
	return FALSE

// The exact test below decides; the grid walk only picks candidates. The
// footprint hull is every s * p for s in 0..1 and p in the target square, so
// along the major axis each unit slab [a, b] holds hull points only with
// minor coordinates between a and b times the square's extreme slopes,
// clamped to the hull's bounding box. Every blocker square touching that
// range is tested, a superset of the blockers the hull can reach, in a few
// grid reads per tile of distance instead of every blocker in the bounding
// box (about 20 exact tests per query on an indoor map).
/datum/los_snapshot/proc/blocks_target(tx, ty, target_tile_x, target_tile_y, opaque_target)
	if(!blocker_grid)
		for(var/datum/los_cell/B in blockers)
			if(los_target_blocked(tx, ty, B.cell_x, B.cell_y, target_tile_x, target_tile_y, B.tile_x, B.tile_y, opaque_target) && !los_height_clears(src, B, tx, ty))
				return TRUE
		return FALSE
	for(var/datum/los_cell/B in loose_blockers)
		if(los_target_blocked(tx, ty, B.cell_x, B.cell_y, target_tile_x, target_tile_y, B.tile_x, B.tile_y, opaque_target) && !los_height_clears(src, B, tx, ty))
			return TRUE
	var/half_size = opaque_target ? 0 : 0.25
	var/x_major = abs(tx) >= abs(ty)
	// Major (u) and minor (v) axes of this query.
	var/tu = x_major ? tx : ty
	var/tv = x_major ? ty : tx
	var/frac_u = x_major ? grid_frac_x : grid_frac_y
	var/frac_v = x_major ? grid_frac_y : grid_frac_x
	var/v_low = min(0, tv - half_size)
	var/v_high = max(0, tv + half_size)
	var/slope_known = abs(tu) > half_size
	var/slope_low = 0
	var/slope_high = 0
	if(slope_known)
		var/s1 = (tv - half_size) / (tu - half_size)
		var/s2 = (tv + half_size) / (tu - half_size)
		var/s3 = (tv - half_size) / (tu + half_size)
		var/s4 = (tv + half_size) / (tu + half_size)
		slope_low = min(s1, s2, s3, s4)
		slope_high = max(s1, s2, s3, s4)
	// Cell keys k hold centres at k - frac; widen by a hair against rounding.
	// A grid slot is base + kv * stride for the column (or row) ku.
	var/ku_low = -round(-(min(0, tu - half_size) - 0.5 + frac_u - 0.001))
	var/ku_high = round(max(0, tu + half_size) + 0.5 + frac_u + 0.001)
	var/grid_width = grid_size / grid_height
	var/u_min = x_major ? grid_min_x : grid_min_y
	var/v_min = x_major ? grid_min_y : grid_min_x
	var/u_count = x_major ? grid_width : grid_height
	var/v_count = x_major ? grid_height : grid_width
	var/stride = x_major ? 1 : grid_height
	var/u_stride = x_major ? grid_height : 1
	ku_low = max(ku_low, u_min)
	ku_high = min(ku_high, u_min + u_count - 1)
	for(var/ku = ku_low, ku <= ku_high, ku++)
		var/slab_low = ku - frac_u - 0.5
		var/slab_high = slab_low + 1
		var/row_low = v_low
		var/row_high = v_high
		if(slope_known)
			row_low = max(v_low, min(slab_low * slope_low, slab_low * slope_high, slab_high * slope_low, slab_high * slope_high))
			row_high = min(v_high, max(slab_low * slope_low, slab_low * slope_high, slab_high * slope_low, slab_high * slope_high))
			if(row_low > row_high)
				continue
		var/kv_low = max(v_min, -round(-(row_low - 0.5 + frac_v - 0.001)))
		var/kv_high = min(v_min + v_count - 1, round(row_high + 0.5 + frac_v + 0.001))
		var/base = (ku - u_min) * u_stride - v_min * stride + 1
		for(var/kv = kv_low, kv <= kv_high, kv++)
			var/datum/los_cell/B = blocker_grid[base + kv * stride]
			if(B && los_target_blocked(tx, ty, B.cell_x, B.cell_y, target_tile_x, target_tile_y, B.tile_x, B.tile_y, opaque_target) && !los_height_clears(src, B, tx, ty))
				return TRUE
	return FALSE

// A unit blocker's shadow on an eye-facing unit edge. Depth is positive in
// this coordinate system. Keep slope ratios: multiplying face into both sides
// would add an unnecessary third factor to bounded subtile comparisons.
/proc/los_surface_shadow(face, edge_low, edge_high, cx, cy)
	var/near_depth = max(0, cx - 0.5)
	var/far_depth = min(face, cx + 0.5)
	if (far_depth <= 0 || near_depth >= face)
		return null
	var/low_y = cy - 0.5
	var/high_y = cy + 0.5
	var/low_n = low_y
	var/low_d = far_depth
	var/high_n = high_y
	var/high_d = far_depth
	if (low_y < 0)
		low_d = near_depth
		if (!low_d)
			low_n = edge_low
			low_d = face
	if (high_y > 0)
		high_d = near_depth
		if (!high_d)
			high_n = edge_high
			high_d = face
	return list(low_n, low_d, high_n, high_d)

/datum/los_snapshot/proc/surface_blockers(tx, ty)
	if (!ensure_blocker_bins())
		return blockers
	var/list/candidates = list()
	var/min_x = los_bucket_lower(tx, 0.5)
	var/max_x = los_bucket_upper(tx, 0.5)
	var/min_y = los_bucket_lower(ty, 0.5)
	var/max_y = los_bucket_upper(ty, 0.5)
	for (var/bx = min_x, bx <= max_x, bx++)
		for (var/by = min_y, by <= max_y, by++)
			var/list/bin = blocker_bins["[bx],[by]"]
			if (bin)
				candidates += bin
	return candidates

// Every nearer unit blocker projects a shadow at least one unit wide. On a
// unit target edge it can therefore cover only a prefix, a suffix, or all of
// the edge. Their union needs two bounds, not sorting or per-pixel ray casts.
/datum/los_snapshot/proc/surface_edge_visible(face, edge_low, edge_high, axis, direction, tile_x, tile_y, atom/target, list/candidates)
	var/visible_low_n = edge_low
	var/visible_low_d = face
	var/visible_high_n = edge_high
	var/visible_high_d = face
	for (var/datum/los_cell/B in candidates)
		// Co-located foreign owners still occlude. Only this tree's own
		// contributions may be ignored, including conservative overlap cells.
		if (B.owners == 1 && B.surface_owner == target)
			continue
		if (abs(B.cell_x) <= 0.5 && abs(B.cell_y) <= 0.5)
			return FALSE
		var/depth = B.cell_x * direction
		var/side = B.cell_y
		if (axis)
			depth = B.cell_y * direction
			side = B.cell_x
		var/list/shadow = los_surface_shadow(face, edge_low, edge_high, depth, side)
		if (!shadow || shadow[3] * face < edge_low * shadow[4] || shadow[1] * face > edge_high * shadow[2])
			continue
		var/covers_low = shadow[1] * face <= edge_low * shadow[2]
		var/covers_high = shadow[3] * face >= edge_high * shadow[4]
		if (covers_low && covers_high)
			return FALSE
		if (covers_low)
			if (shadow[3] * visible_low_d > visible_low_n * shadow[4])
				visible_low_n = shadow[3]
				visible_low_d = shadow[4]
		else if (covers_high)
			if (shadow[1] * visible_high_d < visible_high_n * shadow[2])
				visible_high_n = shadow[1]
				visible_high_d = shadow[2]
		else
			// Fail closed if a future non-unit blocker violates the invariant.
			return FALSE
		if (visible_low_n * visible_high_d >= visible_high_n * visible_low_d)
			return FALSE
	return TRUE

// Freeze the actual physical rectangle once per opaque movable. Native turf
// contents includes fractional overlaps; shifting a full unit for EVERY such
// turf would fabricate surfaces beyond the physical tree. Reads skip this path.
/datum/los_snapshot/proc/capture_tree_bounds(atom/movable/A)
	if (!tree_bounds)
		tree_bounds = list()
	if (tree_bounds[A])
		return
	var/datum/los_tree_bounds/R = new
	R.root_x = A.x
	R.root_y = A.y
	R.root_z = A.z
	R.step_x = A.step_x
	R.step_y = A.step_y
	R.bound_x = A.bound_x
	R.bound_y = A.bound_y
	R.bound_width = A.bound_width
	R.bound_height = A.bound_height
	R.left = A.x - eye_x + (A.step_x + A.bound_x) / 32 - 0.5
	R.bottom = A.y - eye_y + (A.step_y + A.bound_y) / 32 - 0.5
	R.right = R.left + A.bound_width / 32
	R.top = R.bottom + A.bound_height / 32
	tree_bounds[A] = R

/datum/los_snapshot/proc/owned_surface_cells(atom/movable/target)
	if (!tree_bounds)
		return null
	var/datum/los_tree_bounds/R = tree_bounds[target]
	if (!R || R.root_x != target.x || R.root_y != target.y || R.root_z != target.z || R.step_x != target.step_x || R.step_y != target.step_y || R.bound_x != target.bound_x || R.bound_y != target.bound_y || R.bound_width != target.bound_width || R.bound_height != target.bound_height)
		return null
	if (R.cells)
		return R.cells
	R.cells = list()
	// Clip to the viewport before subdividing; even custom large bounds cannot
	// cause unbounded surface allocation. Each real subrectangle is <=1x1.
	var/left = max(R.left, -radius_x - 0.5)
	var/right = min(R.right, radius_x + 0.5)
	var/bottom = max(R.bottom, -radius_y - 0.5)
	var/top = min(R.top, radius_y + 0.5)
	for (var/cell_left = left, cell_left < right, cell_left++)
		for (var/cell_bottom = bottom, cell_bottom < top, cell_bottom++)
			var/datum/los_surface_cell/C = new
			C.half_x = min(1, right - cell_left) / 2
			C.half_y = min(1, top - cell_bottom) / 2
			C.cell_x = cell_left + C.half_x
			C.cell_y = cell_bottom + C.half_y
			R.cells += C
	return R.cells

/datum/los_snapshot/proc/tree_surface_visible(atom/target, tx, ty, tile_x, tile_y)
	var/list/cells = owned_surface_cells(target)
	for (var/datum/los_surface_cell/owned in cells)
		tx = owned.cell_x
		ty = owned.cell_y
		var/list/candidates = surface_blockers(tx, ty)
		if (abs(tx) <= owned.half_x && abs(ty) <= owned.half_y)
			return TRUE
		if (tx > owned.half_x && surface_edge_visible(tx-owned.half_x, ty-owned.half_y, ty+owned.half_y, 0, 1, tile_x, tile_y, target, candidates))
			return TRUE
		if (tx < -owned.half_x && surface_edge_visible(-tx-owned.half_x, ty-owned.half_y, ty+owned.half_y, 0, -1, tile_x, tile_y, target, candidates))
			return TRUE
		if (ty > owned.half_y && surface_edge_visible(ty-owned.half_y, tx-owned.half_x, tx+owned.half_x, 1, 1, tile_x, tile_y, target, candidates))
			return TRUE
		if (ty < -owned.half_y && surface_edge_visible(-ty-owned.half_y, tx-owned.half_x, tx+owned.half_x, 1, -1, tile_x, tile_y, target, candidates))
			return TRUE
	return FALSE

/datum/los_mutation
	should_save = FALSE
	var/datum/los_context/context
	var/closed = FALSE

/datum/los_context
	should_save = FALSE
	var/client/owner
	var/mob/living/human/body
	var/turf/movement_turf
	// Half-tile eye offset at the last movement callback ("x,y" pixels).
	var/movement_bucket
	var/revision = 1
	var/retired = FALSE
	var/list/mutations = list()
	var/list/root_trees = list()
	var/viewport_cache_ready = FALSE
	var/viewport_cached_view
	var/list/viewport_cached_dimensions
	// Set only while one renderer runs a synchronous, non-sleeping pass.
	var/datum/los_snapshot/verified_snapshot
	var/verified_snapshot_time = -1
	// Inputs of the last complete publication, read only by the periodic
	// presentation audit. Never a lease: every refresh still captures fresh.
	var/datum/los_snapshot/audit_snapshot
	var/list/audit_appearances
	var/audit_image_count = -1
	var/audit_screen_count = -1

/datum/los_context/New(client/C)
	..()
	if (!CIV13_GEOMETRIC_LOS_CORE || !C)
		retired = TRUE
		return
	if (C.los_context)
		C.los_context.retire()
	if (!los_active_contexts)
		los_active_contexts = list()
	owner = C
	body = C.mob
	movement_turf = get_turf(body)
	C.los_context = src
	los_active_contexts += src

/datum/los_context/Destroy()
	retire()
	return ..()

/datum/los_context/proc/retire()
	retired = TRUE
	// Without a presentation nothing masks what the height flags would send.
	los_height_sight_revoke(body)
	if (owner && owner.los_presenter)
		owner.los_presenter.retire()
	if (CIV13_ROOT_TREE_PRESENTATION && owner && owner.root_tree_presenter)
		owner.root_tree_presenter.retire()
	root_trees.Cut()
	end_snapshot_pass()
	clear_audit_scene()
	viewport_cache_ready = FALSE
	viewport_cached_view = null
	viewport_cached_dimensions = null
	for (var/datum/los_mutation/M in mutations)
		M.closed = TRUE
		M.context = null
	mutations.Cut()
	if (owner && owner.los_context == src)
		owner.los_context = null
	if (los_active_contexts)
		los_active_contexts -= src
		if (!los_active_contexts.len)
			los_active_contexts = null
	owner = null
	body = null
	movement_turf = null
	movement_bucket = null

/datum/los_context/proc/advance_revision()
	if (retired || revision >= 1000000)
		retire()
		return FALSE
	revision++
	return TRUE

/datum/los_context/proc/begin_change()
	if (mutations.len >= 16)
		retire()
		return null
	if (!advance_revision())
		return null
	var/datum/los_mutation/M = new
	M.context = src
	mutations += M
	clear_audit_scene()
	if (owner && owner.los_presenter)
		owner.los_presenter.invalidate()
	if (CIV13_ROOT_TREE_PRESENTATION && owner && owner.root_tree_presenter)
		owner.root_tree_presenter.invalidate()
	return M

// Closing an outer ticket cannot clear a nested or newer mutation.
/datum/los_context/proc/finish_change(datum/los_mutation/M)
	if (!M || M.closed || M.context != src || !(M in mutations))
		return FALSE
	mutations -= M
	M.closed = TRUE
	M.context = null
	return advance_revision()

// Unsupported camera/observer modes retain their established native behavior.
// Blindness, mutations and save activity are NOT eligibility exemptions: they
// suspend presentation and deny world information for an otherwise owned viewer.
/datum/los_context/proc/eligible()
	return !retired && owner && owner.los_context == src && body && istype(body, /mob/living/human) && owner.mob == body && owner.eye == body && !owner.adminobs && isturf(body.loc)

/datum/los_context/proc/viewport()
	if (!owner)
		return null
	// Only the parsed scalar view is cached, never geometry or read authority.
	// Internal callers treat this dimensions list as read-only.
	if (viewport_cache_ready && owner.view == viewport_cached_view)
		return viewport_cached_dimensions
	viewport_cached_view = owner.view
	viewport_cache_ready = TRUE
	viewport_cached_dimensions = null
	var/list/dimensions = getviewsize(owner.view)
	if (!dimensions || dimensions.len != 2 || dimensions[1] < 1 || dimensions[2] < 1 || dimensions[1] > 63 || dimensions[2] > 63)
		return null
	viewport_cached_dimensions = dimensions
	return viewport_cached_dimensions

// The camera pans independently of the physical eye. Cover the whole sweep
// between body-centered and panned view, so animation cannot expose an uncaptured
// leading edge. Keep the existing 63-cell view admission; do not move the eye
// or truncate the camera sweep, which could leave native pixels unmasked.
/datum/los_context/proc/viewport_radii()
	var/list/dimensions = viewport()
	if (!dimensions)
		return null
	var/pan_x = -round(-abs(owner.pixel_x) / 32)
	var/pan_y = -round(-abs(owner.pixel_y) / 32)
	if (world.time <= owner.los_camera_union_until)
		// Also cover view growth which occurs without another pan preparation.
		pan_x = max(pan_x, owner.los_camera_pan_x)
		pan_y = max(pan_y, owner.los_camera_pan_y)
	var/radius_x = round(dimensions[1] / 2) + pan_x
	var/radius_y = round(dimensions[2] / 2) + pan_y
	if (world.time <= owner.los_camera_union_until)
		radius_x = max(radius_x, owner.los_camera_radius_x)
		radius_y = max(radius_y, owner.los_camera_radius_y)
	return list(radius_x, radius_y)

/datum/los_context/proc/policy_key(tile_anchored = FALSE)
	if (!eligible() || !viewport() || mutations.len || (persistence_active_operation && persistence_active_operation.kind != "save") || body.stat || is_blind(body))
		return null
	// Presentation follows the eye in half-tile steps; reads use the exact offset.
	var/offset_key = tile_anchored ? ",q[los_eye_bucket(body)]" : ",[body.step_x],[body.step_y]"
	return "[revision]|\ref[body]|[body.x],[body.y],[body.z][offset_key]|[owner.view]|[owner.pixel_x],[owner.pixel_y]|[world.time <= owner.los_camera_union_until ? owner.los_camera_radius_x : 0],[world.time <= owner.los_camera_union_until ? owner.los_camera_radius_y : 0]|[owner.perspective]|[body.sight & ~body.los_height_sight]|[body.see_invisible]|[body.see_in_dark]|[body.dir]|[body.resting],[body.lying],[body.prone]|[config ? config.disable_fov : 1]|\ref[body.pulling]"

/datum/los_context/proc/presentation_key()
	return policy_key(TRUE)

// policy_key() builds a long string; a renderer pass would otherwise rebuild
// it for every tile and atom in view. A pass checks its snapshot once here,
// makes only non-sleeping decisions, then ends the pass and rechecks policy
// and revision before it publishes anything. Other reads still check fresh.
/datum/los_context/proc/begin_snapshot_pass(datum/los_snapshot/S)
	verified_snapshot = null
	if (S && S.revision == revision && S.policy == policy_key())
		verified_snapshot = S
		verified_snapshot_time = world.time
	return !!verified_snapshot

/datum/los_context/proc/end_snapshot_pass()
	verified_snapshot = null
	verified_snapshot_time = -1

// The one-second presentation audit exists for raw opacity and art writers
// that have no central setter. Almost every audit finds the scene unchanged,
// yet it repaid the whole presenter refresh (about 25 ms per idle Gaia client).
// A fresh capture plus this scan costs a small fraction of that. It is only a
// skip condition for an already published presentation: any new, removed or
// changed atom, blocker, tree bound, client image or screen object, or any
// policy change, still takes the full refresh.
/datum/los_context/proc/audit_scene_radius(datum/los_snapshot/S)
	return max(S.radius_x, S.radius_y) + 6

/datum/los_context/proc/audit_scene_member(atom/A)
	// Lighting masks are never presented and change colour constantly; their
	// tree lighting reaches the compositor through root_tree_light_changed.
	return !istype(A, /atom/movable/lighting_overlay) && !istype(A, /atom/movable/lighting_fullbright)

/datum/los_context/proc/clear_audit_scene()
	audit_snapshot = null
	audit_appearances = null
	audit_image_count = -1
	audit_screen_count = -1

/datum/los_context/proc/record_audit_scene(datum/los_snapshot/S)
	clear_audit_scene()
	if (!S || !S.presentation || retired || !owner || !body)
		return FALSE
	var/list/appearances = list()
	for (var/atom/A in range(audit_scene_radius(S), body))
		if (audit_scene_member(A))
			appearances[A] = A.appearance
	audit_snapshot = S
	audit_appearances = appearances
	audit_image_count = length(owner.images)
	audit_screen_count = length(owner.screen)
	return TRUE

/datum/los_context/proc/audit_scene_unchanged(datum/los_snapshot/S)
	if (!S || !S.presentation || !audit_snapshot || !audit_appearances || retired || !owner || !body)
		return FALSE
	if (length(owner.images) != audit_image_count || length(owner.screen) != audit_screen_count)
		return FALSE
	if (!S.same_geometry(audit_snapshot))
		return FALSE
	var/count = 0
	for (var/atom/A in range(audit_scene_radius(S), body))
		if (!audit_scene_member(A))
			continue
		if (audit_appearances[A] != A.appearance)
			return FALSE
		count++
	return count == audit_appearances.len

// A focus (one read's target, never a presentation) limits the walk to the
// box spanning the eye and that target plus three tiles: every blocker the
// eye-target hull or a neighbour check can touch lies inside it.
/datum/los_context/proc/capture(presentation = FALSE, atom/focus = null)
	var/key = policy_key()
	if (!key)
		return null
	var/list/radii = viewport_radii()
	var/datum/los_snapshot/S = new
	S.presentation = presentation
	S.revision = revision
	S.policy = key
	// Presentation follows the eye's pixel offset in half-tile steps, so a
	// sub-tile step refreshes it at most twice per tile. Information reads
	// capture the exact physical offset rather than borrowing a visual lease.
	if (presentation)
		S.eye_x = body.x + los_eye_quantized(body.step_x) / 32
		S.eye_y = body.y + los_eye_quantized(body.step_y) / 32
	else
		S.eye_x = body.x + body.step_x / 32
		S.eye_y = body.y + body.step_y / 32
	S.eye_z = body.z
	S.radius_x = radii[1]
	S.radius_y = radii[2]
	// Hills: one shared, cached answer per eye position (null on flat ground).
	var/list/terrain = los_terrain_for(body, max(S.radius_x, S.radius_y) + 2)
	if (terrain)
		S.terrain = terrain[1]
		S.eye_top = S.terrain.eye
		S.terrain_tile_x = terrain[2]
		S.terrain_tile_y = terrain[3]
	// One extra tile covers fractional blockers and edge geometry. Ordinary
	// clutter never invalidates the scene; opacity alone owns blocking geometry.
	var/low_x = max(1, body.x-S.radius_x-1)
	var/high_x = min(world.maxx, body.x+S.radius_x+1)
	var/low_y = max(1, body.y-S.radius_y-1)
	var/high_y = min(world.maxy, body.y+S.radius_y+1)
	if (focus && !presentation && focus.z == S.eye_z)
		low_x = max(low_x, min(body.x, focus.x) - 3)
		high_x = min(high_x, max(body.x, focus.x) + 3)
		low_y = max(low_y, min(body.y, focus.y) - 3)
		high_y = min(high_y, max(body.y, focus.y) + 3)
	for (var/cx = low_x, cx <= high_x, cx++)
		for (var/cy = low_y, cy <= high_y, cy++)
			var/turf/T = locate(cx, cy, S.eye_z)
			if (!T)
				continue
			var/owner_count = 0
			var/atom/cell_owner = null
			// Tallest opaque owner on this tile, in levels above its ground.
			var/cell_height = 0
			if (T.opacity)
				cell_owner = T
				owner_count++
				cell_height = los_target_top(T)
			for (var/atom/A in T)
				if (A.opacity && A != body)
					if (ismovable(A))
						var/atom/movable/AM = A
						if (presentation && root_tree_family(AM))
							S.capture_tree_bounds(AM)
						if (AM.step_x || AM.step_y)
							var/datum/los_cell/moving_blocker = new
							moving_blocker.tile_x = cx - S.eye_x
							moving_blocker.tile_y = cy - S.eye_y
							moving_blocker.cell_x = cx - S.eye_x + AM.step_x / 32
							moving_blocker.cell_y = cy - S.eye_y + AM.step_y / 32
							moving_blocker.surface_owner = AM
							moving_blocker.owners = 1
							if (terrain)
								moving_blocker.top = los_blocker_top(S, T, los_target_top(AM))
							S.blockers += moving_blocker
							continue
					cell_owner = A
					owner_count++
					cell_height = max(cell_height, los_target_top(A))
			// Empty ground allocates no los_cell; moving blockers stay separate.
			if (owner_count)
				var/datum/los_cell/B = new
				B.tile_x = cx - S.eye_x
				B.tile_y = cy - S.eye_y
				B.cell_x = cx - S.eye_x
				B.cell_y = cy - S.eye_y
				B.surface_owner = cell_owner
				B.owners = owner_count
				if (terrain)
					B.top = los_blocker_top(S, T, cell_height)
				S.blockers += B
	if (S.revision != revision || S.policy != policy_key())
		return null
	los_snapshot_see_over(S)
	S.index_blockers()
	return S

// Shared synchronous geometric decision for a renderer's single captured pass.
// Coordinates are eye-relative, keeping products small on large Gaia maps.
/datum/los_context/proc/decision_snapshot(atom/target, datum/los_snapshot/S, operation = "visual")
	if (!S || !target || target.gcDestroyed || target.gc_destroyed || S.revision != revision || ((S != verified_snapshot || verified_snapshot_time != world.time) && S.policy != policy_key()))
		return LOS_DENY
	if (target == body)
		return LOS_SELF
	if ((!isturf(target) && !isturf(target.loc)) || target.z != S.eye_z || !target.alpha || target.invisibility > body.see_invisible)
		return LOS_DENY
	var/target_tile_x = target.x - S.eye_x
	var/target_tile_y = target.y - S.eye_y
	var/tx = target_tile_x
	var/ty = target_tile_y
	if (ismovable(target) && (!S.presentation || !ishuman(target)))
		var/atom/movable/moving_target = target
		tx += moving_target.step_x / 32
		ty += moving_target.step_y / 32
	var/tree_presentation = S.presentation && operation == "visual_tree" && target.opacity
	var/outside_view = abs(tx) > S.radius_x + 0.5 || abs(ty) > S.radius_y + 0.5
	if (outside_view && !tree_presentation)
		return LOS_DENY
	// Preserve the existing directional human concealment policy, when active.
	if (istype(target, /mob/living/human) && config && !config.disable_fov && body.HUDtech && !body.resting && !body.lying && !body.prone && get_dist(body, target) > 1 && body.pulling != target)
		var/obj/screen/fov/F = body.HUDtech["fov"]
		if (F && F.alpha && target.InCone(body, OPPOSITE_DIR(body.dir)))
			return LOS_DENY
	var/result = target.opacity ? LOS_SURFACE : LOS_WORLD
	// Anything the body can touch right now stays rendered and examinable. The
	// closed corner rule would otherwise black out a diagonal neighbour beside a
	// wall even though clicks still reach it. Adjacent() keeps both-sides-walled
	// diagonals hidden, so this admits nothing a hand could not already reach.
	// The eye may carry a sub-tile step, so this is only a cheap prefilter;
	// Adjacent() makes the real one-tile decision.
	if (abs(target_tile_x) < 2 && abs(target_tile_y) < 2 && los_reach_admits(body, target))
		return result
	// Ground rising above the sight line hides the target unless its top
	// shows over it. Depends on the target's height, so it is not cached in
	// the footprint cache below.
	if (!los_terrain_target_visible(S, target))
		return LOS_DENY
	// Equal visual coordinates can belong to different native tiles during a
	// smooth step. Include BOTH native tile and opacity policy in the cache key.
	var/footprint_key = "[target.opacity]|[target_tile_x],[target_tile_y]|[tx],[ty]"
	// From high ground a target can show over lower blockers (los_terrain.dm).
	var/query_top = los_height_query_top(S, target)
	if (query_top)
		footprint_key += "|h[query_top]"
	if (tree_presentation)
		footprint_key += "|tree-surface-\ref[target]"
	var/cached = S.clear_footprints[footprint_key]
	if (!isnull(cached))
		return cached
	S.query_top = query_top
	var/blocked = outside_view || S.blocks_target(tx, ty, target_tile_x, target_tile_y, target.opacity)
	// Neighbour checks below keep the flat rule.
	S.query_top = null
	if (blocked)
		// Only tree presentation may admit an exposed blocker edge. Terrain,
		// entities and fresh hover/examine retain their existing decisions.
		if (tree_presentation && S.tree_surface_visible(target, tx, ty, target_tile_x, target_tile_y))
			S.clear_footprints[footprint_key] = LOS_SURFACE
			return LOS_SURFACE
		// A wall, closed door or other opaque tile that bounds visible open
		// ground is a seen surface, like BYOND's own view. The closed-contact
		// ray otherwise blacks out every wall tile seen along its face and a
		// room's inner corner. It reveals the blocker only, never what is behind.
		if (target.opacity && !outside_view && !tree_presentation && !root_tree_family(target) && S.opaque_borders_visible(target_tile_x, target_tile_y))
			S.clear_footprints[footprint_key] = LOS_SURFACE
			return LOS_SURFACE
		S.clear_footprints[footprint_key] = LOS_DENY
		return LOS_DENY
	S.clear_footprints[footprint_key] = result
	return result

// Touch reach is the click system's own Adjacent() rule (border objects,
// passable diagonal corner). It never grants a new action; it only stops the
// geometric mask from hiding a world root the body can already interact with.
/proc/los_reach_admits(mob/body, atom/target)
	if (!body || !target || !isturf(body.loc))
		return FALSE
	var/turf/T = target.loc
	if (isturf(target))
		T = target
	if (!isturf(T))
		return FALSE
	// Standing inside a closed curtain (opaque, non-dense) blinds the viewer
	// to every other tile. Adjacent() ignores it, so keep that sight policy.
	if (los_turf_blocks_sight(body.loc, body))
		return FALSE
	// Reach only settles the closed-corner question. Contents sharing a tile
	// with an opaque blocker (closed door, curtain, bookcase, wall) keep the
	// ordinary geometric decision; touch reach never reveals what it hides.
	if (!target.opacity)
		if (T.opacity)
			return FALSE
		for (var/atom/movable/A in T)
			if (A.opacity && A != target)
				return FALSE
	// Adjacent() reaches a diagonal past non-dense blockers such as closed
	// curtains. Touch must not see through a corner where BOTH shared
	// cardinal tiles block sight; it may only clear the closed-contact crack.
	if (T.x != body.x && T.y != body.y)
		if (los_turf_blocks_sight(locate(T.x, body.y, T.z)) && los_turf_blocks_sight(locate(body.x, T.y, T.z)))
			return FALSE
	return target.Adjacent(body)

/proc/los_turf_blocks_sight(turf/T, atom/ignore = null)
	if (!T || T.opacity)
		return TRUE
	for (var/atom/movable/A in T)
		if (A.opacity && A != ignore)
			return TRUE
	return FALSE

// A displayed storage item is readable (hover and shift-click examine) only
// through this body's current open storage view. Screen membership alone does
// not authorize hidden contents.
/proc/los_storage_hover_visible(mob/user, atom/target)
	if (!user || !user.client || !istype(target, /obj/item))
		return FALSE
	var/client/C = user.client
	var/obj/item/weapon/storage/S = user.s_active
	if (C.mob != user || !istype(S, /obj/item/weapon/storage) || S.gcDestroyed || S.gc_destroyed || target.gcDestroyed || target.gc_destroyed)
		return FALSE
	if (target.loc != S || !(target in S.contents) || !(user in S.is_seeing))
		return FALSE
	var/obj/item/I = target
	return I.screen_loc && (I in C.screen)

// Fresh raw geometry on EACH information read covers direct opacity writers.
/datum/los_context/proc/decision(mob/user, atom/target, operation)
	if (operation != "hover" && operation != "examine" && operation != "observe" && operation != "click")
		return LOS_DENY
	if (retired || !owner || !body || owner.los_context != src || owner.mob != user || user != body || user.client != owner)
		return LOS_DENY
	if (!target || target.gcDestroyed || target.gc_destroyed)
		return LOS_DENY
	if (target == body)
		return LOS_SELF
	// Open storage contents sit off-turf, so geometry would always deny them.
	if (los_storage_hover_visible(user, target))
		return LOS_OWN_SLOT
	if (ismovable(target))
		var/atom/movable/I = target
		if (I.loc == body && (operation == "examine" || (I.screen_loc && (I in owner.screen))))
			return LOS_OWN_SLOT
	// A tree canopy the renderer shows through its exposed edge is drawn by the
	// "visual_tree" rule. Hover and examine read the same rule, so a tree the
	// player can see never refuses its name (or shows a name it does not draw).
	// Its surface test reaches beyond the eye-target box: capture everything.
	if ((operation == "hover" || operation == "examine") && los_tree_canopy_readable(target))
		return decision_snapshot(target, capture(), "visual_tree")
	var/atom/focus = null
	if (isturf(target) || isturf(target.loc))
		focus = target
	return decision_snapshot(target, capture(FALSE, focus), operation)

/proc/los_read_allowed(mob/user, atom/target, operation)
	if (!CIV13_GEOMETRIC_LOS_CORE)
		return TRUE
	if (!user || !user.client)
		return TRUE
	var/datum/los_context/C = user.client.los_context
	// Cameras, observers and non-human mobs retain their existing information
	// checks. An eligible human with a temporarily unavailable snapshot does not.
	if (!C || !C.eligible())
		return TRUE
	return C.decision(user, target, operation) != LOS_DENY
