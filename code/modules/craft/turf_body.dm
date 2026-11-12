// ============================================================
// Turf bodies (docs/craft-core.md): a hull made of the map itself
// ------------------------------------------------------------
// Some crafts are not floors laid over water but walls and floors that are
// turfs: a spacecraft is habitat modules. A turf body is the set of tiles
// such a hull stands on, kept as offsets from a pivot. A move takes the kind
// of every tile and everything standing on it to the matching tile of the
// new place, on this level or another, and leaves open_turf behind.
//
// The body keeps no template. The hull is whatever its tiles are when it
// moves, so what the crew build aboard goes with it. It does not turn: a
// wall has no facing to carry, and what is aboard keeps its own.
//
// Every level a turf body moves between shares one area, so areas are left
// alone.
// ============================================================

/datum/craft_body/turfs
	var/hull_name = "hull"
	var/z = 0
	var/px = 0                    // The pivot.
	var/py = 0
	var/list/offsets = list()     // list(dx, dy) from the pivot, one per tile.
	var/tmp/list/offset_index = list() // "dx,dy" -> TRUE, for contains().
	var/tmp/moving = FALSE
	var/open_turf = null          // What she stands in and leaves behind her.

/datum/craft_body/turfs/craft_name()
	return hull_name

/datum/craft_body/turfs/placed()
	return z > 0 && offsets.len > 0

/datum/craft_body/turfs/proc/set_offsets(list/new_offsets)
	offsets = new_offsets
	offset_index = list()
	for (var/list/O in offsets)
		offset_index["[O[1]],[O[2]]"] = TRUE

/datum/craft_body/turfs/cells()
	. = list()
	if (!placed())
		return
	for (var/list/O in offsets)
		var/turf/T = locate(px + O[1], py + O[2], z)
		if (T)
			. += T

/datum/craft_body/turfs/tile_count()
	return offsets.len

/datum/craft_body/turfs/contains(turf/T)
	return T && placed() && T.z == z && offset_index["[T.x - px],[T.y - py]"]

// The box around the hull: list(min dx, min dy, max dx, max dy).
/datum/craft_body/turfs/proc/box()
	. = list(0, 0, 0, 0)
	var/first = TRUE
	for (var/list/O in offsets)
		if (first)
			. = list(O[1], O[2], O[1], O[2])
			first = FALSE
			continue
		.[1] = min(.[1], O[1])
		.[2] = min(.[2], O[2])
		.[3] = max(.[3], O[1])
		.[4] = max(.[4], O[2])

/datum/craft_body/turfs/origin()
	if (!placed())
		return null
	var/list/B = box()
	return locate(px + B[1], py + B[2], z)

/datum/craft_body/turfs/length_tiles()
	var/list/B = box()
	return B[4] - B[2] + 1

/datum/craft_body/turfs/beam_tiles()
	var/list/B = box()
	return B[3] - B[1] + 1

// Why the hull cannot move at all now, or null. Subtypes add their reasons.
/datum/craft_body/turfs/proc/ready_refusal()
	if (!placed())
		return "she has no hull"
	return null

// Why a tile the hull does not already cover cannot take it, or null.
/datum/craft_body/turfs/proc/tile_refusal(turf/D)
	return blocker(D)

// What stands in a tile that is not open space, as a reason, or null.
/datum/craft_body/turfs/proc/blocker(turf/D)
	if (open_turf && D.type != open_turf)
		return "[D.name] in the way at [D.x],[D.y]"
	for (var/atom/movable/M in D)
		if (M.loc != D || istype(M, /atom/movable/lighting_overlay) || istype(M, /atom/movable/lighting_fullbright) || isobserver(M))
			continue
		if (M.density || isliving(M) || istype(M, /obj/structure))
			return "[M.name] in the way at [D.x],[D.y]"
	return null

// Plans a move that puts the box corner at (x, y) on a level. Returns
// list(new px, new py, destination turfs in offset order), or null with
// last_refusal set. Writes nothing.
/datum/craft_body/turfs/proc/plan(x, y, level)
	var/why = ready_refusal()
	if (why)
		last_refusal = why
		return null
	var/list/B = box()
	var/nx = x - B[1]
	var/ny = y - B[2]
	var/list/dest = list()
	for (var/list/O in offsets)
		var/turf/D = locate(nx + O[1], ny + O[2], level)
		if (!D)
			last_refusal = "the edge of the world"
			return null
		if (!(level == z && offset_index["[D.x - px],[D.y - py]"]))
			why = tile_refusal(D)
			if (why)
				last_refusal = why
				return null
		dest += D
	return list(nx, ny, dest)

/datum/craft_body/turfs/can_move_to(x, y, heading)
	return !isnull(plan(x, y, z))

/datum/craft_body/turfs/move_to(x, y, heading)
	return shift(x, y, z)

/datum/craft_body/turfs/turn_to(heading)
	last_refusal = "she keeps the attitude she was built in"
	return FALSE

// Moves the hull so its box corner lies at (x, y) on a level.
/datum/craft_body/turfs/proc/shift(x, y, level)
	if (moving)
		last_refusal = "already moving"
		return FALSE
	// Never rewrite a level while the world save is capturing it.
	if (persistence_save_in_progress)
		last_refusal = "the world is being saved"
		return FALSE
	var/started = world.timeofday
	var/list/P = plan(x, y, level)
	if (!P)
		return FALSE
	var/list/old = list()
	for (var/list/O in offsets)
		old += locate(px + O[1], py + O[2], z)
	var/list/dest = P[3]
	var/turf/old_origin = origin()
	moving = TRUE
	var/list/carry = null
	// A step of one tile on her own level is shown as a glide (glide.dm).
	var/gliding = (glide_time > 0 && level == z && abs(P[1] - px) + abs(P[2] - py) == 1) ? glide_time : 0
	var/step_x = P[1] - px
	var/step_y = P[2] - py
	try
		// What every tile is and what stands on it, before anything changes.
		var/list/kinds = list()
		var/list/facings = list()
		var/list/cargo = list()
		var/list/everything = list()
		for (var/turf/S in old)
			kinds += S.type
			facings += S.dir
			var/list/riders = list()
			for (var/atom/movable/M in S)
				if (M.loc != S || QDELETED(M) || isobserver(M))
					continue
				if (istype(M, /atom/movable/lighting_overlay) || istype(M, /atom/movable/lighting_fullbright))
					continue
				riders += M
			cargo += list(riders)
			everything += riders
		// The hull is there before anyone steps onto it.
		for (var/i = 1, i <= dest.len, i++)
			var/turf/D = dest[i]
			D.ChangeTurf(kinds[i], FALSE, FALSE)
			if (D.dir != facings[i])
				D.set_dir(facings[i])
		// Wiring aboard keeps its links while she carries it (rigid_move.dm).
		carry = craft_rigid_begin(everything)
		for (var/i = 1, i <= old.len, i++)
			var/turf/S = old[i]
			var/turf/D = dest[i]
			if (S == D)
				continue
			for (var/atom/movable/M in cargo[i])
				if (!QDELETED(M) && M.loc == S)
					M.forceMove(D)
					if (gliding && M.loc == D)
						craft_glide(M, step_x, step_y, gliding)
		craft_rigid_settle(carry)
		carry = null
		glide_keep(gliding ? everything : null)
		// Her tiles are drawn where they were and slid into place with her.
		if (gliding)
			for (var/turf/D in dest)
				glide_slide(D, step_x, step_y, gliding)
		// Open space closes where she was.
		if (open_turf)
			for (var/turf/S in old)
				if (!(S in dest))
					S.ChangeTurf(open_turf, FALSE, FALSE)
		px = P[1]
		py = P[2]
		z = level
	catch (var/exception/e)
		moving = FALSE
		craft_rigid_settle(carry)
		throw e
	moving = FALSE
	last_move_ms = (world.timeofday - started) * 100
	if (craft)
		craft.on_hop(old_origin)
	return TRUE
