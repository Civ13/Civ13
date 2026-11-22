// ============================================================
// Hauling a ship out on the slipway (docs/berths.md)
// ------------------------------------------------------------
// A built hull can come back up the ways she was launched down. Bring her to
// a stop off the foot of an empty slipway, her bow to the open water the way
// the post faces, and use the post: "Haul her out". One pair of hands at the
// post hauls up to SLIPWAY_HAUL_TILES tiles of hull; a horse or an ox counts
// as two. She is drawn up stern first until her stern lies on the tile in
// front of the post, about three seconds for every tile she moves, with
// everyone aboard riding along. Every tile she comes to rest on must be dry
// open ground.
//
// Hauled out, she is a berth's ship (berth.dm) that lies dry: the water runs
// out of her bilge, nothing seeps or fouls, and her bottom, seams and patches
// can all be worked on. "Launch her again" at the post slides her back down
// the ways to open water, as a new ship is launched.
//
// Nothing is saved for it: a hauled hull is found again from where she lies.
// ============================================================

#define SLIPWAY_HAUL_TILES 20 // tiles of hull one hand at the post hauls
#define SLIPWAY_HAUL_TIME 30  // deciseconds for each tile she is hauled
#define SLIPWAY_HAUL_REACH 12 // tiles off the foot of the ways she may lie

// TRUE for dry open ground a hauled hull can rest on.
/proc/slipway_haul_ground(turf/T)
	return T && slipway_ground(T) && !istype(T, /turf/floor/beach/water) && !istype(T, /turf/floor/trench/flooded)

// How far along the ways T lies: 1 is the tile in front of the post.
/obj/structure/slipway/proc/ways_along(turf/T)
	var/list/W = ways_step()
	return (T.x - x) * W[1] + (T.y - y) * W[2]

// How far T lies to the side of the post's line.
/obj/structure/slipway/proc/ways_aside(turf/T)
	var/list/W = ways_step()
	return (T.x - x) * -W[2] + (T.y - y) * W[1]

// ---- The berth ----

// The slipway holds a hull hauled out on its berth: every tile on dry ground,
// her bow to the water, her stern on the tile in front of the post.
/obj/structure/slipway/berth_holds(datum/craft/C, list/cells)
	var/datum/craft_body/built/B = C ? C.body : null
	if (!istype(B) || !cells || !cells.len || design || B.dir != dir)
		return FALSE
	var/stern = FALSE
	for (var/turf/T in cells)
		if (T.z != z || !slipway_haul_ground(T))
			return FALSE
		if (ways_along(T) == 1 && ways_aside(T) == 0)
			stern = TRUE
	return stern

/obj/structure/slipway/berth_dry(datum/craft/C)
	return TRUE

// The hull hauled out on this berth, or null.
/obj/structure/slipway/proc/hauled_hull()
	if (!isturf(loc))
		return null
	var/list/W = ways_step()
	var/datum/craft/C = craft_at(locate(x + W[1], y + W[2], z))
	if (C && C.ledger && berth_holds(C, C.body.cells()))
		return C
	return null

// The built hull lying in the water off the foot of the ways, or null.
/obj/structure/slipway/proc/hull_off_ways()
	if (!isturf(loc))
		return null
	var/list/W = ways_step()
	for (var/k = 1, k <= SLIPWAY_HAUL_REACH + 1, k++)
		var/turf/T = locate(x + W[1] * k, y + W[2] * k, z)
		if (!T)
			return null
		var/datum/craft/C = craft_at(T)
		if (C && C.ledger)
			return C
	return null

// Hands at the post to haul C: people and draught animals within two tiles,
// on their feet and not aboard her.
/obj/structure/slipway/proc/haul_hands(datum/craft/C)
	. = 0
	for (var/mob/living/M in range(2, src))
		if (M.stat || M.lying)
			continue
		var/turf/T = get_turf(M)
		if (C && C.body && C.body.contains(T))
			continue
		if (ishuman(M))
			. += 1
		else if (istype(M, /mob/living/simple_animal/horse) || istype(M, /mob/living/simple_animal/cattle))
			. += 2

// Hands it takes to haul C.
/proc/slipway_hands_needed(datum/craft/C)
	return max(1, CEILING(C.ledger.tiles / SLIPWAY_HAUL_TILES, 1))

// How many tiles C is hauled to bring her stern to the post: -1 when she is
// not lying off the ways.
/obj/structure/slipway/proc/haul_distance(datum/craft/C)
	var/least = null
	for (var/turf/T in C.body.cells())
		var/t = ways_along(T)
		if (isnull(least) || t < least)
			least = t
	return isnull(least) ? -1 : least - 1

// Why C cannot be hauled out here now, or null. Fills dest with the tiles
// she will rest on when she can.
/obj/structure/slipway/proc/haul_refusal(datum/craft/C, list/dest = null)
	if (!C || !C.ledger || !C.body)
		return "There is no ship off the ways to haul out."
	if (design)
		return "A [design] is being built on the berth: finish or abandon her first."
	if (C.ledger.under_way())
		return "Bring the [C.name] to a stop first."
	if (C.grapple)
		return "The [C.name] is grappled to another ship."
	var/datum/craft_body/built/B = C.body
	if (!istype(B))
		return "Only a hull you built can be hauled up the ways."
	if (B.dir != dir)
		return "The [C.name] must lie with her bow to the open water, [dir2text(dir)], to come up the ways stern first."
	var/k = haul_distance(C)
	if (k < 1)
		return "The [C.name] is already on the ways."
	if (k > SLIPWAY_HAUL_REACH)
		return "The [C.name] lies too far off: bring her stern within [SLIPWAY_HAUL_REACH] tiles of the foot of the ways."
	var/list/W = ways_step()
	var/list/mine = list()
	for (var/turf/T in C.body.cells())
		mine[T] = TRUE
	var/found_stern = FALSE
	for (var/turf/T in mine)
		var/turf/D = locate(T.x - W[1] * k, T.y - W[2] * k, z)
		if (!slipway_haul_ground(D))
			return "The berth must be dry open ground wherever she will lie: [D ? "[D.name] at [D.x],[D.y]" : "the edge of the world"] is not."
		if (ways_along(D) == 1 && ways_aside(D) == 0)
			found_stern = TRUE
		// Every tile she slides over on the way up must be clear.
		for (var/step = 1, step <= k, step++)
			var/turf/S = locate(T.x - W[1] * step, T.y - W[2] * step, z)
			if (!S || mine[S])
				continue
			if (slipway_dense_in(S))
				return "Something solid is in the way up the ways at [S.x],[S.y]."
			if (hull_floor_in(S) || vessel_at(S) || (craft_at(S) && craft_at(S) != C))
				return "Another floor or ship is in the way up the ways at [S.x],[S.y]."
		if (dest)
			dest[D] = TRUE
	if (!found_stern)
		return "Her stern must come up the middle of the ways, in line with the post."
	var/need = slipway_hands_needed(C)
	var/have = haul_hands(C)
	if (have < need)
		return "The [C.name] has [C.ledger.tiles] tiles of hull: it takes [need] pair[need == 1 ? "" : "s"] of hands at the post to haul her (a horse or an ox counts as two), and there [have == 1 ? "is" : "are"] [have]."
	return null

// Hauls C up the ways. Returns null when done, else the reason.
/obj/structure/slipway/proc/haul_out(datum/craft/C)
	var/list/dest = list()
	var/why = haul_refusal(C, dest)
	if (why)
		return why
	var/datum/craft_body/built/B = C.body
	var/list/W = ways_step()
	var/k = haul_distance(C)
	var/list/box = B.box(B.offsets)
	B.ways_tiles = dest
	B.slide_time = glide_dock_time(k)
	var/moved = B.move_to(B.px + box[1] - W[1] * k, B.py + box[2] - W[2] * k, dir)
	B.slide_time = 0
	B.ways_tiles = null
	if (!moved)
		return "She would not come up the ways: [B.last_refusal]."
	C.set_speed(VESSEL_SPEED_STOP)
	C.set_anchor(TRUE)
	var/datum/hull_ledger/L = C.ledger
	L.water = 0
	L.grounded = FALSE
	L.stop_sinking()
	L.depth_told = HULL_DEPTH_DRY
	visible_message(SPAN_NOTICE("The [C.name] is hauled up the ways and lies dry on the berth, the water running out of her."))
	return null

// Slides a hauled hull back down the ways. Returns null when done, else
// the reason.
/obj/structure/slipway/proc/relaunch(datum/craft/C)
	if (!C || C != hauled_hull())
		return "No ship is hauled out here."
	var/datum/craft_body/built/B = C.body
	var/list/cells = B.cells()
	var/k = draught_landing(cells, B.length_tiles())
	if (k < 0)
		return "There is no open water for her [dir2text(dir)] of the slipway within reach of the ways."
	var/list/W = ways_step()
	var/list/mine = list()
	for (var/turf/T in cells)
		mine[T] = TRUE
	for (var/step = 1, step < k, step++)
		for (var/turf/T in cells)
			var/turf/D = locate(T.x + W[1] * step, T.y + W[2] * step, z)
			if (!D || mine[D])
				continue
			if (slipway_dense_in(D) || (istype(D, /turf/floor/trench) && !istype(D, /turf/floor/trench/flooded)))
				return "[capitalize(D.name)] at [D.x],[D.y] is in the way down the ways."
	var/list/box = B.box(B.offsets)
	B.slide_time = glide_dock_time(k)
	var/moved = B.move_to(B.px + box[1] + W[1] * k, B.py + box[2] + W[2] * k, dir)
	B.slide_time = 0
	if (!moved)
		return "The launch failed: [B.last_refusal]."
	visible_message(SPAN_NOTICE("The [C.name] slides back down the ways and into the water with a great splash!"))
	return null

// The post's menu for a hauled hull or one off the ways. TRUE when the
// action was one of these.
/obj/structure/slipway/proc/haul_action(mob/living/human/H, action)
	switch (action)
		if ("survey")
			var/datum/craft/C = hauled_hull()
			if (C)
				to_chat(H, SPAN_NOTICE(C.ledger.berth_condition_text()))
			return TRUE
		if ("relaunch")
			var/datum/craft/C = hauled_hull()
			var/why = relaunch(C)
			if (why)
				to_chat(H, SPAN_WARNING(why))
			else
				log_game("[key_name(H)] relaunched the [C.name] from [src] at [x],[y],[z].")
			return TRUE
		if ("haul")
			var/datum/craft/C = hull_off_ways()
			var/why = haul_refusal(C)
			if (why)
				to_chat(H, SPAN_WARNING(why))
				return TRUE
			busy = TRUE
			H.visible_message(SPAN_NOTICE("[H] sets the hands at the post to haul the [C.name] up the ways."), SPAN_NOTICE("You set the hands to haul the [C.name] up the ways."))
			var/ok = do_after(H, yard_time(src, SLIPWAY_HAUL_TIME * haul_distance(C)), src)
			busy = FALSE
			if (!ok || QDELETED(src) || QDELETED(C) || !Adjacent(H))
				return TRUE
			why = haul_out(C)
			if (why)
				to_chat(H, SPAN_WARNING(why))
			else
				log_game("[key_name(H)] hauled the [C.name] out at [src] at [x],[y],[z].")
			return TRUE
	return FALSE

// Adds the haul-out choices to the post's menu. Returns TRUE when a hull is
// hauled out, so nothing else is offered.
/obj/structure/slipway/proc/haul_options(list/options)
	var/datum/craft/C = hauled_hull()
	if (C)
		options["Launch the [C.name] again"] = "relaunch"
		options["Survey her condition"] = "survey"
		return TRUE
	if (!design)
		C = hull_off_ways()
		if (C)
			options["Haul the [C.name] out"] = "haul"
	return FALSE

#undef SLIPWAY_HAUL_TILES
#undef SLIPWAY_HAUL_TIME
#undef SLIPWAY_HAUL_REACH
