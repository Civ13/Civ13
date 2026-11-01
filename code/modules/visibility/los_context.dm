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
	var/list/clear_footprints = list()
	var/list/tree_bounds

// The flat list remains authoritative and is retained for sparse scenes and
// snapshot fixtures. Bins are derived once per fresh capture, never shared.
/datum/los_snapshot/proc/index_blockers()
	blocker_bins = null
	if(blockers.len <= 16)
		return
	blocker_bins = list()
	for(var/datum/los_cell/B in blockers)
		var/bin_key = "[los_bucket_index(B.cell_x)],[los_bucket_index(B.cell_y)]"
		var/list/bin = blocker_bins[bin_key]
		if(!bin)
			bin = list()
			blocker_bins[bin_key] = bin
		bin += B

/datum/los_snapshot/proc/blocks_target(tx, ty, target_tile_x, target_tile_y, opaque_target)
	if(!blocker_bins)
		for(var/datum/los_cell/B in blockers)
			if(los_target_blocked(tx, ty, B.cell_x, B.cell_y, target_tile_x, target_tile_y, B.tile_x, B.tile_y, opaque_target))
				return TRUE
		return FALSE
	var/half_size = opaque_target ? 0 : 0.25
	var/min_x = los_bucket_lower(tx, half_size)
	var/max_x = los_bucket_upper(tx, half_size)
	var/min_y = los_bucket_lower(ty, half_size)
	var/max_y = los_bucket_upper(ty, half_size)
	// Iterate bins directly, without allocating a candidate list per target.
	for(var/bx = min_x, bx <= max_x, bx++)
		for(var/by = min_y, by <= max_y, by++)
			var/list/bin = blocker_bins["[bx],[by]"]
			if(!bin)
				continue
			for(var/datum/los_cell/B in bin)
				if(los_target_blocked(tx, ty, B.cell_x, B.cell_y, target_tile_x, target_tile_y, B.tile_x, B.tile_y, opaque_target))
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
	if (!blocker_bins)
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
	var/revision = 1
	var/retired = FALSE
	var/list/mutations = list()
	var/list/root_trees = list()
	var/viewport_cache_ready = FALSE
	var/viewport_cached_view
	var/list/viewport_cached_dimensions

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
	if (owner && owner.los_presenter)
		owner.los_presenter.retire()
	if (CIV13_ROOT_TREE_PRESENTATION && owner && owner.root_tree_presenter)
		owner.root_tree_presenter.retire()
	root_trees.Cut()
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

/datum/los_context/proc/policy_key(tile_anchored = FALSE)
	if (!eligible() || !viewport() || mutations.len || (persistence_active_operation && persistence_active_operation.kind != "save") || body.stat || is_blind(body))
		return null
	var/offset_key = tile_anchored ? "" : ",[body.step_x],[body.step_y]"
	return "[revision]|\ref[body]|[body.x],[body.y],[body.z][offset_key]|[owner.view]|[owner.perspective]|[body.sight]|[body.see_invisible]|[body.see_in_dark]|[body.dir]|[body.resting],[body.lying],[body.prone]|[config ? config.disable_fov : 1]|\ref[body.pulling]"

/datum/los_context/proc/presentation_key()
	return policy_key(TRUE)

/datum/los_context/proc/capture(presentation = FALSE)
	var/key = policy_key()
	if (!key)
		return null
	var/list/dimensions = viewport()
	var/datum/los_snapshot/S = new
	S.presentation = presentation
	S.revision = revision
	S.policy = key
	// Tile cadence is a presentation policy. Information reads still capture
	// fresh physical eye/target offsets rather than borrowing a visual lease.
	S.eye_x = body.x
	S.eye_y = body.y
	if (!presentation)
		S.eye_x += body.step_x / 32
		S.eye_y += body.step_y / 32
	S.eye_z = body.z
	S.radius_x = round(dimensions[1] / 2)
	S.radius_y = round(dimensions[2] / 2)
	// One extra tile covers fractional blockers and edge geometry. Ordinary
	// clutter never invalidates the scene; opacity alone owns blocking geometry.
	for (var/cx = max(1, body.x-S.radius_x-1), cx <= min(world.maxx, body.x+S.radius_x+1), cx++)
		for (var/cy = max(1, body.y-S.radius_y-1), cy <= min(world.maxy, body.y+S.radius_y+1), cy++)
			var/turf/T = locate(cx, cy, S.eye_z)
			if (!T)
				continue
			var/owner_count = 0
			var/atom/cell_owner = null
			if (T.opacity)
				cell_owner = T
				owner_count++
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
							S.blockers += moving_blocker
							continue
					cell_owner = A
					owner_count++
			// Empty ground allocates no los_cell; moving blockers stay separate.
			if (owner_count)
				var/datum/los_cell/B = new
				B.tile_x = cx - S.eye_x
				B.tile_y = cy - S.eye_y
				B.cell_x = cx - S.eye_x
				B.cell_y = cy - S.eye_y
				B.surface_owner = cell_owner
				B.owners = owner_count
				S.blockers += B
	if (S.revision != revision || S.policy != policy_key())
		return null
	S.index_blockers()
	return S

// Shared synchronous geometric decision for a renderer's single captured pass.
// Coordinates are eye-relative, keeping products small on large Gaia maps.
/datum/los_context/proc/decision_snapshot(atom/target, datum/los_snapshot/S, operation = "visual")
	if (!S || !target || target.gcDestroyed || target.gc_destroyed || S.revision != revision || S.policy != policy_key())
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
	// Equal visual coordinates can belong to different native tiles during a
	// smooth step. Include BOTH native tile and opacity policy in the cache key.
	var/footprint_key = "[target.opacity]|[target_tile_x],[target_tile_y]|[tx],[ty]"
	if (tree_presentation)
		footprint_key += "|tree-surface-\ref[target]"
	var/cached = S.clear_footprints[footprint_key]
	if (!isnull(cached))
		return cached
	if (outside_view || S.blocks_target(tx, ty, target_tile_x, target_tile_y, target.opacity))
		// Only tree presentation may admit an exposed blocker edge. Terrain,
		// entities and fresh hover/examine retain their existing decisions.
		if (tree_presentation && S.tree_surface_visible(target, tx, ty, target_tile_x, target_tile_y))
			S.clear_footprints[footprint_key] = LOS_SURFACE
			return LOS_SURFACE
		S.clear_footprints[footprint_key] = LOS_DENY
		return LOS_DENY
	S.clear_footprints[footprint_key] = result
	return result

// Fresh raw geometry on EACH information read covers direct opacity writers.
/datum/los_context/proc/decision(mob/user, atom/target, operation)
	if (operation != "hover" && operation != "examine")
		return LOS_DENY
	if (retired || !owner || !body || owner.los_context != src || owner.mob != user || user != body || user.client != owner)
		return LOS_DENY
	if (!target || target.gcDestroyed || target.gc_destroyed)
		return LOS_DENY
	if (target == body)
		return LOS_SELF
	if (ismovable(target))
		var/atom/movable/I = target
		if (I.loc == body && (operation == "examine" || (I.screen_loc && (I in owner.screen))))
			return LOS_OWN_SLOT
	var/datum/los_snapshot/S = capture()
	return decision_snapshot(target, S, operation)

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
