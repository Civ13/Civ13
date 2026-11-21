// ============================================================
// Ship's draughts (docs/ship-draught.md)
// ------------------------------------------------------------
// A draught is a ship drawn on paper before she is built: the tiles of her
// hull, what floor each one has, what stands on it (tiller, masts, rowing
// benches, walls, doors...) and which tiles carry a deck above. She is drawn
// with her bow to the top of the sheet (north) and her helm anywhere on her.
//
// The checks are the ones a tiller makes when she is commissioned: one piece
// joined edge to edge, one helm, no more tiles than a built hull may have. A
// draught that passes them can always be commissioned once she is built.
//
// A draught also reckons what she costs (the same materials as building every
// piece by hand) and how she will go: her size class, the weight on her deck
// against her burden, and the best telegraph step her sails and oars give,
// by the same figures her ledger and drives use afloat.
//
// A draught travels as a design code (design_codes.dm):
//   C13SHIP/1/<name>/<tile>;<tile>;...
// where each tile is "x,y,floor,piece,dir,upper" (piece "-" for none, upper
// 0 or 1). The paper item keeps that same code, so it saves as one text var.
//
// "Draw her lines" at a commissioned tiller copies a ship afloat onto a blank
// sheet of paper.
// ============================================================

// Same figures as hull_load.dm (whose defines end with that file); the probe
// holds them to the ledger's own.
#define DRAUGHT_BURDEN_PER_TILE 0.5
#define DRAUGHT_BALLAST_PER_MAST 0.05
#define DRAUGHT_NAME_MAX 40

// What a tile's floor can be. Costs are the hand recipes in
// config/crafting/material_recipes_global.txt (tests/ship_draught checks them).
var/global/list/ship_draught_floors = list(
	"w" = list("name" = "plank floor", "path" = /obj/covers/repairedfloor, "cost" = list("wood" = 2)),
	"s" = list("name" = "steel floor", "path" = /obj/covers/steelplating, "cost" = list("steel" = 1)),
)

// What can stand on a tile. "load" is what it weighs on a deck in tiles of
// hull (hull_load()); "turns" when its facing matters; "helm" for what steers
// her; "drive" for what pushes her. The order is the order a survey looks for
// them: a subtype before its parent.
var/global/list/ship_draught_pieces = list(
	"O" = list("name" = "steering oar", "path" = /obj/structure/hull_tiller/steering_oar, "cost" = list("wood" = 6), "load" = 0.5, "helm" = TRUE),
	"T" = list("name" = "tiller", "path" = /obj/structure/hull_tiller, "cost" = list("wood" = 10), "load" = 0.5, "helm" = TRUE),
	"M" = list("name" = "ship mast", "path" = /obj/structure/vehicleparts/movement/sail, "cost" = list("wood" = 15), "load" = 0.5, "drive" = "sail"),
	"R" = list("name" = "rowing bench", "path" = /obj/structure/bed/chair/wood/rowing_bench, "cost" = list("wood" = 6), "load" = 0.1, "turns" = TRUE, "drive" = "oars"),
	"K" = list("name" = "killick", "path" = /obj/structure/hull_anchor/stone, "cost" = list("wood" = 8), "load" = 0.4),
	"A" = list("name" = "iron anchor", "path" = /obj/structure/hull_anchor, "cost" = list("iron" = 8), "load" = 1),
	"P" = list("name" = "hand bilge pump", "path" = /obj/structure/cellar_pump/lever, "cost" = list("iron" = 6), "load" = 0.5),
	"W" = list("name" = "plank wall", "path" = /obj/covers/wood_wall/adjustable, "cost" = list("wood" = 2, "planks" = 4), "load" = 0.3),
	"D" = list("name" = "door", "path" = /obj/structure/simple_door/key_door/anyone/wood, "cost" = list("wood" = 5), "load" = 0.5, "turns" = TRUE),
	"G" = list("name" = "window", "path" = /obj/structure/window_frame, "cost" = list("wood" = 5), "load" = 0.1),
	"C" = list("name" = "wood crate", "path" = /obj/structure/closet/crate/empty, "cost" = list("wood" = 5), "load" = 0.5),
	"B" = list("name" = "bed", "path" = /obj/structure/bed/wood, "cost" = list("wood" = 4), "load" = 0.1),
	// A gate in her gunwale on an edge tile, facing out (hull_gangway.dm).
	// A mast with a crow's nest at her masthead (hull_masts.dm).
	"N" = list("name" = "mast with a crow's nest", "path" = /obj/structure/vehicleparts/movement/sail/crows_nest, "cost" = list("wood" = 23), "load" = 0.5, "drive" = "sail"),
	"Y" = list("name" = "gangway", "path" = /obj/structure/railing/built/gunwale/gangway, "cost" = list("wood" = 4), "load" = 0, "turns" = TRUE),
)

// A tile of deck on the level above costs a floor, like any floor laid there.
var/global/list/ship_draught_upper_cost = list("wood" = 2)

/datum/ship_draught
	var/name = "ship"
	// "x,y" = list(floor key, piece key or null, piece dir, upper deck TRUE/FALSE)
	var/list/cells = list()

/datum/ship_draught/proc/cell(x, y)
	return cells["[x],[y]"]

// Lays (or changes) the floor of a tile. Returns FALSE for an unknown floor
// or a tile off the sheet.
/datum/ship_draught/proc/set_floor(x, y, floor)
	if (!ship_draught_floors[floor] || !ship_draught_on_sheet(x, y))
		return FALSE
	var/list/C = cell(x, y)
	if (C)
		C[1] = floor
	else
		cells["[x],[y]"] = list(floor, null, NORTH, FALSE)
	return TRUE

// Stands a piece on a floored tile (null clears it).
/datum/ship_draught/proc/set_piece(x, y, piece, piece_dir = NORTH)
	var/list/C = cell(x, y)
	if (!C || (piece && !ship_draught_pieces[piece]) || !(piece_dir in cardinal))
		return FALSE
	C[2] = piece
	C[3] = piece_dir
	return TRUE

/datum/ship_draught/proc/set_upper(x, y, state)
	var/list/C = cell(x, y)
	if (!C)
		return FALSE
	C[4] = state ? TRUE : FALSE
	return TRUE

/datum/ship_draught/proc/clear(x, y)
	cells -= "[x],[y]"

/datum/ship_draught/proc/hull_tiles()
	return cells.len

/datum/ship_draught/proc/upper_tiles()
	. = 0
	for (var/key in cells)
		var/list/C = cells[key]
		if (C[4])
			.++

/datum/ship_draught/proc/piece_count(piece)
	. = 0
	for (var/key in cells)
		var/list/C = cells[key]
		if (C[2] == piece)
			.++

// The tiles that carry a helm, as "x,y" keys.
// Her masts, with or without a crow's nest.
/datum/ship_draught/proc/mast_count()
	return piece_count("M") + piece_count("N")

/datum/ship_draught/proc/helms()
	. = list()
	for (var/key in cells)
		var/list/C = cells[key]
		if (C[2])
			var/list/P = ship_draught_pieces[C[2]]
			if (P["helm"])
				. += key

// list(min x, min y, max x, max y), or null when nothing is drawn.
/datum/ship_draught/proc/extent()
	if (!cells.len)
		return null
	var/list/B = null
	for (var/key in cells)
		var/list/xy = splittext(key, ",")
		var/x = text2num(xy[1])
		var/y = text2num(xy[2])
		if (!B)
			B = list(x, y, x, y)
		else
			B[1] = min(B[1], x)
			B[2] = min(B[2], y)
			B[3] = max(B[3], x)
			B[4] = max(B[4], y)
	return B

// TRUE when every tile is joined edge to edge with every other.
/datum/ship_draught/proc/joined()
	if (!cells.len)
		return FALSE
	var/start = cells[1]
	var/list/found = list("[start]" = TRUE)
	var/list/queue = list(start)
	while (queue.len)
		var/key = queue[1]
		queue.Cut(1, 2)
		var/list/xy = splittext(key, ",")
		var/x = text2num(xy[1])
		var/y = text2num(xy[2])
		for (var/next in list("[x + 1],[y]", "[x - 1],[y]", "[x],[y + 1]", "[x],[y - 1]"))
			if (cells[next] && !found[next])
				found[next] = TRUE
				queue += next
	return found.len == cells.len

// Why she could not be commissioned as drawn; an empty list when she could.
/datum/ship_draught/proc/problems()
	. = list()
	if (!cells.len)
		. += "Nothing is drawn yet: draw her floors first."
		return
	if (cells.len > SHIP_DRAUGHT_MAX_TILES)
		. += "She has [cells.len] tiles of hull: a hull may have at most [SHIP_DRAUGHT_MAX_TILES]."
	var/upper = upper_tiles()
	if (cells.len + upper > SHIP_DRAUGHT_MAX_DECK)
		. += "Her decks are [cells.len + upper] tiles in all: at most [SHIP_DRAUGHT_MAX_DECK] can sail. Draw less deck above."
	if (!joined())
		. += "Her floors are in more than one piece: every tile must touch another along an edge."
	var/list/H = helms()
	if (!H.len)
		. += "She has no helm: put a tiller or a steering oar on one of her tiles."
	else if (H.len > 1)
		. += "She has [H.len] helms: only one tiller or steering oar can steer her."
	var/inboard = 0
	for (var/key in cells)
		var/list/C = cells[key]
		if (C[2] != "Y")
			continue
		var/list/xy = splittext(key, ",")
		var/x = text2num(xy[1])
		var/y = text2num(xy[2])
		var/d = C[3]
		if (cell(x + (d == EAST ? 1 : d == WEST ? -1 : 0), y + (d == NORTH ? 1 : d == SOUTH ? -1 : 0)))
			inboard++
	if (inboard)
		. += "[inboard] gangway\s face[inboard == 1 ? "s" : ""] her own deck: a gangway stands on her edge, facing out over the side."

/datum/ship_draught/proc/buildable()
	var/list/P = problems()
	return !P.len

// What building her takes: material = amount.
/datum/ship_draught/proc/costs()
	. = list()
	for (var/key in cells)
		var/list/C = cells[key]
		var/list/F = ship_draught_floors[C[1]]
		ship_draught_add_cost(., F["cost"])
		if (C[2])
			var/list/P = ship_draught_pieces[C[2]]
			ship_draught_add_cost(., P["cost"])
		if (C[4])
			ship_draught_add_cost(., ship_draught_upper_cost)
	for (var/list/side in gunwale_sides())
		var/list/C = cells[side[1]]
		ship_draught_add_cost(., C[1] == "s" ? list("steel" = 2) : list("wood" = 2))

// The open sides of her deck as drawn, which get a gunwale (a steel bulwark on
// steel floor) when she is built: list(list(sheet key, sheet direction)).
// Small craft get none, and a tile with a wall, door or window is closed.
/datum/ship_draught/proc/gunwale_sides()
	. = list()
	if (cells.len <= HULL_SMALL_MAX_TILES)
		return
	for (var/key in cells)
		var/list/C = cells[key]
		if (C[2] == "W" || C[2] == "D" || C[2] == "G")
			continue
		var/list/xy = splittext(key, ",")
		var/x = text2num(xy[1])
		var/y = text2num(xy[2])
		for (var/d in cardinal)
			if (C[2] == "Y" && C[3] == d)
				continue // her gangway closes that side
			if (!cell(x + (d == EAST ? 1 : d == WEST ? -1 : 0), y + (d == NORTH ? 1 : d == SOUTH ? -1 : 0)))
				. += list(list(key, d))

/datum/ship_draught/proc/costs_text()
	var/list/C = costs()
	var/list/parts = list()
	for (var/material in C)
		parts += "[C[material]] [material]"
	return parts.len ? english_list(parts) : "nothing"

// What stands on her deck weighs, in tiles of hull.
/datum/ship_draught/proc/load()
	. = 0
	for (var/key in cells)
		var/list/C = cells[key]
		if (C[2])
			var/list/P = ship_draught_pieces[C[2]]
			. += P["load"]

/datum/ship_draught/proc/size_class()
	if (cells.len <= HULL_SMALL_MAX_TILES)
		return HULL_CLASS_SMALL
	if (cells.len <= HULL_BOAT_MAX_TILES)
		return HULL_CLASS_BOAT
	return HULL_CLASS_SHIP

/datum/ship_draught/proc/size_class_name()
	switch (size_class())
		if (HULL_CLASS_SMALL)
			return "small craft"
		if (HULL_CLASS_BOAT)
			return "boat"
	return "ship"

// What her drives push against, empty of cargo and crew: her tiles, and the
// weight of her fittings past her burden (small craft carry theirs free).
/datum/ship_draught/proc/mass()
	. = max(1, cells.len)
	if (size_class() != HULL_CLASS_SMALL)
		. += max(0, round(load() - cells.len * DRAUGHT_BURDEN_PER_TILE))

// The best telegraph step her masts make on a reach, her benches manned, and
// both together (VESSEL_SPEED_SLOW when nothing makes more: she can be poled).
/datum/ship_draught/proc/sail_step()
	var/push = mast_count() * CRAFT_SAIL_THRUST
	return push / mass() >= CRAFT_THRUST_HALF ? VESSEL_SPEED_HALF : VESSEL_SPEED_SLOW

/datum/ship_draught/proc/oar_step()
	var/push = piece_count("R") * CRAFT_OAR_THRUST
	if (push / mass() >= CRAFT_THRUST_FULL)
		return VESSEL_SPEED_FULL
	return push / mass() >= CRAFT_THRUST_HALF ? VESSEL_SPEED_HALF : VESSEL_SPEED_SLOW

/datum/ship_draught/proc/best_step()
	var/oars = piece_count("R") * CRAFT_OAR_THRUST
	var/all = oars + mast_count() * CRAFT_SAIL_THRUST
	if (oars / mass() >= CRAFT_THRUST_FULL)
		return VESSEL_SPEED_FULL
	return all / mass() >= CRAFT_THRUST_HALF ? VESSEL_SPEED_HALF : VESSEL_SPEED_SLOW

// A ship with masts wants weight low in her (hull_load.dm): TRUE when her
// fittings alone are not enough, so she sails crank until she is ballasted.
/datum/ship_draught/proc/wants_ballast()
	var/masts = mast_count()
	if (size_class() != HULL_CLASS_SHIP || !masts)
		return 0
	return max(0, round(cells.len * DRAUGHT_BALLAST_PER_MAST * masts - load(), 0.1))

/proc/ship_draught_step_name(step)
	switch (step)
		if (VESSEL_SPEED_FULL)
			return "full ahead"
		if (VESSEL_SPEED_HALF)
			return "half ahead"
	return "slow ahead"

/datum/ship_draught/proc/summary_text()
	var/list/lines = list()
	var/upper = upper_tiles()
	lines += "<b>[name]</b>: [cells.len] tile\s of hull[upper ? " and [upper] of deck above" : ""], a [size_class_name()], bow to the top of the sheet."
	if (!cells.len)
		return jointext(lines, "<br>")
	lines += "Building her takes [costs_text()]."
	var/masts = mast_count()
	var/benches = piece_count("R")
	var/list/drives = list()
	if (masts)
		drives += "under sail on a reach: [ship_draught_step_name(sail_step())]"
	if (benches)
		drives += "with every bench manned: [ship_draught_step_name(oar_step())]"
	if (masts && benches)
		drives += "with both: [ship_draught_step_name(best_step())]"
	if (drives.len)
		lines += "Empty, she should make [jointext(drives, "; ")]."
	else
		lines += "She has no masts or rowing benches: she can only be poled along at slow ahead, unless you fit an engine."
	var/ballast = wants_ballast()
	if (ballast)
		lines += "With [masts] mast\s she wants about [ballast] more tiles of weight low in her as ballast, or she sails crank."
	var/list/P = problems()
	if (P.len)
		lines += "<span class='warning'>Not ready to build: [jointext(P, " ")]</span>"
	else
		lines += "As drawn she can be built and commissioned."
	return jointext(lines, "<br>")

// The same summary as fields, for the designer window to lay out:
// what summary_text() says, nothing reckoned twice.
/datum/ship_draught/proc/summary_data()
	var/upper = upper_tiles()
	var/masts = mast_count()
	var/benches = piece_count("R")
	var/list/cost_parts = list()
	var/list/drives = list()
	if (cells.len)
		var/list/C = costs()
		for (var/material in C)
			cost_parts += "[C[material]] [material]"
		if (masts)
			drives += list(list("Sail", ship_draught_step_name(sail_step())))
		if (benches)
			drives += list(list("Oars", ship_draught_step_name(oar_step())))
		if (masts && benches)
			drives += list(list("Both", ship_draught_step_name(best_step())))
	return list(
		"name" = name,
		"tiles" = cells.len,
		"max_tiles" = SHIP_DRAUGHT_MAX_TILES,
		"upper" = upper,
		"max_deck" = SHIP_DRAUGHT_MAX_DECK,
		"class" = size_class_name(),
		"costs" = cost_parts,
		"drives" = drives,
		"masts" = masts,
		"gunwales" = length(gunwale_sides()),
		"ballast" = cells.len ? wants_ballast() : 0,
		"problems" = problems(),
	)

// ---- Design codes ----

/datum/ship_draught/proc/to_code()
	var/list/B = extent()
	var/list/tiles = list()
	for (var/key in cells)
		var/list/C = cells[key]
		var/list/xy = splittext(key, ",")
		var/x = text2num(xy[1]) - (B ? B[1] : 0)
		var/y = text2num(xy[2]) - (B ? B[2] : 0)
		tiles += "[x],[y],[C[1]],[C[2] ? C[2] : "-"],[C[3]],[C[4] ? 1 : 0]"
	return "C13SHIP/1/[ship_draught_code_name(name)]/[jointext(tiles, ";")]"

// A name as a code field: "_" for spaces, no "/" or ";".
/proc/ship_draught_code_name(text)
	text = ship_draught_clean_name(text)
	return replacetext(text, " ", "_")

/proc/ship_draught_clean_name(text)
	if (!istext(text))
		return "ship"
	text = replacetext(replacetext(replacetext(text, "/", " "), ";", " "), ",", " ")
	text = trim(sanitize(copytext(text, 1, DRAUGHT_NAME_MAX + 1)))
	return length(text) ? text : "ship"

/proc/ship_draught_on_sheet(x, y)
	return isnum(x) && isnum(y) && x == round(x) && y == round(y) && x >= 0 && y >= 0 && x < SHIP_DRAUGHT_SIDE && y < SHIP_DRAUGHT_SIDE

// A draught from a code, or null when the code is not a working ship code.
/proc/ship_draught_from_code(code)
	var/list/F = design_code_fields(code, "SHIP", DESIGN_CODE_SHIP_MAX)
	if (!F || F.len != 2)
		return null
	var/datum/ship_draught/D = new
	D.name = ship_draught_clean_name(replacetext(F[1], "_", " "))
	var/list/tiles = length(F[2]) ? splittext(F[2], ";") : list()
	if (tiles.len > SHIP_DRAUGHT_MAX_TILES)
		qdel(D)
		return null
	for (var/tile in tiles)
		var/list/T = splittext(tile, ",")
		if (T.len != 6)
			qdel(D)
			return null
		var/x = text2num(T[1])
		var/y = text2num(T[2])
		var/piece_dir = text2num(T[5])
		if (D.cell(x, y) || !D.set_floor(x, y, T[3]) || !(T[6] in list("0", "1")))
			qdel(D)
			return null
		if (!D.set_piece(x, y, T[4] == "-" ? null : T[4], piece_dir))
			qdel(D)
			return null
		D.set_upper(x, y, T[6] == "1")
	return D

/proc/ship_draught_add_cost(list/into, list/cost)
	for (var/material in cost)
		into[material] = (into[material] ? into[material] : 0) + cost[material]

// ---- Drawing a ship afloat ----

// The piece key for what stands on T, or null. helm is the tiller that
// steers her: any other tiller on her deck is left off, as one sheet shows
// one helm.
/proc/ship_draught_piece_on(turf/T, obj/structure/hull_tiller/helm)
	// A mast with a crow's nest fitted by hand draws as one.
	for (var/obj/structure/vehicleparts/movement/sail/S in T)
		if (S.crows_nest)
			return list("N", S.dir)
	for (var/key in ship_draught_pieces)
		var/list/P = ship_draught_pieces[key]
		var/path = P["path"]
		for (var/atom/movable/M in T)
			if (M.type != path)
				continue
			if (istype(M, /obj/structure/hull_tiller) && M != helm)
				continue
			return list(key, M.dir)
	// Close kin of a piece draw as that piece.
	for (var/atom/movable/M in T)
		if (istype(M, /obj/structure/hull_tiller) && M != helm)
			continue
		if (istype(M, /obj/covers))
			var/obj/covers/W = M
			if (W.wall)
				return list("W", M.dir)
			continue
		if (istype(M, /obj/structure/simple_door))
			return list("D", M.dir)
		if (istype(M, /obj/structure/window_frame))
			return list("G", M.dir)
		if (istype(M, /obj/structure/closet/crate))
			return list("C", M.dir)
		if (istype(M, /obj/structure/railing/built/gunwale/bulwark/gangway))
			return list("Y", M.dir)
	return null

// Her lines with her bow to the top of the sheet, or the reason she cannot
// be drawn.
/proc/ship_draught_survey(obj/structure/hull_tiller/tiller)
	if (!tiller || !tiller.craft)
		return "Only a commissioned hull can have her lines drawn."
	var/datum/craft/craft = tiller.craft
	var/datum/craft_body/built/B = craft.body
	if (!istype(B) || !B.placed())
		return "She is not afloat."
	var/angle = craft_turn_angle(B.dir, NORTH)
	var/uz = B.upper_z()
	var/list/turned = list()
	var/minx = 0
	var/miny = 0
	var/maxx = 0
	var/maxy = 0
	for (var/list/O in B.offsets)
		var/list/R = ship_draught_bow_up(O[1], O[2], B.dir)
		turned += list(R)
		minx = min(minx, R[1])
		miny = min(miny, R[2])
		maxx = max(maxx, R[1])
		maxy = max(maxy, R[2])
	if (maxx - minx >= SHIP_DRAUGHT_SIDE || maxy - miny >= SHIP_DRAUGHT_SIDE)
		return "She is too long to draw on one sheet: a draught is at most [SHIP_DRAUGHT_SIDE] tiles each way."
	var/datum/ship_draught/D = new
	D.name = ship_draught_clean_name(craft.name)
	for (var/i = 1, i <= B.offsets.len, i++)
		var/list/O = B.offsets[i]
		var/list/R = turned[i]
		var/turf/T = locate(B.px + O[1], B.py + O[2], B.z)
		if (!T)
			continue
		var/x = R[1] - minx
		var/y = R[2] - miny
		D.set_floor(x, y, (locate(/obj/covers/steelplating) in T) ? "s" : "w")
		var/list/piece = ship_draught_piece_on(T, tiller)
		if (piece)
			D.set_piece(x, y, piece[1], (piece[2] in cardinal) ? turn(piece[2], angle) : NORTH)
		if (B.upper_deck_cell(T, uz))
			D.set_upper(x, y, TRUE)
	return D

// An offset of a hull whose bow points to heading, as it lies with her bow to
// the north.
/proc/ship_draught_bow_up(dx, dy, heading)
	switch (heading)
		if (EAST)
			return list(-dy, dx)
		if (SOUTH)
			return list(-dx, -dy)
		if (WEST)
			return list(dy, -dx)
	return list(dx, dy)

// ---- The sheet ----

/obj/item/ship_draught
	name = "ship's draught"
	desc = "A ship drawn on paper: her hull tile by tile, with her fittings and decks."
	icon = 'icons/obj/items.dmi'
	icon_state = "blueprints"
	w_class = ITEM_SIZE_SMALL
	flammable = TRUE
	// Saved: the draught as its design code.
	var/draught_code = ""

/obj/item/ship_draught/proc/draught()
	return draught_code ? ship_draught_from_code(draught_code) : null

// The name of the ship drawn on the sheet, or null when it is blank.
/obj/item/ship_draught/proc/draughts_name()
	var/datum/ship_draught/D = draught()
	. = D ? D.name : null
	if (D)
		qdel(D)

/obj/item/ship_draught/proc/take(datum/ship_draught/D)
	draught_code = D ? D.to_code() : ""
	name = D ? "ship's draught ([D.name])" : initial(name)

/obj/item/ship_draught/examine(mob/user, distance)
	..()
	var/datum/sub_draught/sub = sub_draught()
	if (sub)
		to_chat(user, sub.summary_text())
		qdel(sub)
		return
	var/datum/ship_draught/D = draught()
	to_chat(user, D ? D.summary_text() : "The sheet is blank.")
	if (D)
		qdel(D)

/obj/item/ship_draught/attack_self(mob/living/human/H)
	if (!istype(H))
		return
	var/datum/sub_draught/sub = sub_draught()
	if (sub)
		sub_sheet_menu(H, sub)
		qdel(sub)
		return
	var/datum/ship_draught/D = draught()
	var/list/options = list("Draw on the sheet", "Paste a design code", "Cancel")
	if (D)
		options.Insert(2, "Copy her design code")
	else
		options.Insert(2, "Draw a submarine on the sheet")
	var/choice = WWinput(H, D ? D.summary_text() : "The sheet is blank. Hold a pen or pencil to draw a ship on it.", name, "Cancel", options)
	if (choice == "Draw on the sheet")
		open_designer(H)
	else if (choice == "Draw a submarine on the sheet" && !draught_code)
		open_sub_designer(H)
	else if (choice == "Copy her design code" && D)
		design_code_show(H, "Ship's draught: [D.name]", draught_code, "Paste it into any ship's draught to draw the same ship.")
	else if (choice == "Paste a design code")
		paste_any_code(H)
	if (D)
		qdel(D)

// "Draw her lines" at the tiller: a blank sheet in hand becomes her draught.
/obj/structure/hull_tiller/proc/draw_lines(mob/living/human/H)
	var/obj/item/weapon/paper/P = H.get_active_hand()
	if (!recipe_blank_paper(P))
		P = H.get_inactive_hand()
	if (!recipe_blank_paper(P))
		to_chat(H, SPAN_WARNING("Hold a blank sheet of paper to draw her lines on."))
		return
	var/survey = ship_draught_survey(src)
	if (istext(survey))
		to_chat(H, SPAN_WARNING(survey))
		return
	var/datum/ship_draught/D = survey
	if (!do_after(H, 50, src) || !recipe_blank_paper(P) || P.loc != H || !craft)
		qdel(D)
		return
	var/obj/item/ship_draught/S = new(get_turf(H))
	S.take(D)
	H.drop_from_inventory(P)
	qdel(P)
	H.put_in_hands(S)
	to_chat(H, SPAN_NOTICE("You draw the lines of the [D.name] on the sheet: [D.hull_tiles()] tiles of hull, bow to the top."))
	qdel(D)

#undef DRAUGHT_BURDEN_PER_TILE
#undef DRAUGHT_BALLAST_PER_MAST
#undef DRAUGHT_NAME_MAX
