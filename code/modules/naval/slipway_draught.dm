// ============================================================
// Building a ship's draught on the slipway (docs/ship-draught.md)
// ------------------------------------------------------------
// Use a ship's draught (ship_draught.dm) on an empty slipway post and the ship
// drawn on it is laid out on the berth in front of the post: her stern row on
// the tile before the post, her middle column on the post's line, her bow
// running the way the post faces. A ghost outline marks every tile to build.
//
// She is built piece by piece like the schooner, but each piece is one real
// thing on the berth: first her floors from stern to bow, then her fittings
// one kind at a time (helm, masts, benches, anchors, walls...). Each piece
// costs what building it by hand costs, and the floor or fitting appears as
// soon as it is paid for. Several shipwrights can work on her at once, each
// fitting the next piece in turn, and a worker keeps going while the stack in
// hand still pays for the next one.
//
// The deck above is not built on the slipway: it is laid by hand once she is
// afloat, as on any built hull.
//
// The post keeps the draught as its design code (draught_code) beside the
// usual pieces_done and paid, so a half-built ship saves with the post. What
// is already built is ordinary floors and fittings that save on their own.
//
// When the last piece is fitted she is launched from the post: she slides
// down the ways along the post's facing until every tile of her floats on
// open water, carrying everyone aboard, and her tiller commissions her as a
// built hull under the name on her draught. The berth must have that water
// ahead of it before she is laid out.
// ============================================================

#define SLIPWAY_FLOOR_TIME 30 // ticks to lay one floor tile
#define SLIPWAY_FIT_TIME 50   // ticks to set one fitting
#define SLIPWAY_DRAUGHT_RUN 12 // tiles she may slide past her own length to float

// A ship's draught as a piece plan: one piece per floor tile, then one per
// fitting, then one per gunwale. order[i] is list(sheet key "x,y", "floor",
// the piece key or "gunwale"); a gunwale's entry adds its sheet direction.
/datum/slipway_design/draught
	name = "ship"
	var/datum/ship_draught/draught
	var/list/order = list()
	var/list/floor_index = list() // sheet key -> piece index of its floor
	var/list/piece_index = list() // sheet key -> piece index of its fitting
	var/list/gunwale_index = list() // sheet key -> piece index of its last gunwale

/datum/slipway_design/draught/Destroy()
	if (draught)
		qdel(draught)
		draught = null
	return ..()

/datum/slipway_design/draught/progress_text(done, list/paid)
	var/list/next = next_piece(done)
	if (!next)
		return null
	var/list/stage = stages[next[1]]
	return "Building the [name] from her draught: [done] of [total_pieces()] pieces fitted. Stage [next[1]] of [stages.len], [stage["name"]]: the next [stage["verb"]] ([next[2]] of [stage["pieces"]]) needs [piece_cost_text(still_needed(done, paid))]."

// The plan for building draught D. The plan keeps D.
/proc/slipway_draught_plan(datum/ship_draught/D)
	var/datum/slipway_design/draught/P = new
	P.name = D.name
	P.draught = D
	P.blurb = "[D.hull_tiles()] tiles of hull drawn on a ship's draught"
	var/list/B = D.extent()
	if (!B)
		return P
	// Her tiles from stern (the bottom of the sheet) to bow.
	var/list/keys = list()
	for (var/y = B[2], y <= B[4], y++)
		for (var/x = B[1], x <= B[3], x++)
			if (D.cell(x, y))
				keys += "[x],[y]"
	for (var/floor in ship_draught_floors)
		var/list/F = ship_draught_floors[floor]
		var/n = 0
		for (var/key in keys)
			var/list/C = D.cells[key]
			if (C[1] == floor)
				P.order += list(list(key, "floor"))
				P.floor_index[key] = P.order.len
				n++
		if (n)
			P.stages += list(list("name" = slipway_draught_plural(F["name"]), "pieces" = n, "cost" = F["cost"], "part" = "floor", "verb" = F["name"]))
	for (var/piece in ship_draught_pieces)
		var/list/F = ship_draught_pieces[piece]
		var/n = 0
		for (var/key in keys)
			var/list/C = D.cells[key]
			if (C[2] == piece)
				P.order += list(list(key, piece))
				P.piece_index[key] = P.order.len
				n++
		if (n)
			P.stages += list(list("name" = slipway_draught_plural(F["name"]), "pieces" = n, "cost" = F["cost"], "part" = "fitting", "verb" = F["name"]))
	// Last her gunwales along every open side (docs/ship-edges.md), stern to bow.
	var/list/sides = D.gunwale_sides()
	for (var/floor in list("w", "s"))
		var/n = 0
		for (var/key in keys)
			var/list/C = D.cells[key]
			if (C[1] != floor)
				continue
			for (var/list/side in sides)
				if (side[1] == key)
					P.order += list(list(key, "gunwale", side[2]))
					P.gunwale_index[key] = P.order.len
					n++
		if (n)
			var/what = floor == "s" ? "steel bulwark" : "wooden gunwale"
			var/list/cost = list()
			cost[floor == "s" ? "steel" : "wood"] = 2
			P.stages += list(list("name" = slipway_draught_plural(what), "pieces" = n, "cost" = cost, "part" = "gunwale", "verb" = what))
	return P

// "Rowing benches", "Killicks": a stage's name from what it builds.
/proc/slipway_draught_plural(text)
	var/end = copytext(text, -2)
	return capitalize(text) + ((end == "ch" || end == "sh" || copytext(text, -1) == "s") ? "es" : "s")

// An offset on the sheet (x across, y towards the bow) as it lies on the
// ground with her bow to heading.
/proc/slipway_draught_turn(ox, oy, heading)
	switch (heading)
		if (EAST)
			return list(oy, -ox)
		if (SOUTH)
			return list(-ox, -oy)
		if (WEST)
			return list(-oy, ox)
	return list(ox, oy)

// ---- The post ----

/obj/structure/slipway
	var/draught_code = ""           // the ship's draught being built, as its design code
	var/tmp/datum/slipway_design/draught/draught_cache
	var/tmp/list/working = list()   // shipwrights at work on her now

// The plan for the draught being built, made once per code.
/obj/structure/slipway/proc/draught_plan()
	if (!draught_code)
		return null
	if (draught_cache && draught_cache.draught && draught_cache.draught.to_code() == draught_code)
		return draught_cache
	if (draught_cache)
		qdel(draught_cache)
		draught_cache = null
	var/datum/ship_draught/D = ship_draught_from_code(draught_code)
	if (!D)
		return null
	draught_cache = slipway_draught_plan(D)
	return draught_cache

// The tile of the berth under sheet tile (x, y) of D, or null off the map.
/obj/structure/slipway/proc/draught_turf(datum/ship_draught/D, x, y)
	var/turf/front = get_step(src, dir)
	var/list/B = D.extent()
	if (!front || !B)
		return null
	var/list/R = slipway_draught_turn(x - round((B[1] + B[3]) / 2), y - B[2], dir)
	return locate(front.x + R[1], front.y + R[2], z)

// The berth for D: turf -> sheet key. Null when any tile is off the map.
/obj/structure/slipway/proc/draught_berth(datum/ship_draught/D)
	. = list()
	for (var/key in D.cells)
		var/list/xy = splittext(key, ",")
		var/turf/T = draught_turf(D, text2num(xy[1]), text2num(xy[2]))
		if (!T)
			return null
		.[T] = key

// A piece's facing on the sheet as it stands on the berth.
/obj/structure/slipway/proc/draught_dir(sheet_dir)
	return (sheet_dir in cardinal) ? turn(sheet_dir, craft_turn_angle(NORTH, dir)) : dir

// Why draught D could not be laid out here, or null.
/obj/structure/slipway/proc/draught_refusal(datum/ship_draught/D)
	if (!isturf(loc))
		return "The slipway must stand on the ground."
	if (design)
		return "The [design] is already on the berth."
	if (!D)
		return "The sheet is blank."
	var/list/P = D.problems()
	if (P.len)
		return "The [D.name] cannot be built as drawn: [jointext(P, " ")]"
	var/list/berth = draught_berth(D)
	if (!berth)
		return "The [D.name] runs off the edge of the world [dir2text(dir)] of the slipway."
	for (var/turf/T in berth)
		if (!slipway_ground(T))
			return "The berth must be open ground, trench or water: [T.name] at [T.x],[T.y] is in the way."
		if (vessel_at(T))
			return "A ship lies on the berth."
		for (var/atom/movable/M in T)
			if (M.loc != T || !M.simulated || isliving(M))
				continue
			if (istype(M, /obj/structure/slipway_frame))
				return "Another ship is being built across this berth."
			if (istype(M, /obj/covers))
				return "\The [M] at [T.x],[T.y] already floors part of the berth."
			if (M.density)
				return "\The [M] is in the way on the berth at [T.x],[T.y]."
	if (draught_landing(berth, draught_length(D)) < 0)
		return "There is no open water for the [D.name] within [draught_length(D) + SLIPWAY_DRAUGHT_RUN] tiles [dir2text(dir)] of the slipway. Face the slipway to the water with a wrench."
	return null

/obj/structure/slipway/proc/lay_draught(datum/ship_draught/D)
	draught_code = D.to_code()
	design = D.name
	pieces_done = 0
	paid = list()
	update_frames()

// Using a ship's draught on an empty post lays her out on the berth.
/obj/structure/slipway/proc/offer_draught(mob/living/human/H, obj/item/ship_draught/S)
	if (!istype(H) || busy || !Adjacent(H))
		return
	var/datum/ship_draught/D = S.draught()
	var/refusal = draught_refusal(D)
	if (refusal)
		to_chat(H, SPAN_WARNING(refusal))
		if (D)
			qdel(D)
		return
	var/datum/slipway_design/draught/P = slipway_draught_plan(D)
	var/upper = D.upper_tiles()
	var/text = "Lay out the [D.name] on the berth? Her stern goes before the post and her bow runs [dir2text(dir)]. She takes [P.total_pieces()] pieces: [piece_cost_text(P.total_cost())] in all.[upper ? " Her [upper] tiles of deck above are laid by hand once she is afloat." : ""]"
	qdel(P) // also deletes D
	if (WWinput(H, text, name, "No", list("Yes", "No")) != "Yes" || QDELETED(S) || S.loc != H || !Adjacent(H))
		return
	D = S.draught()
	refusal = draught_refusal(D)
	if (refusal)
		to_chat(H, SPAN_WARNING(refusal))
		if (D)
			qdel(D)
		return
	lay_draught(D)
	log_game("[key_name(H)] laid out the ship's draught [D.name] ([D.hull_tiles()] tiles) on [src] at [x],[y],[z].")
	to_chat(H, SPAN_NOTICE("You pin the draught to the post and mark the [D.name] out on the berth. [status_text()] Bring the materials to the post or to any marked tile; more hands build her faster."))
	qdel(D)

// Builds piece index i of the draught on the berth.
/obj/structure/slipway/proc/draught_place(datum/slipway_design/draught/P, i)
	if (!P || i < 1 || i > P.order.len)
		return null
	var/list/entry = P.order[i]
	var/list/C = P.draught.cells[entry[1]]
	var/list/xy = splittext(entry[1], ",")
	var/turf/T = draught_turf(P.draught, text2num(xy[1]), text2num(xy[2]))
	if (!T)
		return null
	var/path
	if (entry[2] == "gunwale")
		path = C[1] == "s" ? /obj/structure/railing/built/gunwale/bulwark : /obj/structure/railing/built/gunwale
		var/obj/structure/railing/R = new path(T)
		R.set_dir(draught_dir(entry[3]))
		refresh_draught_tile(P, T, entry[1])
		return R
	if (entry[2] == "floor")
		var/list/F = ship_draught_floors[C[1]]
		path = F["path"]
	else
		var/list/F = ship_draught_pieces[entry[2]]
		path = F["path"]
	var/atom/movable/M = new path(T)
	if (entry[2] != "floor")
		M.set_dir(draught_dir(C[3]))
	refresh_draught_tile(P, T, entry[1])
	return M

// A shipwright brings materials to the berth: they fit the next piece and
// keep on while the stack in hand pays for the next. Others may work beside them.
/obj/structure/slipway/proc/add_draught_piece(mob/living/human/H, obj/item/stack/S, atom/target)
	var/datum/slipway_design/draught/P = draught_plan()
	if (!P)
		return TRUE
	if (H in working)
		to_chat(H, SPAN_WARNING("You are already at work on the [P.name]."))
		return TRUE
	var/code = draught_code
	var/fitted = 0
	working += H
	while (TRUE)
		var/list/next = P.next_piece(pieces_done)
		if (!next)
			if (!fitted)
				to_chat(H, SPAN_NOTICE("The [P.name] is finished on the berth."))
			break
		var/key = piece_material(S)
		var/list/needed = still_needed()
		if (!key || !needed[key])
			to_chat(H, fitted ? SPAN_NOTICE(status_text()) : SPAN_WARNING("The next piece needs [piece_cost_text(needed)], not [S.name]."))
			break
		var/list/stage = P.stages[next[1]]
		if (!fitted)
			to_chat(H, SPAN_NOTICE("You start work on the [stage["verb"]]..."))
		if (!do_after(H, stage["part"] == "fitting" ? SLIPWAY_FIT_TIME : SLIPWAY_FLOOR_TIME, target || src) || QDELETED(src) || QDELETED(S) || draught_code != code || S.loc != H)
			break
		var/before = pieces_done
		var/took = pay(S)
		if (!took)
			break
		if (pieces_done == before)
			to_chat(H, SPAN_NOTICE("You set out [took] [key] for the next piece; it still needs [piece_cost_text(still_needed())]."))
			break
		fitted += pieces_done - before
	working -= H
	if (fitted)
		log_game("[key_name(H)] fitted [fitted] piece\s of the [P.name] at [x],[y],[z] ([pieces_done]/[P.total_pieces()]).")
		H.visible_message(SPAN_NOTICE("[H] works on the [P.name]."), SPAN_NOTICE("You fit [fitted] piece\s. [status_text()]"))
	return TRUE

// ---- The launch ----

// Her length from stern to bow, in tiles.
/proc/draught_length(datum/ship_draught/D)
	var/list/B = D.extent()
	return B ? B[4] - B[2] + 1 : 0

// One tile along the ways: list(dx, dy).
/obj/structure/slipway/proc/ways_step()
	switch (dir)
		if (EAST)
			return list(1, 0)
		if (WEST)
			return list(-1, 0)
		if (SOUTH)
			return list(0, -1)
	return list(0, 1)

// The slide, in tiles, that puts every tile of the berth on open water with
// nothing in the way and no other floor alongside; -1 when there is none.
/obj/structure/slipway/proc/draught_landing(list/berth, length)
	var/list/W = ways_step()
	var/list/hull = list()
	for (var/turf/T in berth)
		hull[T] = TRUE
	for (var/k = 1, k <= length + SLIPWAY_DRAUGHT_RUN, k++)
		var/list/dest = list()
		var/ok = TRUE
		for (var/turf/T in berth)
			var/turf/D = locate(T.x + W[1] * k, T.y + W[2] * k, z)
			if (!D || !istype(D, /turf/floor/beach/water))
				ok = FALSE
				break
			if (!hull[D] && (hull_floor_in(D) || vessel_at(D) || craft_at(D) || slipway_dense_in(D)))
				ok = FALSE
				break
			dest[D] = TRUE
		if (!ok)
			continue
		// She must float free, not joined to a jetty or another hull.
		for (var/turf/D in dest)
			for (var/d in cardinal)
				var/turf/N = get_step(D, d)
				if (N && !dest[N] && !hull[N] && hull_floor_in(N))
					ok = FALSE
			if (!ok)
				break
		if (ok)
			return k
	return -1

// TRUE when something solid stands on T.
/proc/slipway_dense_in(turf/T)
	if (T.density)
		return TRUE
	for (var/atom/movable/M in T)
		if (M.loc == T && M.simulated && M.density && !isliving(M))
			return TRUE
	return FALSE

// Launches the finished draught. Returns her tiller, or the reason she stayed.
/obj/structure/slipway/proc/launch_draught()
	var/datum/slipway_design/draught/P = draught_plan()
	if (!P)
		return "No ship is being built here."
	if (!finished())
		return "The [P.name] is not finished: [status_text()]"
	var/hull_name = P.name
	var/list/berth = draught_berth(P.draught)
	if (!berth)
		return "The berth runs off the edge of the world."
	var/list/hull = list()
	for (var/turf/T in berth)
		if (istype(T, /turf/floor/trench) && !istype(T, /turf/floor/trench/flooded))
			return "The dry dock is not flooded: open it to the water first."
		if (hull_floor_in(T))
			hull += T
	var/list/helms = P.draught.helms()
	var/list/xy = splittext(helms[1], ",")
	var/turf/helm_at = draught_turf(P.draught, text2num(xy[1]), text2num(xy[2]))
	var/obj/structure/hull_tiller/tiller = locate() in helm_at
	if (!tiller || !(helm_at in hull))
		var/list/helm_cell = P.draught.cell(text2num(xy[1]), text2num(xy[2]))
		return "Her helm is gone: set her [helm_cell[2] == "O" ? "steering oar" : "tiller"] back on its floor where the draught shows it."
	var/k = draught_landing(berth, draught_length(P.draught))
	if (k < 0)
		return "There is no open water for her within [draught_length(P.draught) + SLIPWAY_DRAUGHT_RUN] tiles [dir2text(dir)] of the slipway."
	// The ways: every tile she slides over must be clear.
	var/list/W = ways_step()
	for (var/step = 1, step < k, step++)
		for (var/turf/T in hull)
			var/turf/D = locate(T.x + W[1] * step, T.y + W[2] * step, z)
			if (!D || (D in berth))
				continue
			if (slipway_dense_in(D) || (istype(D, /turf/floor/trench) && !istype(D, /turf/floor/trench/flooded)))
				return "[capitalize(D.name)] at [D.x],[D.y] is in the way down the ways."
	// She slides as one hull, everyone aboard with her (craft/built_body.dm).
	var/datum/craft_body/built/B = new
	B.hull_name = hull_name
	B.adopt(hull, helm_at, dir)
	var/list/box = B.box(B.offsets)
	B.slide_time = glide_dock_time(k)
	var/moved = B.move_to(B.px + box[1] + W[1] * k, B.py + box[2] + W[2] * k, dir)
	B.slide_time = 0
	if (!moved)
		B.set_afloat(FALSE)
		return "The launch failed: [B.last_refusal]."
	design = null
	draught_code = ""
	pieces_done = 0
	paid = list()
	clear_frames()
	helm_at = get_turf(tiller)
	helm_at.visible_message(SPAN_NOTICE("The [hull_name] slides down the ways and into the water with a great splash!"))
	var/problem = tiller.commission(hull_name, dir)
	if (problem)
		log_game("Slipway: the [hull_name] launched at [helm_at.x],[helm_at.y],[helm_at.z] but was not commissioned: [problem]")
		return "She is afloat, but her tiller could not commission her: [problem]"
	return tiller

// ---- The outline on the berth ----

// Shows what is still to build on tile T (sheet key): the cradle where her
// floor goes, then a faint fitting where one is still to stand. No marker
// once the tile is built.
/obj/structure/slipway/proc/refresh_draught_tile(datum/slipway_design/draught/P, turf/T, key)
	for (var/obj/structure/slipway_frame/F in T)
		if (F.slipway == src)
			F.slipway = null
			frames -= F
			qdel(F)
	var/list/C = P.draught.cells[key]
	var/floor_done = pieces_done >= P.floor_index[key]
	var/piece_done = !C[2] || pieces_done >= P.piece_index[key]
	var/sides_done = !P.gunwale_index[key] || pieces_done >= P.gunwale_index[key]
	if (floor_done && piece_done && sides_done)
		return
	var/obj/structure/slipway_frame/F = new(T)
	F.slipway = src
	frames += F
	var/list/piece = C[2] ? ship_draught_pieces[C[2]] : null
	if (!floor_done)
		F.icon = 'icons/obj/vehicles/vehicleparts_boats.dmi'
		F.icon_state = "grid"
		F.alpha = 110
		F.name = "slipway cradle"
		F.desc = "Part of the [P.name] marked out on a slipway: her [ship_draught_floors[C[1]]["name"]] goes here[piece ? ", with a [piece["name"]] on it" : ""]. Bring the materials here or to the slipway post."
		return
	if (piece_done)
		var/obj/G = C[1] == "s" ? /obj/structure/railing/built/gunwale/bulwark : /obj/structure/railing/built/gunwale
		F.icon = initial(G.icon)
		F.icon_state = initial(G.icon_state)
		F.alpha = 110
		F.name = "marked place for a [initial(G.name)]"
		F.desc = "The [P.name]'s draught closes this edge of her deck with a [initial(G.name)]. Bring the materials here or to the slipway post."
		return
	var/obj/O = piece["path"]
	F.icon = initial(O.icon)
	F.icon_state = initial(O.icon_state)
	F.dir = draught_dir(C[3])
	F.alpha = 110
	F.name = "marked place for a [piece["name"]]"
	F.desc = "The [P.name]'s draught puts a [piece["name"]] here. Bring the materials here or to the slipway post."

/obj/structure/slipway/proc/draught_frames()
	var/datum/slipway_design/draught/P = draught_plan()
	if (!P || !isturf(loc))
		return
	var/list/berth = draught_berth(P.draught)
	if (!berth)
		return
	for (var/turf/T in berth)
		refresh_draught_tile(P, T, berth[T])

#undef SLIPWAY_FLOOR_TIME
#undef SLIPWAY_FIT_TIME
#undef SLIPWAY_DRAUGHT_RUN
