// ============================================================
// Built bodies (docs/craft-core.md): a hull the players laid themselves
// ------------------------------------------------------------
// Players build floors and walls over water as /obj/covers objects. A built
// body is the set of water tiles those floors stand on, kept as offsets from
// a pivot (the tile of the tiller that commissioned it). A move carries
// everything standing on those tiles to the matching tiles of the new place
// in one call, and hands the water level of each tile from the floors that
// leave it to the floors that arrive.
//
// One level only. Nothing here is a turf template: the hull is whatever is
// built on its tiles when it moves.
// ============================================================

#define BUILT_HULL_MAX_TILES 200

/datum/craft_body/built
	var/hull_name = "hull"
	var/z = 0
	var/px = 0                    // The pivot: the tile the tiller stands on.
	var/py = 0
	var/dir = NORTH               // Where the bow points.
	var/list/offsets = list()     // list(dx, dy) from the pivot, one per tile.
	var/tmp/list/offset_index = list() // "dx,dy" -> TRUE, for contains().
	var/tmp/moving = FALSE
	glides = TRUE

/datum/craft_body/built/craft_name()
	return hull_name

/datum/craft_body/built/placed()
	return z > 0 && offsets.len > 0

/datum/craft_body/built/proc/set_offsets(list/new_offsets)
	offsets = new_offsets
	offset_index = list()
	for (var/list/O in offsets)
		offset_index["[O[1]],[O[2]]"] = TRUE

/datum/craft_body/built/cells()
	. = list()
	if (!placed())
		return
	for (var/list/O in offsets)
		var/turf/T = locate(px + O[1], py + O[2], z)
		if (T)
			. += T

/datum/craft_body/built/tile_count()
	return offsets.len

/datum/craft_body/built/contains(turf/T)
	return T && placed() && T.z == z && offset_index["[T.x - px],[T.y - py]"]

// The box around a set of offsets: list(min dx, min dy, max dx, max dy).
/datum/craft_body/built/proc/box(list/of)
	. = list(0, 0, 0, 0)
	var/first = TRUE
	for (var/list/O in of)
		if (first)
			. = list(O[1], O[2], O[1], O[2])
			first = FALSE
			continue
		.[1] = min(.[1], O[1])
		.[2] = min(.[2], O[2])
		.[3] = max(.[3], O[1])
		.[4] = max(.[4], O[2])

/datum/craft_body/built/origin()
	if (!placed())
		return null
	var/list/B = box(offsets)
	return locate(px + B[1], py + B[2], z)

/datum/craft_body/built/heading()
	return dir

/datum/craft_body/built/length_tiles()
	var/list/B = box(offsets)
	return (dir == NORTH || dir == SOUTH) ? B[4] - B[2] + 1 : B[3] - B[1] + 1

/datum/craft_body/built/beam_tiles()
	var/list/B = box(offsets)
	return (dir == NORTH || dir == SOUTH) ? B[3] - B[1] + 1 : B[4] - B[2] + 1

// The offsets as they would lie with the bow to heading.
/datum/craft_body/built/proc/turned_offsets(heading)
	var/angle = craft_turn_angle(dir, heading)
	. = list()
	for (var/list/O in offsets)
		switch (angle)
			if (90) . += list(list(-O[2], O[1]))
			if (-90) . += list(list(O[2], -O[1]))
			if (180, -180) . += list(list(-O[1], -O[2]))
			else . += list(list(O[1], O[2]))

// Why a tile the hull does not already cover cannot take it, or null.
/datum/craft_body/built/proc/tile_refusal(turf/D)
	if (!istype(D, /turf/floor/beach/water))
		return "[D.name] ahead at [D.x],[D.y]"
	if (locate(/obj/covers) in D)
		return "a built floor in the way at [D.x],[D.y]"
	if (vessel_at(D))
		return "another ship in the way at [D.x],[D.y]"
	for (var/atom/movable/M in D)
		if (M.loc == D && M.density && !istype(M, /atom/movable/lighting_overlay))
			return "[M.name] in the way at [D.x],[D.y]"
	return null

// Plans a move that puts the box corner at (x, y) with the bow to heading.
// Returns list(new px, new py, new offsets, destination turfs in offset
// order), or null with last_refusal set. Writes nothing.
/datum/craft_body/built/proc/plan(x, y, heading)
	if (!placed())
		last_refusal = "she is not afloat"
		return null
	var/list/turned = turned_offsets(heading)
	var/list/B = box(turned)
	var/nx = x - B[1]
	var/ny = y - B[2]
	var/list/mine = cells()
	var/overhang = craft_overhang_refusal(mine)
	if (overhang)
		last_refusal = overhang
		return null
	var/list/dest = list()
	for (var/list/O in turned)
		var/turf/D = locate(nx + O[1], ny + O[2], z)
		if (!D)
			last_refusal = "the edge of the world"
			return null
		if (!(D in mine))
			var/why = tile_refusal(D)
			if (why)
				last_refusal = why
				return null
		dest += D
	return list(nx, ny, turned, dest)

/datum/craft_body/built/move_cells(x, y, heading)
	var/list/P = plan(x, y, heading)
	return P ? P[4] : null

/datum/craft_body/built/can_move_to(x, y, heading)
	return !isnull(plan(x, y, heading))

// The water level a tile has under whatever floors stand on it.
/datum/craft_body/built/proc/true_water_level(turf/T)
	. = T.water_level
	for (var/obj/covers/C in T)
		. = max(., C.origin_water_level)

/datum/craft_body/built/move_to(x, y, heading)
	if (moving)
		last_refusal = "already moving"
		return FALSE
	// Never rewrite a level while the world save is capturing it.
	if (persistence_save_in_progress)
		last_refusal = "the world is being saved"
		return FALSE
	var/started = world.timeofday
	var/list/P = plan(x, y, heading)
	if (!P)
		return FALSE
	var/list/old = list()
	for (var/list/O in offsets)
		old += locate(px + O[1], py + O[2], z)
	var/list/dest = P[4]
	var/turf/old_origin = origin()
	var/angle = craft_turn_angle(dir, heading)
	moving = TRUE
	var/list/carry = null
	// A step of one tile without a turn is shown as a glide (glide.dm).
	var/gliding = (glides && glide_time > 0 && !angle && abs(P[1] - px) + abs(P[2] - py) == 1) ? glide_time : 0
	try
		// What rides on each tile, and the water under every tile involved,
		// before anything changes.
		var/list/cargo = list()
		var/list/water = list()
		for (var/turf/S in old)
			var/list/riders = list()
			for (var/atom/movable/M in S)
				if (M.loc != S || QDELETED(M))
					continue
				if (istype(M, /atom/movable/lighting_overlay) || istype(M, /atom/movable/lighting_fullbright) || istype(M, /obj/effect/vessel_path) || M.craft_left_behind())
					continue
				riders += M
			cargo += list(riders)
			water[S] = true_water_level(S)
		for (var/turf/D in dest)
			if (isnull(water[D]))
				water[D] = D.water_level
		// The tiles she arrives on are dry before anyone steps onto them.
		for (var/i = 1, i <= dest.len, i++)
			var/turf/D = dest[i]
			if (locate(/obj/covers) in cargo[i])
				D.water_level = 0
				D.move_delay = 0
		// Wiring aboard keeps its links while she carries it (rigid_move.dm).
		var/list/everything = list()
		for (var/list/riders in cargo)
			everything += riders
		carry = craft_rigid_begin(everything)
		for (var/i = 1, i <= old.len, i++)
			var/turf/S = old[i]
			var/turf/D = dest[i]
			var/floored = FALSE
			for (var/atom/movable/M in cargo[i])
				if (QDELETED(M))
					continue
				if (S != D && M.loc == S)
					M.forceMove(D)
					if (gliding && M.loc == D)
						craft_glide(M, D.x - S.x, D.y - S.y, gliding)
				if (istype(M, /obj/covers))
					var/obj/covers/C = M
					C.origin_water_level = water[D]
					floored = TRUE
			if (!floored)
				D.water_level = water[D]
		craft_rigid_settle(carry)
		carry = null
		glide_keep(gliding ? everything : null)
		// The water closes where she was.
		for (var/turf/S in old)
			if (S in dest)
				continue
			S.water_level = water[S]
			S.move_delay = initial(S.move_delay)
		px = P[1]
		py = P[2]
		dir = heading
		set_offsets(P[3])
		if (angle)
			for (var/list/riders in cargo)
				for (var/atom/movable/M in riders)
					if (!QDELETED(M))
						M.craft_turned(craft, angle)
		// A turn is shown swinging round, and a slide into a berth is drawn
		// for as long as its caller asked, instead of snapping (glide.dm).
		if (glides && !gliding && (angle || slide_time > 0))
			var/shown = slide_time > 0 ? slide_time : glide_turn_time()
			if (!glide_was)
				glide_was = list()
			for (var/i = 1, i <= old.len, i++)
				var/turf/S = old[i]
				var/turf/D = dest[i]
				if (S == D)
					continue
				for (var/atom/movable/M in cargo[i])
					if (!QDELETED(M) && M.loc == D)
						glide_swing(glide_was, M, D.x - S.x, D.y - S.y, shown)
			glide_rest(shown)
	catch (var/exception/e)
		moving = FALSE
		craft_rigid_settle(carry)
		throw e
	moving = FALSE
	last_move_ms = (world.timeofday - started) * 100
	if (craft)
		craft.on_hop(old_origin)
		if (angle)
			craft.on_turn(angle)
	return TRUE

// Turns about the pivot.
/datum/craft_body/built/turn_to(heading)
	if (heading == dir)
		return TRUE
	var/list/B = box(turned_offsets(heading))
	return move_to(px + B[1], py + B[2], heading)

// ---- Commissioning ----

// The tiles of the hull built around start: every water tile with a built
// floor on it that joins start edge to edge. Returns the list of turfs, or a
// text saying why this is not a hull.
/proc/built_hull_survey(turf/start, datum/craft/refitting = null)
	if (!istype(start, /turf/floor/beach/water) || !hull_floor_in(start))
		return "It must stand on a floor built over water."
	var/list/found = list(start)
	var/list/queue = list(start)
	while (queue.len)
		var/turf/T = queue[1]
		queue.Cut(1, 2)
		for (var/d in cardinal)
			var/turf/N = get_step(T, d)
			if (!N || (N in found) || !hull_floor_in(N))
				continue
			if (!istype(N, /turf/floor/beach/water))
				return "The hull is still joined to the shore at [N.x],[N.y]. Cut her free first."
			if (vessel_at(N))
				return "The hull is joined to another ship at [N.x],[N.y]."
			var/datum/craft/other = craft_at(N)
			if (other && other != refitting)
				return "The hull is joined to the [other.name] at [N.x],[N.y]."
			found += N
			queue += N
			if (found.len > BUILT_HULL_MAX_TILES)
				return "The hull is too large: more than [BUILT_HULL_MAX_TILES] tiles of floor."
	return found

// Makes the body from surveyed turfs, with the pivot at pivot.
/datum/craft_body/built/proc/adopt(list/turfs, turf/pivot, heading)
	z = pivot.z
	px = pivot.x
	py = pivot.y
	dir = heading
	var/list/of = list()
	for (var/turf/T in turfs)
		of += list(list(T.x - px, T.y - py))
	set_offsets(of)
	set_afloat(TRUE)

// Marks every floor of the hull as part of a ship, or as plain planks again.
// A floor that is afloat does not sink when a load finds it on the deep sea.
/datum/craft_body/built/proc/set_afloat(state)
	for (var/turf/T in cells())
		for (var/obj/covers/C in T)
			C.afloat = state

// The body as plain numbers for a saved field, and back around a pivot.
/datum/craft_body/built/proc/body_state()
	var/list/flat = list()
	for (var/list/O in offsets)
		flat += O[1]
		flat += O[2]
	return list("name" = hull_name, "dir" = dir, "cells" = flat)

/datum/craft_body/built/proc/restore_state(list/state, turf/pivot)
	if (!islist(state) || !pivot)
		return FALSE
	var/list/flat = state["cells"]
	if (!islist(flat) || !flat.len || flat.len % 2 || flat.len > BUILT_HULL_MAX_TILES * 2)
		return FALSE
	var/list/of = list()
	for (var/i = 1, i < flat.len, i += 2)
		if (!isnum(flat[i]) || !isnum(flat[i + 1]))
			return FALSE
		of += list(list(round(flat[i]), round(flat[i + 1])))
	hull_name = istext(state["name"]) && length(state["name"]) ? state["name"] : hull_name
	dir = (state["dir"] in cardinal) ? state["dir"] : NORTH
	z = pivot.z
	px = pivot.x
	py = pivot.y
	set_offsets(of)
	set_afloat(TRUE)
	return TRUE
