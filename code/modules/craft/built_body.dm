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
// Nothing here is a turf template: the hull is whatever is built on its tiles
// when it moves. A roof built over her deck has its walkable upper face on the
// building level above (building_levels.dm); that upper deck sails with her,
// found again at every move by position over her own tiles, so nothing about
// it is saved and no field links one deck to the other. Her hold below the
// waterline sails the same way (naval/hull_hold.dm).
// ============================================================

#define BUILT_HULL_MAX_TILES 200
// Every tile of every deck is carried at each step, so her decks together have
// a cap of their own. Measured in tests/naval_carrier/upper_deck_probe.dm: a
// sailing step (plan and move) of 200 tiles of hull and 100 of upper deck with
// ten sailors and ten buckets aboard takes about 12 ms, and a bare 200-tile
// hull about 7.5 ms.
#define BUILT_HULL_MAX_DECK_TILES 300

/datum/craft_body/built
	var/hull_name = "hull"
	var/z = 0
	var/px = 0                    // The pivot: the tile the tiller stands on.
	var/py = 0
	var/dir = NORTH               // Where the bow points.
	var/list/offsets = list()     // list(dx, dy) from the pivot, one per tile.
	var/tmp/list/offset_index = list() // "dx,dy" -> TRUE, for contains().
	var/tmp/list/offset_box = null     // box(offsets), kept by set_offsets().
	// The plan can_move_to() just made, so the move_to() that follows it in
	// the same tick does not plan the same step twice.
	var/tmp/list/plan_memo = null
	var/tmp/plan_memo_key = null
	var/tmp/moving = FALSE
	glides = TRUE

/datum/craft_body/built/craft_name()
	return hull_name

/datum/craft_body/built/placed()
	return z > 0 && offsets.len > 0

/datum/craft_body/built/proc/set_offsets(list/new_offsets)
	plan_memo = null
	// A step without a turn keeps the same offsets: nothing to rebuild.
	if (new_offsets == offsets && offset_box && offset_index.len == offsets.len)
		return
	offsets = new_offsets
	offset_index = list()
	for (var/list/O in offsets)
		offset_index["[O[1]],[O[2]]"] = TRUE
	offset_box = null
	offset_box = box(offsets)

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

// The level her upper deck stands on, or 0 where the map has none above her.
/datum/craft_body/built/proc/upper_z()
	return placed() ? building_upper_z(z) : 0

// The tile above hull tile S when it is part of her upper deck: it holds the
// upper face of a roof built on S, or the top of a ladder that stands on S.
// A floor or ladder that belongs to anything else is not hers.
/datum/craft_body/built/proc/upper_deck_cell(turf/S, uz)
	if (!S || !uz)
		return null
	var/turf/U = locate(S.x, S.y, uz)
	if (!U || !building_open_turf(U))
		return null
	for (var/obj/covers/C in U)
		var/obj/roof/R = C.building_roof()
		if (R && R.loc == S)
			return U
	for (var/obj/structure/multiz/L in U)
		if (L.target && L.target.loc == S)
			return U
	return null

// Her upper deck: one entry per offset, the tile above it or null.
/datum/craft_body/built/proc/upper_cells(list/below = null)
	. = list()
	var/uz = upper_z()
	if (!below)
		below = cells()
	for (var/turf/S in below)
		. += upper_deck_cell(S, uz)

/datum/craft_body/built/proc/upper_tile_count()
	. = 0
	for (var/turf/U in upper_cells())
		.++

// The level her second deck above stands on, or 0 where there is none.
/datum/craft_body/built/proc/top_z()
	var/uz = upper_z()
	return uz ? building_upper_z(uz) : 0

// Her second deck above: one entry per entry of upper (her upper deck), the
// tile above it that holds the upper face of a roof built on her upper deck,
// or the top of a ladder that stands there; null where there is none.
/datum/craft_body/built/proc/top_cells(list/upper = null)
	. = list()
	var/tz = top_z()
	if (!upper)
		upper = upper_cells()
	for (var/i = 1, i <= upper.len, i++)
		. += upper_deck_cell(upper[i], tz)

/datum/craft_body/built/proc/top_tile_count()
	. = 0
	for (var/turf/T in top_cells())
		.++

// Everyone and everything aboard, on her deck, the deck above and her hold.
/datum/craft_body/built/aboard()
	. = ..()
	var/list/upper = upper_cells()
	for (var/turf/U in upper + top_cells(upper) + lower_cells())
		for (var/atom/movable/M in U)
			if (M.loc != U || QDELETED(M))
				continue
			if (!M.craft_cargo())
				continue
			. += M

// Why a tile of the building level cannot take a tile of her upper deck, or
// null. Only open air with nothing built or standing in it will do.
/datum/craft_body/built/proc/upper_tile_refusal(turf/D)
	return built_hull_upper_refusal(D)

// The same for any tile, so a ship built from a crossing record can ask it
// before she exists (naval/ship_crossing.dm).
/proc/built_hull_upper_refusal(turf/D)
	if (!D)
		return "the edge of the world"
	if (!building_open_turf(D))
		return "[D.name] above the deck at [D.x],[D.y]"
	for (var/obj/covers/C in D)
		if (C.loc == D)
			return "a floor in the way of her upper deck at [D.x],[D.y]"
	for (var/obj/structure/multiz/L in D)
		if (L.loc == D)
			return "a ladder in the way of her upper deck at [D.x],[D.y]"
	for (var/atom/movable/M in D)
		if (M.loc == D && M.density && !istype(M, /atom/movable/lighting_overlay))
			return "[M.name] in the way of her upper deck at [D.x],[D.y]"
	return null

// Why a tile of the level above cannot take the top of one of her masts, or
// null. Open air, or the edge of the levels, will do.
/datum/craft_body/built/proc/mast_tile_refusal(turf/D)
	if (!D)
		return null
	if (!building_open_turf(D))
		return "[D.name] over her mast at [D.x],[D.y]"
	for (var/obj/covers/C in D)
		if (C.loc == D)
			return "a floor over her mast at [D.x],[D.y]"
	for (var/atom/movable/M in D)
		if (M.loc == D && M.density && !istype(M, /atom/movable/lighting_overlay))
			return "[M.name] in the way of her mast at [D.x],[D.y]"
	return null

// The box around a set of offsets: list(min dx, min dy, max dx, max dy).
/datum/craft_body/built/proc/box(list/of)
	if (of == offsets && offset_box)
		return offset_box.Copy()
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
/datum/craft_body/built
	// Ground she may be hauled onto during one haul-out (turf = TRUE).
	var/tmp/list/ways_tiles = null

/datum/craft_body/built/proc/turned_offsets(heading)
	var/angle = craft_turn_angle(dir, heading)
	// Bow where she points already: the offsets themselves (never changed in
	// place; set_offsets() swaps in a new list).
	if (!angle)
		return offsets
	. = list()
	for (var/list/O in offsets)
		switch (angle)
			if (90) . += list(list(-O[2], O[1]))
			if (-90) . += list(list(O[2], -O[1]))
			if (180, -180) . += list(list(-O[1], -O[2]))
			else . += list(list(O[1], O[2]))

// Why a tile the hull does not already cover cannot take it, or null.
/datum/craft_body/built/proc/tile_refusal(turf/D)
	// Hauled up a slipway (slipway_haul.dm), she may come to rest on the
	// ground of its berth; she floats in a flooded dock basin (drydock.dm).
	// A flooded trench is a canal (canals.dm): she floats in it as a boat
	// does, and plan() keeps her to its levels.
	if (!istype(D, /turf/floor/beach/water) && !istype(D, /turf/floor/trench/flooded) && !(ways_tiles && ways_tiles[D]) && !dock_floats(D))
		return "[D.name] ahead at [D.x],[D.y]"
	// A turf lists what overlaps it by pixels too (a hull sailing by pixels,
	// vehicle_offset_hull.dm), so only a floor filed on D is in the way.
	for (var/obj/covers/C in D)
		if (C.loc == D)
			return "a built floor in the way at [D.x],[D.y]"
	if (vessel_at(D))
		return "another ship in the way at [D.x],[D.y]"
	for (var/atom/movable/M in D)
		if (M.loc == D && M.density && !istype(M, /atom/movable/lighting_overlay))
			return "[M.name] in the way at [D.x],[D.y]"
	return null

// A floor lifted from her hull leaves a hole that is still part of her shape
// until a refit cuts it away. When the tile refused is where that hole would
// go, the refusal says so: otherwise a crew that lifted a plank to clear an
// obstacle is told only of the obstacle. index is the offset's place in
// offsets (turned_offsets() keeps the order).
/datum/craft_body/built/proc/lifted_floor_hint(index)
	if (!craft || !craft.ledger || index < 1 || index > offsets.len)
		return ""
	var/list/O = offsets[index]
	var/turf/S = locate(px + O[1], py + O[2], z)
	if (!S || !craft.ledger.hole_at(S))
		return ""
	return ". The floor lifted at [S.x],[S.y] is still part of her hull: drop anchor and refit the hull at the tiller to cut it away"

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
	// Keyed, so a hull of n tiles plans in n lookups rather than n squared.
	var/list/mine_set = list()
	for (var/turf/T in mine)
		mine_set[T] = TRUE
	var/overhang = craft_overhang_refusal(mine)
	if (overhang)
		last_refusal = overhang
		return null
	var/list/dest = list()
	var/index = 0
	for (var/list/O in turned)
		index++
		var/turf/D = locate(nx + O[1], ny + O[2], z)
		if (!D)
			last_refusal = "the edge of the world"
			return null
		if (!mine_set[D])
			var/why = tile_refusal(D)
			if (!why)
				why = ice_refusal(D, mine_set) // ice_breaking.dm
			if (why)
				last_refusal = why + lifted_floor_hint(index)
				return null
		// Every tile of her keeps to the canal rule a boat keeps: no tile
		// crosses a step between canal levels, except through a pound lock
		// standing at the level of the water it opens to.
		var/list/S = offsets[index]
		var/turf/from = locate(px + S[1], py + S[2], z)
		if (canal_step_blocked(from, D))
			last_refusal = "a step in the canal at [D.x],[D.y]: work a pound lock to the level of her water"
			return null
		dest += D
	// Her upper deck must find open air above the tiles she moves to.
	var/list/upper = upper_cells(mine)
	var/list/upper_dest = list()
	var/uz = upper_z()
	var/list/upper_set = null
	for (var/i = 1, i <= upper.len, i++)
		var/turf/U = upper[i]
		if (!U)
			upper_dest += null
			continue
		if (!upper_set)
			upper_set = list()
			for (var/turf/O in upper)
				upper_set[O] = TRUE
		var/turf/D = dest[i]
		var/turf/UD = locate(D.x, D.y, uz)
		if (!UD || !upper_set[UD])
			var/why = upper_tile_refusal(UD)
			if (why)
				last_refusal = why
				return null
		upper_dest += UD
	// Her second deck above the same way, a level higher.
	var/list/top = top_cells(upper)
	var/list/top_dest = list()
	var/tz = top_z()
	var/list/top_set = null
	for (var/i = 1, i <= top.len, i++)
		var/turf/T = top[i]
		if (!T)
			top_dest += null
			continue
		if (!top_set)
			top_set = list()
			for (var/turf/O in top)
				top_set[O] = TRUE
		var/turf/D = dest[i]
		var/turf/TD = locate(D.x, D.y, tz)
		if (!TD || !top_set[TD])
			var/why = upper_tile_refusal(TD)
			if (why)
				last_refusal = why
				return null
		top_dest += TD
	// Her hold must find rock or deep water below the tiles she moves to.
	var/list/lower = lower_cells(mine)
	var/list/lower_dest = list()
	var/lz = lower_z()
	var/list/lower_set = null
	for (var/i = 1, i <= lower.len, i++)
		var/turf/L = lower[i]
		if (!L)
			lower_dest += null
			continue
		if (!lower_set)
			lower_set = list()
			for (var/turf/O in lower)
				lower_set[O] = TRUE
		var/turf/D = dest[i]
		var/turf/LD = locate(D.x, D.y, lz)
		if (!LD || !lower_set[LD])
			var/why = lower_tile_refusal(LD)
			if (why)
				last_refusal = why
				return null
		lower_dest += LD
	// A mast stands up through the level above her deck: where no deck of
	// hers is over it, the air there must be clear for her to pass, so a
	// bridge or a floor built over the water stops her masts.
	if (uz)
		for (var/i = 1, i <= mine.len, i++)
			if (upper[i])
				continue
			var/turf/T = mine[i]
			if (!(locate(/obj/structure/vehicleparts/movement/sail) in T))
				continue
			var/turf/D = dest[i]
			var/turf/MD = locate(D.x, D.y, uz)
			if (upper_set && upper_set[MD])
				continue
			var/why = mast_tile_refusal(MD)
			if (why)
				last_refusal = why
				return null
	var/upper_count = 0
	for (var/turf/U in upper + top)
		upper_count++
	var/lower_count = 0
	for (var/turf/L in lower)
		lower_count++
	if (upper_count + lower_count + offsets.len > BUILT_HULL_MAX_DECK_TILES)
		last_refusal = "her decks are too large to sail: [offsets.len] tiles of hull, [upper_count] of decks above and [lower_count] of hold, more than [BUILT_HULL_MAX_DECK_TILES] in all. Take down some of the roofs over her deck"
		return null
	// Her second deck above rides with her upper deck: it moves after it.
	return list(nx, ny, turned, dest, upper + top, upper_dest + top_dest, lower, lower_dest)

/datum/craft_body/built/move_cells(x, y, heading)
	var/list/P = plan(x, y, heading)
	return P ? P[4] : null

/datum/craft_body/built/can_move_to(x, y, heading)
	var/list/P = plan(x, y, heading)
	plan_memo = P
	plan_memo_key = P ? plan_key(x, y, heading) : null
	return !isnull(P)

// What a plan depends on: where she is, where she goes and when. A plan is
// reused only within the tick it was made: the sailing loop asks and moves in
// one call (next_hop() then move_to()), with nothing between.
/datum/craft_body/built/proc/plan_key(x, y, heading)
	return "[x],[y],[heading],[px],[py],[z],[dir],[offsets.len],[world.time]"

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
	var/list/P = null
	if (plan_memo && plan_memo_key == plan_key(x, y, heading))
		P = plan_memo
	plan_memo = null
	if (!P)
		P = plan(x, y, heading)
	if (!P)
		return FALSE
	var/list/old = list()
	for (var/list/O in offsets)
		old += locate(px + O[1], py + O[2], z)
	// Thin ice her armoured bow is cleared to enter breaks first (ice_breaking.dm).
	break_ice_ahead(P[4], old)
	var/list/dest = P[4]
	var/list/dest_set = list()
	for (var/turf/D in dest)
		dest_set[D] = TRUE
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
				if (!M.craft_cargo())
					continue
				// Floors first, so nobody reaches a tile before the floor
				// under them does (an airship's deck hangs over open air).
				if (istype(M, /obj/covers))
					riders.Insert(1, M)
				else
					riders += M
			cargo += list(riders)
			water[S] = true_water_level(S)
		for (var/turf/D in dest)
			if (isnull(water[D]))
				water[D] = D.water_level
		// What stands on her upper deck, tile by tile.
		var/list/upper_old = P[5]
		var/list/upper_new = P[6]
		var/list/upper_cargo = list()
		for (var/i = 1, i <= upper_old.len, i++)
			var/list/riders = list()
			var/turf/U = upper_old[i]
			if (U)
				for (var/atom/movable/M in U)
					if (M.loc != U || QDELETED(M))
						continue
					if (!M.craft_cargo())
						continue
					riders += M
			upper_cargo += list(riders)
		// What stands in her hold, tile by tile.
		var/list/lower_old = P[7]
		var/list/lower_new = P[8]
		var/list/lower_cargo = list()
		for (var/i = 1, i <= lower_old.len, i++)
			var/list/riders = list()
			var/turf/L = lower_old[i]
			if (L)
				for (var/atom/movable/M in L)
					if (M.loc != L || QDELETED(M))
						continue
					if (!M.craft_cargo())
						continue
					riders += M
			lower_cargo += list(riders)
		// A roof aboard makes the tiles under it indoors (roof_stuff.dm): the
		// areas of her tiles sail with her, and the sea's come back behind.
		// A roof on her upper deck does the same for the tiles of it.
		var/list/areas = built_hull_areas_before(cargo, old, dest)
		var/list/upper_areas = built_hull_areas_before(upper_cargo, upper_old, upper_new)
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
		for (var/list/riders in upper_cargo + lower_cargo)
			everything += riders
		// The rock ahead of her hold is hollowed before anyone steps into it.
		var/list/hold_origin = before_hold_move(lower_old, lower_new)
		carry = craft_rigid_begin(everything)
		// A turn is drawn swinging round (turn_swing.dm): the engine shows
		// the moves themselves at once, and the facings before it are kept.
		var/list/swing_dirs = null
		if (glides && angle)
			if (!glide_was)
				glide_was = list()
			swing_dirs = list()
			for (var/atom/movable/M in everything)
				if (QDELETED(M))
					continue
				swing_dirs[M] = M.dir
				if (craft_glides_natively(M))
					glide_hold(glide_was, M, world.icon_size)
		for (var/i = 1, i <= old.len, i++)
			var/turf/S = old[i]
			var/turf/D = dest[i]
			var/floored = FALSE
			for (var/atom/movable/M in cargo[i])
				if (QDELETED(M))
					continue
				if (S != D && M.loc == S)
					craft_step_move(M, D, D.x - S.x, D.y - S.y, gliding)
				if (istype(M, /obj/covers))
					var/obj/covers/C = M
					C.origin_water_level = water[D]
					floored = TRUE
			if (!floored)
				D.water_level = water[D]
		// The upper deck: floors and ladder tops first, so nobody standing up
		// there ever reaches a tile of open air with no floor under them.
		for (var/pass = 1, pass <= 2, pass++)
			for (var/i = 1, i <= upper_cargo.len, i++)
				var/turf/S = upper_old[i]
				var/turf/D = upper_new[i]
				if (!S || !D || S == D)
					continue
				for (var/atom/movable/M in upper_cargo[i])
					if (QDELETED(M) || M.loc != S)
						continue
					if ((pass == 1) != (istype(M, /obj/covers) || istype(M, /obj/structure/multiz)))
						continue
					craft_step_move(M, D, D.x - S.x, D.y - S.y, gliding)
		// The hold the same way, then the rock closes where it was.
		for (var/pass = 1, pass <= 2, pass++)
			for (var/i = 1, i <= lower_cargo.len, i++)
				var/turf/S = lower_old[i]
				var/turf/D = lower_new[i]
				if (!S || !D || S == D)
					continue
				for (var/atom/movable/M in lower_cargo[i])
					if (QDELETED(M) || M.loc != S)
						continue
					if ((pass == 1) != (istype(M, /obj/covers) || istype(M, /obj/structure/multiz)))
						continue
					craft_step_move(M, D, D.x - S.x, D.y - S.y, gliding)
		after_hold_move(lower_old, lower_new, hold_origin)
		built_hull_areas_after(areas)
		built_hull_areas_after(upper_areas)
		craft_rigid_settle(carry)
		carry = null
		glide_keep(gliding ? everything : null)
		// The water closes where she was.
		for (var/turf/S in old)
			if (dest_set[S])
				continue
			S.water_level = water[S]
			S.move_delay = initial(S.move_delay)
		px = P[1]
		py = P[2]
		dir = heading
		set_offsets(P[3])
		if (angle)
			for (var/list/riders in cargo + upper_cargo + lower_cargo)
				for (var/atom/movable/M in riders)
					if (!QDELETED(M))
						M.craft_turned(craft, angle)
		// A turn is shown swinging round, and a slide into a berth is drawn
		// for as long as its caller asked, instead of snapping (glide.dm).
		if (glides && !gliding && angle && slide_time <= 0)
			var/list/was_at = list()
			for (var/i = 1, i <= old.len, i++)
				built_hull_swing_from(was_at, cargo[i], old[i], dest[i])
			for (var/i = 1, i <= upper_cargo.len, i++)
				built_hull_swing_from(was_at, upper_cargo[i], upper_old[i], upper_new[i])
			for (var/i = 1, i <= lower_cargo.len, i++)
				built_hull_swing_from(was_at, lower_cargo[i], lower_old[i], lower_new[i])
			var/span = turn_swing_span(was_at)
			for (var/atom/movable/M in turn_swing_all(was_at, swing_dirs, angle, span))
				var/turf/S = was_at[M]
				if (!QDELETED(M) && isturf(M.loc) && S && M.z == S.z)
					glide_slide(M, M.x - S.x, M.y - S.y, glide_turn_time(), SINE_EASING)
			glide_rest(turn_swing_time(span))
		else if (glides && !gliding && (angle || slide_time > 0))
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
			for (var/i = 1, i <= upper_cargo.len, i++)
				var/turf/S = upper_old[i]
				var/turf/D = upper_new[i]
				if (!S || !D || S == D)
					continue
				for (var/atom/movable/M in upper_cargo[i])
					if (!QDELETED(M) && M.loc == D)
						glide_swing(glide_was, M, D.x - S.x, D.y - S.y, shown)
			for (var/i = 1, i <= lower_cargo.len, i++)
				var/turf/S = lower_old[i]
				var/turf/D = lower_new[i]
				if (!S || !D || S == D)
					continue
				for (var/atom/movable/M in lower_cargo[i])
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

// Adds each thing of riders that a turn carried from S to D to was_at (S is
// D on the tile she turns about).
/proc/built_hull_swing_from(list/was_at, list/riders, turf/S, turf/D)
	if (!S || !D)
		return
	for (var/atom/movable/M in riders)
		if (!QDELETED(M) && M.loc == D)
			was_at[M] = S

// The areas a move carries, taken before it: when a roof rides on one of the
// tiles in old, list(old tiles, new tiles, each old tile's area, the area of
// each new tile she did not already cover), else null. old and dest pair up
// by index and may hold nulls where a deck has no tile.
/proc/built_hull_areas_before(list/cargo, list/old, list/dest)
	var/roofed = FALSE
	for (var/list/riders in cargo)
		if (locate(/obj/roof) in riders)
			roofed = TRUE
			break
	if (!roofed)
		return null
	var/list/from = list()
	var/list/onto = list()
	for (var/i = 1, i <= old.len, i++)
		if (old[i] && dest[i])
			from += old[i]
			onto += dest[i]
	var/list/from_set = list()
	for (var/turf/S in from)
		from_set[S] = TRUE
	var/list/old_area = list()
	var/list/fresh_area = list()
	for (var/turf/S in from)
		old_area += S.loc
	for (var/turf/D in onto)
		if (!from_set[D])
			fresh_area += D.loc
	return list(from, onto, old_area, fresh_area)

// After the move: each new tile takes the area of the tile it came from, and
// each tile she left takes the area of the open tiles she moved onto.
/proc/built_hull_areas_after(list/state)
	if (!state)
		return
	var/list/from = state[1]
	var/list/onto = state[2]
	var/list/old_area = state[3]
	var/list/fresh_area = state[4]
	var/list/to_set = list()
	for (var/turf/D in onto)
		to_set[D] = TRUE
	var/list/changed = list()
	for (var/i = 1, i <= onto.len, i++)
		var/turf/D = onto[i]
		var/area/A = old_area[i]
		if (A && D.loc != A)
			A.contents += D
			changed += D
	var/k = 0
	for (var/turf/S in from)
		if (to_set[S])
			continue
		var/area/A = fresh_area[++k]
		if (A && S.loc != A)
			A.contents += S
			changed += S
	for (var/turf/T in changed)
		for (var/atom/movable/lighting_overlay/LO in T)
			LO.update_overlay()

// Turns about the pivot.
/datum/craft_body/built/turn_to(heading)
	if (heading == dir)
		return TRUE
	var/list/B = box(turned_offsets(heading))
	return move_to(px + B[1], py + B[2], heading)

// ---- Commissioning ----

// The tiles of the hull built around start: every water tile with a built
// floor on it that joins start edge to edge. At a berth (berth_build.dm) her
// floors may stand on the berth's ground as well. Returns the list of turfs,
// or a text saying why this is not a hull.
/proc/built_hull_survey(turf/start, datum/craft/refitting = null)
	if (!start || !hull_floor_in(start))
		return "It must stand on a floor built over water."
	var/obj/structure/berth = istype(start, /turf/floor/beach/water) ? null : berth_ground_at(start)
	if (!berth && !istype(start, /turf/floor/beach/water))
		return "It must stand on a floor built over water, or at a berth: a dock basin or the berth of an empty slipway."
	var/list/found = list(start)
	var/list/queue = list(start)
	while (queue.len)
		var/turf/T = queue[1]
		queue.Cut(1, 2)
		for (var/d in cardinal)
			var/turf/N = get_step(T, d)
			if (!N || (N in found) || !hull_floor_in(N))
				continue
			if (berth ? !berth.berth_ground(N) : !istype(N, /turf/floor/beach/water))
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
