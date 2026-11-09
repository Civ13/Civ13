// Native probe for height-aware line of sight. Compiled with
// code/modules/visibility/los_terrain.dm and the height parser from
// code/modules/1713/terrain_height.dm, plus the small stubs below.
// Writes each field's ground-hidden cells for run.py to compare against its
// Python reference, and times the sweep.
/datum/var/should_save = TRUE
/obj/map_metadata
	var/terrain_height_file = null
	var/tmp/datum/terrain_heights/terrain_heights_cache = null
/obj/map_metadata/proc/terrain_heights()
	if (!terrain_heights_cache)
		terrain_heights_cache = terrain_heights_parse(file2text(terrain_height_file), world.maxx, world.maxy, world.maxz)
	return terrain_heights_cache.error ? null : terrain_heights_cache
var/global/obj/map_metadata/map
var/global/invalidated = 0
/proc/root_tree_family(atom/A)
	return FALSE
/proc/los_invalidate(atom/A, possible = FALSE)
	invalidated++
/mob
	var/resting = FALSE
	var/lying = FALSE
	var/prone = FALSE
/proc/ishuman(A)
	return istype(A, /mob/living/human)
/mob/living/human
	var/equipment_vision_flags = 0
/area
	var/location = 1
/proc/get_turf(atom/A)
	return isturf(A) ? A : get_turf(A.loc)
/proc/los_read_allowed(mob/M, atom/A, operation)
	return TRUE

/world
	maxx = 500
	maxy = 350
	maxz = 2

/world/New()
	..()
	spawn(1)
		los_terrain_probe()

/proc/los_terrain_probe()
	map = new
	map.terrain_height_file = "heights.txt"
	var/datum/terrain_heights/H = map.terrain_heights()
	if (!H)
		world.log << "LOS_TERRAIN FAIL heights did not load"
		shutdown()
		return
	var/list/eyes = json_decode(file2text("eyes.json"))
	var/list/out = list()
	var/mob/M = new
	for (var/list/e in eyes)
		M.loc = locate(e[1], e[2], 2)
		M.step_x = e[3]
		M.step_y = e[4]
		M.lying = e[5]
		var/list/r = los_terrain_for(M, e[6])
		var/list/hidden = list()
		if (r)
			var/datum/los_terrain_field/F = r[1]
			for (var/i = -F.radius, i <= F.radius, i++)
				for (var/j = -F.radius, j <= F.radius, j++)
					if (!F.visible(i, j, LOS_GROUND_TOP))
						hidden += "[i],[j]"
			out += list(list("tile" = list(r[2], r[3]), "hidden" = hidden))
		else
			out += list(null)
	// Timing: fresh sweeps (cache cleared) and cached lookups.
	var/start = world.timeofday
	var/builds = 0
	for (var/n = 1 to 4)
		for (var/list/e in eyes)
			los_terrain_cache = list()
			M.loc = locate(e[1], e[2], 2)
			M.step_x = e[3]
			M.step_y = e[4]
			M.lying = e[5]
			los_terrain_for(M, 9)
			builds++
	var/build_ds = world.timeofday - start
	start = world.timeofday
	for (var/n = 1 to 20000)
		los_terrain_for(M, 9)
	var/cached_ds = world.timeofday - start
	// NPC sight: one ray per viewer/target pair, and the sweep's answer for the
	// same pair (viewer centred, radius 14) for an agreement rate.
	var/list/pairs = json_decode(file2text("pairs.json"))
	var/list/rays = list()
	var/agree = 0
	var/mob/living/human/T = new
	for (var/list/p in pairs)
		M.loc = locate(p[1], p[2], 2)
		M.step_x = 0
		M.step_y = 0
		M.lying = p[3]
		T.loc = locate(p[4], p[5], 2)
		T.lying = p[6]
		var/blocked = los_terrain_ray_blocked(M, T)
		rays += blocked ? 1 : 0
		var/list/f = los_terrain_for(M, 14)
		var/swept = FALSE
		if (f)
			var/datum/los_terrain_field/F = f[1]
			swept = !F.visible(T.x - f[2], T.y - f[3], los_target_top(T))
		if (!blocked == !swept)
			agree++
	start = world.timeofday
	for (var/n = 1 to 20)
		for (var/list/p in pairs)
			M.loc = locate(p[1], p[2], 2)
			T.loc = locate(p[4], p[5], 2)
			los_terrain_ray_blocked(M, T)
	var/ray_ds = world.timeofday - start
	// Grading (terrain_heights/set_level) clears the cache and refreshes viewers.
	los_terrain_heights_changed(locate(M.x, M.y, 2))
	var/cleared = !los_terrain_cache.len && invalidated == 1
	text2file(json_encode(list("fields" = out, "builds" = builds, "build_ds" = build_ds, "cached_ds" = cached_ds, "cleared" = cleared, "see_over" = los_see_over_cases(), "rays" = rays, "agree" = agree, "ray_ds" = ray_ds)), "result.json")
	world.log << "LOS_TERRAIN DONE"
	shutdown()

// Seeing over lower blockers: an eye on a 6-level hill looks east over flat
// ground at height 0. Returns "name=blocked" for each case.
/proc/los_see_over_snapshot(eye_ground, blocker_height)
	var/datum/los_terrain_field/F = new
	F.radius = 9
	F.side = 19
	F.ground = new /list(F.side * F.side)
	F.required = new /list(F.side * F.side)
	for (var/n = 1 to F.ground.len)
		F.ground[n] = 0
	F.ground[F.index(0, 0)] = eye_ground
	F.eye = eye_ground + LOS_EYE_STANDING
	var/datum/los_snapshot/S = new
	S.terrain = F
	S.eye_top = F.eye
	S.radius_x = 9
	S.radius_y = 9
	var/datum/los_cell/B = new
	B.tile_x = 3
	B.tile_y = 0
	B.cell_x = 3
	B.cell_y = 0
	B.owners = 1
	B.top = F.ground[F.index(3, 0)] + blocker_height
	S.blockers += B
	for (var/datum/los_cell/C in S.blockers)
		if (!isnull(C.top) && C.top < S.eye_top)
			S.see_over = TRUE
	S.index_blockers()
	return S

/proc/los_see_over_query(datum/los_snapshot/S, x, top)
	S.query_top = S.see_over && !isnull(top) ? top : null
	. = S.blocks_target(x, 0, x, 0, FALSE)
	S.query_top = null

/proc/los_see_over_cases()
	var/list/out = list()
	var/datum/los_snapshot/S = los_see_over_snapshot(6, 3)
	out["hill_far_ground"] = los_see_over_query(S, 8, LOS_GROUND_TOP)
	out["hill_close_behind_wall"] = los_see_over_query(S, 4, LOS_GROUND_TOP)
	out["hill_person_two_behind_wall"] = los_see_over_query(S, 5, 1.5)
	out["hill_indoors"] = los_see_over_query(S, 8, null)
	S.query_top = LOS_GROUND_TOP
	out["hill_line_clears"] = los_height_clears(S, S.blockers[1], 8, 0)
	S.query_top = null
	S = los_see_over_snapshot(6, 5)
	out["hill_tree"] = los_see_over_query(S, 8, LOS_GROUND_TOP)
	S = los_see_over_snapshot(0, 3)
	out["flat_wall"] = los_see_over_query(S, 8, LOS_GROUND_TOP)
	out["flat_see_over"] = S.see_over
	return out
