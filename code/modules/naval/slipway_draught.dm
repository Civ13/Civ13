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
// ============================================================

#define SLIPWAY_FLOOR_TIME 30 // ticks to lay one floor tile
#define SLIPWAY_FIT_TIME 50   // ticks to set one fitting

// A ship's draught as a piece plan: one piece per floor tile, then one per
// fitting. order[i] is list(sheet key "x,y", "floor" or the piece key).
/datum/slipway_design/draught
	name = "ship"
	var/datum/ship_draught/draught
	var/list/order = list()
	var/list/floor_index = list() // sheet key -> piece index of its floor
	var/list/piece_index = list() // sheet key -> piece index of its fitting

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
		if (!do_after(H, stage["part"] == "floor" ? SLIPWAY_FLOOR_TIME : SLIPWAY_FIT_TIME, target || src) || QDELETED(src) || QDELETED(S) || draught_code != code || S.loc != H)
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
	if (floor_done && piece_done)
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
