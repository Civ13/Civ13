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
// Besides her main deck she can have decks on other levels (ship_draught_decks):
// a hold under her hull and decks above it, each tile over a tile of the level
// toward her main deck, with its own fittings. A ladder joins each deck to the
// next: it stands on the lower deck and the tile above it is left clear.
//
// A draught travels as a design code (design_codes.dm):
//   C13SHIP/1/<name>/<tile>;<tile>;...
// where each tile is "x,y,floor,piece,dir,upper" (piece "-" for none, upper
// 0 or 1). A draught with a hold, a second deck above or fittings on a deck
// above writes C13SHIP/2: the same tiles, then "/" and every tile off her
// main deck as "level,x,y,piece,dir". The paper item keeps that same code, so
// it saves as one text var.
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
// A proc, not an initialised global: world's global initialiser is at BYOND's
// procedure size limit (#6580). The table is built on first use.
/proc/ship_draught_floors()
	var/static/list/table
	if (!table)
		table = list(
	"w" = list("name" = "plank floor", "path" = /obj/covers/repairedfloor, "cost" = list("wood" = 2)),
	"s" = list("name" = "steel floor", "path" = /obj/covers/steelplating, "cost" = list("steel" = 1)),
)
	return table

// What can stand on a tile. "load" is what it weighs on a deck in tiles of
// hull (hull_load()); "turns" when its facing matters; "helm" for what steers
// her; "drive" for what pushes her; "decks" when it may stand on a deck off
// her main deck too; "ladder" for what climbs to the deck above; "carries"
// how many tiles away it holds up the deck above (building_support_reach()). The order is the order a survey looks for
// them: a subtype before its parent.
// A proc, not an initialised global: world's global initialiser is at BYOND's
// procedure size limit (#6580). The table is built on first use.
/proc/ship_draught_pieces()
	var/static/list/table
	if (!table)
		table = list(
	"O" = list("name" = "steering oar", "path" = /obj/structure/hull_tiller/steering_oar, "cost" = list("wood" = 6), "load" = 0.5, "helm" = TRUE),
	"T" = list("name" = "tiller", "path" = /obj/structure/hull_tiller, "cost" = list("wood" = 10), "load" = 0.5, "helm" = TRUE),
	"M" = list("name" = "ship mast", "path" = /obj/structure/vehicleparts/movement/sail, "cost" = list("wood" = 15), "load" = 0.5, "drive" = "sail"),
	"R" = list("name" = "rowing bench", "path" = /obj/structure/bed/chair/wood/rowing_bench, "cost" = list("wood" = 6), "load" = 0.1, "turns" = TRUE, "drive" = "oars"),
	"K" = list("name" = "killick", "path" = /obj/structure/hull_anchor/stone, "cost" = list("wood" = 8), "load" = 0.4),
	"A" = list("name" = "iron anchor", "path" = /obj/structure/hull_anchor, "cost" = list("iron" = 8), "load" = 1),
	"P" = list("name" = "hand bilge pump", "path" = /obj/structure/cellar_pump/lever, "cost" = list("iron" = 6), "load" = 0.5, "decks" = TRUE),
	"W" = list("name" = "plank wall", "path" = /obj/covers/wood_wall/adjustable, "cost" = list("wood" = 2, "planks" = 4), "load" = 0.3, "decks" = TRUE, "carries" = 1),
	"D" = list("name" = "door", "path" = /obj/structure/simple_door/key_door/anyone/wood, "cost" = list("wood" = 5), "load" = 0.5, "turns" = TRUE, "decks" = TRUE),
	"G" = list("name" = "window", "path" = /obj/structure/window_frame, "cost" = list("wood" = 5), "load" = 0.1, "decks" = TRUE),
	"C" = list("name" = "wood crate", "path" = /obj/structure/closet/crate/empty, "cost" = list("wood" = 5), "load" = 0.5, "decks" = TRUE),
	"B" = list("name" = "bed", "path" = /obj/structure/bed/wood, "cost" = list("wood" = 4), "load" = 0.1, "decks" = TRUE),
	// Everything else a built hull takes aboard and works afloat.
	"Q" = list("name" = "steam bilge pump", "path" = /obj/structure/cellar_pump/steam, "cost" = list("iron" = 12), "load" = 0.5, "decks" = TRUE),
	"U" = list("name" = "sump pump", "path" = /obj/structure/cellar_pump/sump, "cost" = list("steel" = 4), "load" = 0.1, "decks" = TRUE),
	"E" = list("name" = "steam engine", "path" = /obj/structure/engine/external/steam, "cost" = list("steel" = 15), "load" = 1, "drive" = "engine"),
	"H" = list("name" = "wooden cannon", "path" = /obj/structure/cannon/hooped, "cost" = list("wood" = 12), "load" = 1.5, "turns" = TRUE, "fires" = TRUE),
	"Z" = list("name" = "cannon", "path" = /obj/structure/cannon, "cost" = list("steel" = 35), "load" = 1.5, "turns" = TRUE, "fires" = TRUE),
	"L" = list("name" = "torpedo tube", "path" = /obj/structure/torpedo_tube, "cost" = list("steel" = 25), "load" = 0.5, "turns" = TRUE, "fires" = TRUE),
	"V" = list("name" = "steel window", "path" = /obj/structure/window_frame/metal, "cost" = list("steel" = 5), "load" = 0.1, "decks" = TRUE),
	"I" = list("name" = "steel door", "path" = /obj/structure/simple_door/key_door/anyone/fire_door/steel, "cost" = list("steel" = 15), "load" = 0.5, "turns" = TRUE, "decks" = TRUE),
	// A mast with a crow's nest at her masthead (hull_masts.dm).
	"N" = list("name" = "mast with a crow's nest", "path" = /obj/structure/vehicleparts/movement/sail/crows_nest, "cost" = list("wood" = 23), "load" = 0.5, "drive" = "sail"),
	// Her bow (hull_bow.dm): a bowsprit carries a jib, half a mast's push.
	"J" = list("name" = "bowsprit", "path" = /obj/structure/vehicleparts/movement/sail/bowsprit, "cost" = list("wood" = 10), "load" = 0.5, "drive" = "sail"),
	"F" = list("name" = "figurehead", "path" = /obj/structure/figurehead, "cost" = list("wood" = 6), "load" = 0.1, "turns" = TRUE),
	// A gate in her gunwale on an edge tile, facing out (hull_gangway.dm).
	"Y" = list("name" = "gangway", "path" = /obj/structure/railing/built/gunwale/gangway, "cost" = list("wood" = 4), "load" = 0, "turns" = TRUE),
	// A wooden ladder stood up to the deck above (edge_climbing.dm): this is
	// its foot; its head stands on the clear tile above.
	// A wooden pillar that carries the deck above it (roof_stuff.dm): it
	// holds deck up to 3 tiles away, a plank wall only beside it.
	"S" = list("name" = "deck pillar", "path" = /obj/structure/roof_support, "cost" = list("wood" = 2), "load" = 0.5, "decks" = TRUE, "carries" = 3),
	"X" = list("name" = "ladder", "path" = /obj/structure/multiz/ladder/up/placed, "cost" = list("wood" = 4), "load" = 0.1, "decks" = TRUE, "ladder" = TRUE),
	// Watertight compartments (hull_compartments.dm): a bulkhead, and a door
	// in one. Two letters each: every single capital is taken.
	"WT" = list("name" = "watertight door", "path" = /obj/structure/simple_door/key_door/anyone/fire_door/steel/watertight, "cost" = list("steel" = 20), "load" = 0.5, "turns" = TRUE, "decks" = TRUE),
	"WB" = list("name" = "watertight bulkhead", "path" = /obj/structure/hull_bulkhead, "cost" = list("steel" = 8), "load" = 0.5, "decks" = TRUE, "carries" = 1),
	"GP" = list("name" = "wooden gun port", "path" = /obj/structure/railing/built/gunwale/gun_port, "cost" = list("wood" = 4), "load" = 0, "turns" = TRUE, "decks" = TRUE),
	"GS" = list("name" = "steel gun port", "path" = /obj/structure/railing/built/gunwale/bulwark/gun_port, "cost" = list("steel" = 4), "load" = 0, "turns" = TRUE, "decks" = TRUE),
	"CH" = list("name" = "cargo hatch", "path" = /obj/structure/cargo_hatch, "cost" = list("wood" = 6), "load" = 0.1),
	"LD" = list("name" = "lifeboat davits", "path" = /obj/structure/lifeboat_davit, "cost" = list("steel" = 6), "load" = 0.1, "turns" = TRUE),
)
	return table

// Her decks off the main deck, by level (her main deck is level 0). A deck
// above stands on the level below it, her hold under her hull. "floor" is
// what each tile of it is laid with, and what that costs.
var/global/list/ship_draught_decks = list(
	"-1" = list("name" = "hold", "floor" = "s", "cost" = list("steel" = 1)),
	"1" = list("name" = "deck above", "floor" = "w", "cost" = list("wood" = 2)),
	"2" = list("name" = "second deck above", "floor" = "w", "cost" = list("wood" = 2)),
)


/datum/ship_draught
	var/name = "ship"
	// "x,y" = list(floor key, piece key or null, piece dir, upper deck TRUE/FALSE)
	var/list/cells = list()
	// Her other decks: level text = list("x,y" = list(piece key or null, piece dir)).
	// Deck "1" is the same tiles as the cells' upper flags.
	var/list/decks = list()

/datum/ship_draught/proc/cell(x, y)
	return cells["[x],[y]"]

// Lays (or changes) the floor of a tile. Returns FALSE for an unknown floor
// or a tile off the sheet.
/datum/ship_draught/proc/set_floor(x, y, floor)
	if (!ship_draught_floors()[floor] || !ship_draught_on_sheet(x, y))
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
	if (!C || (piece && !ship_draught_pieces()[piece]) || !(piece_dir in cardinal))
		return FALSE
	C[2] = piece
	C[3] = piece_dir
	return TRUE

/datum/ship_draught/proc/set_upper(x, y, state)
	return set_deck(1, x, y, state)

// The level a deck tile on level stands on: her main deck for the hold and
// the deck above, the deck below for any higher one.
/proc/ship_draught_support(level)
	return level > 1 ? level - 1 : 0

/proc/ship_draught_level_name(level)
	if (!level)
		return "main deck"
	var/list/L = ship_draught_decks["[level]"]
	return L ? L["name"] : null

// The tile of level at x,y: a main-deck cell, or list(piece, dir) on another
// deck, or null.
/datum/ship_draught/proc/deck_cell(level, x, y)
	if (!level)
		return cell(x, y)
	var/list/L = decks["[level]"]
	return L ? L["[x],[y]"] : null

// Lays (state TRUE) or takes up a tile of a deck off her main deck. It must
// stand over a tile of the level it rests on. Taking one up takes up what
// stands on it, and the deck above it there.
/datum/ship_draught/proc/set_deck(level, x, y, state)
	if (!ship_draught_decks["[level]"])
		return FALSE
	var/key = "[x],[y]"
	var/list/L = decks["[level]"]
	if (!state)
		if (L)
			L -= key
			if (!L.len)
				decks -= "[level]"
		if (level == 1)
			var/list/C = cell(x, y)
			if (C)
				C[4] = FALSE
		if (level > 0)
			set_deck(level + 1, x, y, FALSE)
		return TRUE
	if (!deck_cell(ship_draught_support(level), x, y))
		return FALSE
	if (!L)
		L = list()
		decks["[level]"] = L
	if (!L[key])
		L[key] = list(null, NORTH)
	if (level == 1)
		var/list/C = cell(x, y)
		C[4] = TRUE
	return TRUE

// Stands a piece on a deck tile off her main deck (null clears it). Only the
// pieces marked "decks" go there, and nothing climbs above her top deck.
/datum/ship_draught/proc/set_deck_piece(level, x, y, piece, piece_dir = NORTH)
	var/list/D = deck_cell(level, x, y)
	if (!level || !D || !(piece_dir in cardinal))
		return FALSE
	if (piece)
		var/list/P = ship_draught_pieces()[piece]
		if (!P || !P["decks"] || (P["ladder"] && level != -1 && !ship_draught_decks["[level + 1]"]))
			return FALSE
	D[1] = piece
	D[2] = piece_dir
	return TRUE

/datum/ship_draught/proc/clear(x, y)
	cells -= "[x],[y]"
	for (var/level in decks.Copy())
		set_deck(text2num(level), x, y, FALSE)

// Tiles of a deck off her main deck.
/datum/ship_draught/proc/deck_tiles(level)
	var/list/L = decks["[level]"]
	return L ? L.len : 0

// Tiles of every deck but her main one.
/datum/ship_draught/proc/other_deck_tiles()
	. = 0
	for (var/level in decks)
		var/list/L = decks[level]
		. += L.len

/datum/ship_draught/proc/hull_tiles()
	return cells.len

/datum/ship_draught/proc/upper_tiles()
	return deck_tiles(1)

// How many of piece she carries, on every deck.
/datum/ship_draught/proc/piece_count(piece)
	. = 0
	for (var/key in cells)
		var/list/C = cells[key]
		if (C[2] == piece)
			.++
	for (var/level in decks)
		var/list/L = decks[level]
		for (var/key in L)
			var/list/T = L[key]
			if (T[1] == piece)
				.++

// The tiles that carry a helm, as "x,y" keys.
// Her masts, with or without a crow's nest.
/datum/ship_draught/proc/mast_count()
	return piece_count("M") + piece_count("N")

// What her sails push on a reach: her masts, and half a mast for each jib.
/datum/ship_draught/proc/sail_push()
	return (mast_count() + piece_count("J") * 0.5) * CRAFT_SAIL_THRUST

/datum/ship_draught/proc/helms()
	. = list()
	for (var/key in cells)
		var/list/C = cells[key]
		if (C[2])
			var/list/P = ship_draught_pieces()[C[2]]
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
	var/list/parts = ship_draught_parts(cells)
	return parts.len == 1

// The pieces a set of "x,y" keys falls into, joined edge to edge: a list of
// lists of keys.
/proc/ship_draught_parts(list/tiles)
	. = list()
	var/list/found = list()
	for (var/start in tiles)
		if (found[start])
			continue
		var/list/part = list(start)
		found[start] = TRUE
		var/i = 1
		while (i <= part.len)
			var/list/xy = splittext(part[i], ",")
			i++
			var/x = text2num(xy[1])
			var/y = text2num(xy[2])
			for (var/next in list("[x + 1],[y]", "[x - 1],[y]", "[x],[y + 1]", "[x],[y - 1]"))
				if (tiles[next] && !found[next])
					found[next] = TRUE
					part += next
		. += list(part)

// The ladders drawn with no clear tile of deck above them:
// list(list(level, "x,y")).
/datum/ship_draught/proc/nowhere_ladders()
	. = list()
	var/list/levels = list(0)
	for (var/level in ship_draught_decks)
		levels += text2num(level)
	for (var/level in levels)
		var/list/tiles = level ? decks["[level]"] : cells
		if (!tiles)
			continue
		for (var/key in tiles)
			var/list/C = tiles[key]
			if ((level ? C[1] : C[2]) != "X")
				continue
			var/list/xy = splittext(key, ",")
			if (!ladder_leads(level, text2num(xy[1]), text2num(xy[2])))
				. += list(list(level, key))

// TRUE when a ladder on level at x,y has a clear tile of deck above it.
/datum/ship_draught/proc/ladder_leads(level, x, y)
	var/up = level + 1
	var/list/above = deck_cell(up, x, y)
	// A main-deck cell keeps its piece second, a deck tile first.
	return above && !above[up ? 1 : 2]

// The tiles of a deck above (level 1 or more) with no wall or pillar on the
// level below near enough to carry them, as "x,y" keys. A hand-built roof
// needs the same (building_roof_error()).
/datum/ship_draught/proc/unsupported_deck_tiles(level)
	. = list()
	var/list/tiles = decks["[level]"]
	if (!tiles || level < 1)
		return
	var/below = level - 1
	var/list/base = below ? decks["[below]"] : cells
	var/list/supports = list()
	for (var/key in base)
		var/list/C = base[key]
		var/piece = below ? C[1] : C[2]
		var/list/P = piece ? ship_draught_pieces()[piece] : null
		if (P && P["carries"])
			var/list/xy = splittext(key, ",")
			supports += list(list(text2num(xy[1]), text2num(xy[2]), P["carries"]))
	for (var/key in tiles)
		var/list/xy = splittext(key, ",")
		var/x = text2num(xy[1])
		var/y = text2num(xy[2])
		var/held = FALSE
		for (var/list/S in supports)
			if (max(abs(S[1] - x), abs(S[2] - y)) <= S[3])
				held = TRUE
				break
		if (!held)
			. += key

// The parts of each deck off her main deck that no drawn ladder reaches:
// level text = list of parts, each a list of "x,y" keys.
/datum/ship_draught/proc/unreached_decks()
	. = list()
	for (var/level in ship_draught_decks)
		var/list/tiles = decks[level]
		if (!tiles)
			continue
		var/n = text2num(level)
		// A hold is climbed out of from itself; a deck above is climbed to
		// from the level below.
		var/from = n < 0 ? n : ship_draught_support(n)
		var/list/unreached = list()
		for (var/list/part in ship_draught_parts(tiles))
			var/reached = FALSE
			for (var/key in part)
				var/list/xy = splittext(key, ",")
				var/x = text2num(xy[1])
				var/y = text2num(xy[2])
				var/list/F = deck_cell(from, x, y)
				if (F && (from ? F[1] : F[2]) == "X" && ladder_leads(from, x, y))
					reached = TRUE
					break
			if (!reached)
				unreached += list(part)
		if (unreached.len)
			.[level] = unreached

// Why she could not be commissioned as drawn; an empty list when she could.
// The checks themselves are design checks of kind "ship" (draught_checks.dm).
/datum/ship_draught/proc/problems()
	return design_errors("ship", src)

// Everything the checks find: errors, warnings and advice. The caller owns
// the report.
/datum/ship_draught/proc/check_design()
	return design_report("ship", src)

/datum/ship_draught/proc/buildable()
	var/list/P = problems()
	return !P.len

// What building her takes: material = amount.
/datum/ship_draught/proc/costs()
	. = list()
	for (var/key in cells)
		var/list/C = cells[key]
		var/list/F = ship_draught_floors()[C[1]]
		ship_draught_add_cost(., F["cost"])
		if (C[2])
			var/list/P = ship_draught_pieces()[C[2]]
			ship_draught_add_cost(., P["cost"])
	for (var/level in decks)
		var/list/L = decks[level]
		var/list/deck = ship_draught_decks[level]
		for (var/key in L)
			var/list/D = L[key]
			ship_draught_add_cost(., deck["cost"])
			if (D[1])
				var/list/P = ship_draught_pieces()[D[1]]
				ship_draught_add_cost(., P["cost"])
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
		if (C[2] in list("W", "D", "G", "V", "I"))
			continue // a wall, door or window fills the tile
		var/list/xy = splittext(key, ",")
		var/x = text2num(xy[1])
		var/y = text2num(xy[2])
		for (var/d in cardinal)
			if ((C[2] in list("Y", "GP", "GS")) && C[3] == d)
				continue // her gangway or gun port closes that side
			if (!cell(x + (d == EAST ? 1 : d == WEST ? -1 : 0), y + (d == NORTH ? 1 : d == SOUTH ? -1 : 0)))
				. += list(list(key, d))

/datum/ship_draught/proc/costs_text()
	var/list/C = costs()
	var/list/parts = list()
	for (var/material in C)
		parts += "[C[material]] [material]"
	return parts.len ? english_list(parts) : "nothing"

// What stands on her decks weighs, in tiles of hull.
/datum/ship_draught/proc/load()
	. = 0
	for (var/key in cells)
		var/list/C = cells[key]
		if (C[2])
			var/list/P = ship_draught_pieces()[C[2]]
			. += P["load"]
	for (var/level in decks)
		var/list/L = decks[level]
		for (var/key in L)
			var/list/D = L[key]
			if (D[1])
				var/list/P = ship_draught_pieces()[D[1]]
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

// What she carries free: her fittings up to this weigh nothing extra.
/datum/ship_draught/proc/burden()
	return cells.len * DRAUGHT_BURDEN_PER_TILE

// What her drives push against, empty of cargo and crew: her tiles, and the
// weight of her fittings past her burden (small craft carry theirs free).
/datum/ship_draught/proc/mass()
	. = 0
	// Her floors by what they are made of, as a hull afloat counts them
	// (hull_weight.dm): her decks above are planked and her hold is plated.
	for (var/key in cells)
		var/list/C = cells[key]
		. += hull_material_weight(C[1] == "s" ? "steel" : "wood")
	for (var/level in decks)
		var/list/L = decks[level]
		. += L.len * hull_material_weight(text2num(level) < 0 ? "steel" : "wood")
	. = max(1, round(., 0.1))
	if (size_class() != HULL_CLASS_SMALL)
		. += max(0, round(load() - burden()))

// The best telegraph step her masts make on a reach, her benches manned, and
// both together (VESSEL_SPEED_SLOW when nothing makes more: she can be poled).
/datum/ship_draught/proc/sail_step()
	var/push = sail_push()
	return push / mass() >= CRAFT_THRUST_HALF ? VESSEL_SPEED_HALF : VESSEL_SPEED_SLOW

/datum/ship_draught/proc/oar_step()
	var/push = piece_count("R") * CRAFT_OAR_THRUST
	if (push / mass() >= CRAFT_THRUST_FULL)
		return VESSEL_SPEED_FULL
	return push / mass() >= CRAFT_THRUST_HALF ? VESSEL_SPEED_HALF : VESSEL_SPEED_SLOW

// What her engines push with every fire lit, against her mass, like her
// drives afloat (hull_drives.dm).
/datum/ship_draught/proc/engine_push()
	. = 0
	for (var/key in cells)
		var/list/C = cells[key]
		if (!C[2])
			continue
		var/list/P = ship_draught_pieces()[C[2]]
		if (P["drive"] != "engine")
			continue
		var/obj/structure/engine/E = P["path"]
		. += max(0, initial(E.maxpower))

/datum/ship_draught/proc/engine_step()
	var/push = engine_push()
	if (push / mass() >= CRAFT_THRUST_FULL)
		return VESSEL_SPEED_FULL
	return push / mass() >= CRAFT_THRUST_HALF ? VESSEL_SPEED_HALF : VESSEL_SPEED_SLOW

/datum/ship_draught/proc/best_step()
	var/oars = piece_count("R") * CRAFT_OAR_THRUST + engine_push()
	var/all = oars + sail_push()
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
	lines += "<b>[name]</b>: [cells.len] tile\s of hull[decks_text()], a [size_class_name()], bow to the top of the sheet."
	if (!cells.len)
		return jointext(lines, "<br>")
	lines += "Building her takes [costs_text()]."
	var/masts = mast_count() + piece_count("J")
	var/benches = piece_count("R")
	var/engines = engine_push()
	var/list/drives = list()
	if (masts)
		drives += "under sail on a reach: [ship_draught_step_name(sail_step())]"
	if (benches)
		drives += "with every bench manned: [ship_draught_step_name(oar_step())]"
	if (engines)
		drives += "under steam with every fire lit: [ship_draught_step_name(engine_step())]"
	if ((masts ? 1 : 0) + (benches ? 1 : 0) + (engines ? 1 : 0) > 1)
		drives += "with all of them: [ship_draught_step_name(best_step())]"
	if (drives.len)
		lines += "Empty, she should make [jointext(drives, "; ")]."
	var/datum/design_report/R = check_design()
	if (R.blocked())
		lines += "<span class='warning'>Not ready to build:</span>"
	else
		lines += "As drawn she can be built and commissioned."
	lines += R.chat_lines()
	qdel(R)
	return jointext(lines, "<br>")

// " and 12 of deck above and 20 of hold", or "" for a single deck.
/datum/ship_draught/proc/decks_text()
	. = ""
	for (var/level in ship_draught_decks)
		var/n = deck_tiles(text2num(level))
		if (n)
			. += " and [n] of [ship_draught_decks[level]["name"]]"

// The same summary as fields, for the designer window to lay out:
// what summary_text() says, nothing reckoned twice.
/datum/ship_draught/proc/summary_data()
	var/upper = other_deck_tiles()
	var/masts = mast_count() + piece_count("J")
	var/benches = piece_count("R")
	var/list/cost_parts = list()
	var/list/deck_rows = list()
	for (var/level in ship_draught_decks)
		var/n = deck_tiles(text2num(level))
		if (n)
			deck_rows += list(list(ship_draught_decks[level]["name"], n))
	var/list/drives = list()
	if (cells.len)
		var/list/C = costs()
		for (var/material in C)
			cost_parts += "[C[material]] [material]"
		if (masts)
			drives += list(list("Sail", ship_draught_step_name(sail_step())))
		if (benches)
			drives += list(list("Oars", ship_draught_step_name(oar_step())))
		var/engines = engine_push()
		if (engines)
			drives += list(list("Steam", ship_draught_step_name(engine_step())))
		if ((masts ? 1 : 0) + (benches ? 1 : 0) + (engines ? 1 : 0) > 1)
			drives += list(list("All", ship_draught_step_name(best_step())))
	var/datum/design_report/R = check_design()
	var/list/checks = R.data()
	qdel(R)
	return list(
		"name" = name,
		"tiles" = cells.len,
		"max_tiles" = SHIP_DRAUGHT_MAX_TILES,
		"upper" = upper,
		"decks" = deck_rows,
		"max_deck" = SHIP_DRAUGHT_MAX_DECK,
		"class" = size_class_name(),
		"costs" = cost_parts,
		"drives" = drives,
		"masts" = masts,
		"gunwales" = length(gunwale_sides()),
		"ballast" = cells.len ? wants_ballast() : 0,
		"problems" = problems(),
		"checks" = checks,
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
	var/list/others = list()
	var/plain = TRUE
	// Level by level, each in the order of her hull tiles, so a draught read
	// back writes the same code.
	for (var/level in ship_draught_decks)
		var/list/L = decks[level]
		if (!L)
			continue
		for (var/key in cells)
			var/list/D = L[key]
			if (!D)
				continue
			var/list/xy = splittext(key, ",")
			others += "[level],[text2num(xy[1]) - B[1]],[text2num(xy[2]) - B[2]],[D[1] ? D[1] : "-"],[D[2]]"
			if (level != "1" || D[1])
				plain = FALSE
	// A draught whose only other deck is a bare deck above says it all in
	// the upper flags, and keeps to the first format.
	if (plain)
		return "C13SHIP/1/[ship_draught_code_name(name)]/[jointext(tiles, ";")]"
	return "C13SHIP/2/[ship_draught_code_name(name)]/[jointext(tiles, ";")]/[jointext(others, ";")]"

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
	if (!F)
		F = design_code_fields(code, "SHIP", DESIGN_CODE_SHIP_MAX, 2)
		if (!F || F.len != 3)
			return null
	else if (F.len != 2)
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
	if (F.len < 3)
		return D
	// Her other decks, lowest first so each tile finds the one it rests on.
	var/list/others = length(F[3]) ? splittext(F[3], ";") : list()
	if (others.len > SHIP_DRAUGHT_MAX_DECK)
		qdel(D)
		return null
	var/list/by_level = list()
	for (var/tile in others)
		var/list/T = splittext(tile, ",")
		if (T.len != 5 || !ship_draught_decks[T[1]])
			qdel(D)
			return null
		if (!by_level[T[1]])
			by_level[T[1]] = list()
		by_level[T[1]] += list(T)
	for (var/level in ship_draught_decks)
		var/n = text2num(level)
		for (var/list/T in by_level[level])
			var/x = text2num(T[2])
			var/y = text2num(T[3])
			if (!D.set_deck(n, x, y, TRUE) || !D.set_deck_piece(n, x, y, T[4] == "-" ? null : T[4], text2num(T[5])))
				qdel(D)
				return null
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
	for (var/key in ship_draught_pieces())
		var/list/P = ship_draught_pieces()[key]
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
		if (istype(M, /obj/structure/railing/built/gunwale/bulwark/gun_port))
			return list("GS", M.dir)
		if (istype(M, /obj/structure/railing/built/gunwale/gun_port))
			return list("GP", M.dir)
		if (istype(M, /obj/structure/cargo_hatch))
			return list("CH", NORTH)
		if (istype(M, /obj/structure/railing/built/gunwale/bulwark/gangway))
			return list("Y", M.dir)
		if (istype(M, /obj/structure/multiz/ladder/up))
			return list("X", NORTH)
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
	var/tz = B.top_z()
	var/lz = B.lower_z()
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
		var/turf/U = B.upper_deck_cell(T, uz)
		D.survey_deck(1, x, y, U, angle)
		D.survey_deck(2, x, y, B.upper_deck_cell(U, tz), angle)
		D.survey_deck(-1, x, y, B.lower_deck_cell(T, lz), angle)
	return D

// Draws tile U of one of her other decks (null for none) at x,y, with what
// stands on it when it may stand on that deck.
/datum/ship_draught/proc/survey_deck(level, x, y, turf/U, angle)
	if (!U || !set_deck(level, x, y, TRUE))
		return
	var/list/piece = ship_draught_piece_on(U, null)
	if (piece)
		set_deck_piece(level, x, y, piece[1], (piece[2] in cardinal) ? turn(piece[2], angle) : NORTH)

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
	var/datum/vehicle_draught/car = vehicle_draught()
	if (car)
		to_chat(user, car.summary_text())
		qdel(car)
		return
	var/datum/air_draught/air = air_draught()
	if (air)
		to_chat(user, air.summary_text())
		qdel(air)
		return
	var/datum/station_plan/station = station_plan()
	if (station)
		to_chat(user, station.summary_text())
		qdel(station)
		return
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
	var/datum/vehicle_draught/car = vehicle_draught()
	if (car)
		vehicle_sheet_menu(H, car)
		qdel(car)
		return
	var/datum/air_draught/air = air_draught()
	if (air)
		air_sheet_menu(H, air)
		qdel(air)
		return
	var/datum/station_plan/station = station_plan()
	if (station)
		station_sheet_menu(H, station)
		qdel(station)
		return
	var/datum/ship_draught/D = draught()
	var/list/options = list("Draw on the sheet", "Paste a design code", "Cancel")
	if (D)
		options.Insert(2, "Copy her design code")
	else
		options.Insert(2, "Draw a submarine on the sheet")
		options.Insert(3, "Draw a vehicle on the sheet")
		options.Insert(4, "Draw an airship on the sheet")
		if (map && map.ordinal_age >= ORBIT_MIN_AGE)
			options.Insert(5, "Draw a space station on the sheet")
	var/choice = WWinput(H, D ? D.summary_text() : "The sheet is blank. Hold a pen or pencil to draw a ship on it.", name, "Cancel", options)
	if (choice == "Draw on the sheet")
		open_designer(H)
	else if (choice == "Draw a submarine on the sheet" && !draught_code)
		open_sub_designer(H)
	else if (choice == "Draw a vehicle on the sheet" && !draught_code)
		open_vehicle_designer(H)
	else if (choice == "Draw an airship on the sheet" && !draught_code)
		open_air_designer(H)
	else if (choice == "Draw a space station on the sheet" && !draught_code)
		open_station_designer(H)
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
