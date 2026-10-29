// Source-only #3233 core. No production caller creates a context and no map opts in.
// Keep disabled until all action, renderer and lifecycle adapters are reviewed.
#ifndef CIV13_GEOMETRIC_LOS_CORE
#define CIV13_GEOMETRIC_LOS_CORE 0
#endif
#ifndef CIV13_ROOT_TREE_PRESENTATION
#define CIV13_ROOT_TREE_PRESENTATION 0
#endif
#define LOS_DENY 0
#define LOS_WORLD 1
#define LOS_SURFACE 2
#define LOS_OWN_SLOT 3
#define LOS_SELF 4

/client/var/tmp/datum/los_context/los_context
var/global/list/los_active_contexts

// These numeric primitives use only integers/halves/quarters on the 21x21 slice.
// Closed contact is blocking. No epsilon can open a corner crack.
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

// The four triangles cover conv(eye, footprint), not just four corner rays.
/proc/los_footprint_hits_cell(ex, ey, tx, ty, half_size, cx, cy)
	if (los_triangle_hits_cell(ex, ey, tx-half_size, ty-half_size, tx+half_size, ty-half_size, cx, cy))
		return TRUE
	if (los_triangle_hits_cell(ex, ey, tx+half_size, ty-half_size, tx+half_size, ty+half_size, cx, cy))
		return TRUE
	if (los_triangle_hits_cell(ex, ey, tx+half_size, ty+half_size, tx-half_size, ty+half_size, cx, cy))
		return TRUE
	return los_triangle_hits_cell(ex, ey, tx-half_size, ty+half_size, tx-half_size, ty-half_size, cx, cy)

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
	var/atom/surface_owner
	var/owners = 0

/datum/los_snapshot
	should_save = FALSE
	var/revision
	var/policy
	var/eye_x
	var/eye_y
	var/list/blockers = list()

/datum/los_mutation
	should_save = FALSE
	var/datum/los_context/context
	var/closed = FALSE

/datum/los_context
	should_save = FALSE
	var/client/owner
	var/mob/living/human/body
	var/revision = 1
	var/retired = FALSE
	var/list/mutations = list()
	var/list/root_trees = list()

/datum/los_context/New(client/C)
	..()
	if (!CIV13_GEOMETRIC_LOS_CORE || !C)
		retired = TRUE
		return
	if (C.los_context)
		C.los_context.retire()
	if (!los_active_contexts)
		los_active_contexts = list()
	if (los_active_contexts.len >= 2)
		retired = TRUE
		return
	owner = C
	body = C.mob
	C.los_context = src
	los_active_contexts += src

/datum/los_context/Destroy()
	retire()
	return ..()

/datum/los_context/proc/retire()
	retired = TRUE
	if (CIV13_ROOT_TREE_PRESENTATION && owner && owner.root_tree_presenter)
		owner.root_tree_presenter.retire()
	root_trees.Cut()
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

/datum/los_context/proc/policy_key()
	if (retired || !owner || owner.los_context != src || owner.mob != body || !body || body.type != /mob/living/human)
		return null
	if (mutations.len || persistence_active_operation || owner.eye != body || owner.adminobs || !isturf(body.loc) || body.stat || is_blind(body))
		return null
	if (body.step_x || body.step_y || world.maxx != 21 || world.maxy != 21 || world.maxz != 1)
		return null
	if (owner.view != 7 && owner.view != "15x15")
		return null
	if (!config || !global_hud || !global_hud.fov || !body.HUDtech || !body.HUDtech["fov"])
		return null
	var/obj/screen/fov/F = body.HUDtech["fov"]
	if (!istype(F, /obj/screen/fov) || !istype(global_hud.fov, /obj/screen/fov))
		return null
	// Preserve the existing shared mode; this commit does not make it per-client.
	return "[revision]|\ref[body]|[body.x],[body.y],[body.z]|[owner.view]|[owner.perspective]|[body.sight]|[body.see_invisible]|[body.see_in_dark]|[body.dir]|[body.resting],[body.lying],[body.prone]|\ref[F]|[F.alpha]|[global_hud.fov.icon_state]|[config.disable_fov]|\ref[body.pulling]"

/datum/los_context/proc/capture()
	var/key = policy_key()
	if (!key)
		return null
	var/datum/los_snapshot/S = new
	S.revision = revision
	S.policy = key
	S.eye_x = body.x
	S.eye_y = body.y
	var/visits = 0
	for (var/cx = max(1, body.x-8), cx <= min(21, body.x+8), cx++)
		for (var/cy = max(1, body.y-8), cy <= min(21, body.y+8), cy++)
			var/turf/T = locate(cx, cy, 1)
			if (!T || (T.type != /turf/floor/plating && T.type != /turf/wall))
				return null
			var/datum/los_cell/B = new
			B.cell_x = cx
			B.cell_y = cy
			if (T.opacity)
				B.surface_owner = T
				B.owners++
			for (var/atom/A in T)
				if (++visits > 1024)
					return null
				if (A.type == /atom/movable/lighting_overlay && !A.opacity)
					continue
				if (CIV13_ROOT_TREE_PRESENTATION && A.type == /atom/movable/lighting_fullbright && !A.opacity)
					continue
				if (A.type != /obj/structure/simple_door && A.type != /mob/living/human && !root_tree_admitted(A))
					return null
				if (A.opacity)
					B.surface_owner = A
					B.owners++
			if (B.owners)
				if (cx == body.x && cy == body.y)
					return null
				S.blockers += B
	if (S.revision != revision || S.policy != policy_key())
		return null
	return S

// This is a synchronous read decision. No snapshot is a reusable action lease.
// Fresh raw geometry on EACH call covers unhooked direct opacity writers here.
/datum/los_context/proc/decision(mob/user, atom/target, operation)
	if (operation != "hover" && operation != "examine")
		return LOS_DENY
	if (retired || !owner || !body || body.type != /mob/living/human || owner.los_context != src || owner.mob != user || user != body || user.client != owner || mutations.len)
		return LOS_DENY
	if (!target || target.gcDestroyed || target.gc_destroyed)
		return LOS_DENY
	if (ismovable(target))
		var/atom/movable/I = target
		if (operation == "hover" && I.loc == body && I.screen_loc && (I in owner.screen))
			return LOS_OWN_SLOT
	var/datum/los_snapshot/S = capture()
	if (!S)
		return LOS_DENY
	if (target == body)
		return LOS_SELF
	if (target.type != /turf/floor/plating && target.type != /turf/wall && target.type != /obj/structure/simple_door && target.type != /mob/living/human && !root_tree_admitted(target))
		return LOS_DENY
	if ((!isturf(target) && !isturf(target.loc)) || target.z != body.z || !target.alpha || target.invisibility > body.see_invisible)
		return LOS_DENY
	if (ismovable(target))
		var/atom/movable/moving_target = target
		if (moving_target.step_x || moving_target.step_y)
			return LOS_DENY
	if (abs(target.x-S.eye_x) > 7 || abs(target.y-S.eye_y) > 7 || !(target in view(owner.view, owner.eye)))
		return LOS_DENY
	var/obj/screen/fov/F = body.HUDtech["fov"]
	if (target.type == /mob/living/human && !config.disable_fov && F.alpha && !body.resting && !body.lying && !body.prone && get_dist(body, target) > 1 && body.pulling != target)
		if (target.InCone(body, OPPOSITE_DIR(body.dir)))
			return LOS_DENY
	var/result = LOS_WORLD
	if (target.opacity)
		if (target.type != /turf/wall && target.type != /obj/structure/simple_door && !root_tree_admitted(target))
			return LOS_DENY
		var/datum/los_cell/first
		var/list/best
		var/tied = FALSE
		for (var/datum/los_cell/B in S.blockers)
			var/list/hit = los_ray_entry(S.eye_x, S.eye_y, target.x, target.y, B.cell_x, B.cell_y)
			if (!hit)
				continue
			if (!best || hit[1]*best[2] < best[1]*hit[2])
				best = hit
				first = B
				tied = FALSE
			else if (hit[1]*best[2] == best[1]*hit[2])
				tied = TRUE
		if (!first || tied || first.owners != 1 || first.surface_owner != target)
			return LOS_DENY
		result = LOS_SURFACE
	else
		for (var/datum/los_cell/B in S.blockers)
			if (los_footprint_hits_cell(S.eye_x, S.eye_y, target.x, target.y, 0.25, B.cell_x, B.cell_y))
				return LOS_DENY
	if (S.revision != revision || S.policy != policy_key())
		return LOS_DENY
	return result

/proc/los_read_allowed(mob/user, atom/target, operation)
	if (!CIV13_GEOMETRIC_LOS_CORE)
		return TRUE
	if (!user || !user.client || !user.client.los_context)
		return FALSE
	return user.client.los_context.decision(user, target, operation) != LOS_DENY
