// ============================================================
// Checks for ship's draughts and submarine sheets (docs/design-checks.md)
// ------------------------------------------------------------
// The design checks (craft/design_checks.dm) a draught is judged by before
// anything is built. Errors are what stops her being commissioned (or a
// submarine being assembled): the caps, one joined hull, one helm. Warnings
// are things she can be built with that will not work well afloat. Notes
// are advice. Cell keys are the draught's own "x,y" (a submarine's
// "col,row"), so the designer windows can light the tiles up.
// ============================================================

// ---- Ships ----

/datum/design_check/ship
	kind = "ship"
	abstract_type = /datum/design_check/ship
	var/needs_drawing = TRUE // Skip a blank sheet: "nothing is drawn" says it all.

/datum/design_check/ship/check(datum/ship_draught/D, datum/design_report/R)
	if (!istype(D))
		return
	if (needs_drawing && !D.cells.len)
		return
	ship_check(D, R)

/datum/design_check/ship/proc/ship_check(datum/ship_draught/D, datum/design_report/R)
	return

// The "x,y" keys of every tile carrying piece.
/datum/ship_draught/proc/piece_cells(piece)
	. = list()
	for (var/key in cells)
		var/list/C = cells[key]
		if (C[2] == piece)
			. += key

// The "x,y" keys of every tile whose piece row has flag set.
/datum/ship_draught/proc/flagged_cells(flag)
	. = list()
	for (var/key in cells)
		var/list/C = cells[key]
		if (!C[2])
			continue
		var/list/P = ship_draught_pieces()[C[2]]
		if (P && P[flag])
			. += key

// The tile next to key in direction d, as a key.
/proc/ship_draught_step_key(key, d)
	var/list/xy = splittext(key, ",")
	var/x = text2num(xy[1])
	var/y = text2num(xy[2])
	switch (d)
		if (NORTH)
			y++
		if (SOUTH)
			y--
		if (EAST)
			x++
		if (WEST)
			x--
	return "[x],[y]"

// TRUE when a person can stand on the tile: no piece, or one they walk over
// or through.
/datum/ship_draught/proc/walkable(key)
	var/list/C = cells[key]
	if (!C)
		return FALSE
	if (!C[2])
		return TRUE
	var/list/P = ship_draught_pieces()[C[2]]
	if (!P)
		return TRUE
	// A door is shut on the sheet but crew open it.
	if (ispath(P["path"], /obj/structure/simple_door))
		return TRUE
	var/atom/A = P["path"]
	return !initial(A.density)

// The tiles crew can walk to from her sides, where they come aboard.
/datum/ship_draught/proc/reachable_cells()
	. = list()
	var/list/queue = list()
	for (var/key in cells)
		if (!walkable(key))
			continue
		for (var/d in cardinal)
			if (!cells[ship_draught_step_key(key, d)])
				.[key] = TRUE
				queue += key
				break
	while (queue.len)
		var/key = queue[1]
		queue.Cut(1, 2)
		for (var/d in cardinal)
			var/next = ship_draught_step_key(key, d)
			if (!.[next] && walkable(next))
				.[next] = TRUE
				queue += next

/datum/design_check/ship/drawn
	order = 10
	needs_drawing = FALSE

/datum/design_check/ship/drawn/ship_check(datum/ship_draught/D, datum/design_report/R)
	if (!D.cells.len)
		R.error("Nothing is drawn yet: draw her floors first.")

/datum/design_check/ship/caps
	order = 20

/datum/design_check/ship/caps/ship_check(datum/ship_draught/D, datum/design_report/R)
	if (D.cells.len > SHIP_DRAUGHT_MAX_TILES)
		R.error("She has [D.cells.len] tiles of hull: a hull may have at most [SHIP_DRAUGHT_MAX_TILES].")
	var/upper = D.other_deck_tiles()
	if (D.cells.len + upper > SHIP_DRAUGHT_MAX_DECK)
		R.error("Her decks are [D.cells.len + upper] tiles in all: at most [SHIP_DRAUGHT_MAX_DECK] can sail. Draw less deck off her main deck.")

/datum/design_check/ship/joined
	order = 30

/datum/design_check/ship/joined/ship_check(datum/ship_draught/D, datum/design_report/R)
	if (D.joined())
		return
	// Light up every tile not joined to her helm (or to her first tile).
	var/list/H = D.helms()
	var/start = H.len ? H[1] : D.cells[1]
	var/list/found = list("[start]" = TRUE)
	var/list/queue = list(start)
	while (queue.len)
		var/key = queue[1]
		queue.Cut(1, 2)
		for (var/d in cardinal)
			var/next = ship_draught_step_key(key, d)
			if (D.cells[next] && !found[next])
				found[next] = TRUE
				queue += next
	var/list/apart = list()
	for (var/key in D.cells)
		if (!found[key])
			apart += key
	R.error("Her floors are in more than one piece: every tile must touch another along an edge.", apart)

/datum/design_check/ship/helm
	order = 40

/datum/design_check/ship/helm/ship_check(datum/ship_draught/D, datum/design_report/R)
	var/list/H = D.helms()
	if (!H.len)
		R.error("She has no helm: put a tiller or a steering oar on one of her tiles.", null, "T")
	else if (H.len > 1)
		R.error("She has [H.len] helms: only one tiller or steering oar can steer her.", H, "T")

// A gangway stands on her edge, facing out over the side (hull_gangway.dm).
/datum/design_check/ship/gangways
	order = 45

/datum/design_check/ship/gangways/ship_check(datum/ship_draught/D, datum/design_report/R)
	var/list/inboard = list()
	for (var/key in D.piece_cells("Y"))
		var/list/C = D.cells[key]
		if (D.cells[ship_draught_step_key(key, C[3])])
			inboard += key
	if (inboard.len)
		R.error("[inboard.len] gangway\s face[inboard.len == 1 ? "s" : ""] her own deck: a gangway stands on her edge, facing out over the side.", inboard, "Y")

// A bowsprit carries her jib from her bow: nothing of hers ahead of it
// (hull_bow.dm).
/datum/design_check/ship/bowsprits
	order = 46

/datum/design_check/ship/bowsprits/ship_check(datum/ship_draught/D, datum/design_report/R)
	var/list/aft = list()
	for (var/key in D.piece_cells("J"))
		if (D.cells[ship_draught_step_key(key, NORTH)])
			aft += key
	if (aft.len)
		R.warning("[aft.len] bowsprit\s stand[aft.len == 1 ? "s" : ""] behind more of her deck: a jib draws only from a bowsprit at her bow, the top of the sheet.", aft, "J")

/datum/design_check/ship/drives
	order = 50

/datum/design_check/ship/drives/ship_check(datum/ship_draught/D, datum/design_report/R)
	var/masts = D.mast_count() + D.piece_count("J")
	var/benches = D.piece_count("R")
	var/engines = D.engine_push()
	if (!masts && !benches && !engines)
		R.warning("She has no masts, rowing benches or engine: she can only be poled along at slow ahead.", null, "M")
		return
	if (engines)
		R.note("A steam engine pushes her only while its fires burn: carry wood or coal, and light more fires under it for more power.", D.flagged_cells("drive"), "E")
	if (benches && !masts && !engines)
		R.note("Oars tire their rowers: on a long voyage she is paced by drives that can keep going for days, such as sails or an engine.", D.piece_cells("R"), "R")

/datum/design_check/ship/ballast
	order = 60

/datum/design_check/ship/ballast/ship_check(datum/ship_draught/D, datum/design_report/R)
	var/ballast = D.wants_ballast()
	if (ballast)
		R.warning("With [D.piece_count("M")] mast\s she wants about [ballast] more tiles of weight low in her as ballast, or she sails crank. Heavy fittings such as anchors, pumps or crates count.", D.piece_cells("M"), "M")

/datum/design_check/ship/burden
	order = 65

/datum/design_check/ship/burden/ship_check(datum/ship_draught/D, datum/design_report/R)
	if (D.size_class() == HULL_CLASS_SMALL)
		return
	var/over = round(D.load() - D.burden(), 0.1)
	if (over > 0)
		R.note("Her fittings weigh [over] tiles of hull more than her burden: every drive pushes that weight too, so she is slower than her size.")

/datum/design_check/ship/pumps
	order = 70

/datum/design_check/ship/pumps/ship_check(datum/ship_draught/D, datum/design_report/R)
	var/pumps = D.piece_count("P") + D.piece_count("Q") + D.piece_count("U")
	if (pumps)
		if (D.piece_count("U"))
			R.note("A sump pump runs on cable power or its own battery: lay cable to it from a generator aboard, or keep its battery charged.", D.piece_cells("U"), "U")
		return
	if (D.size_class() == HULL_CLASS_SMALL)
		return
	R.warning("She has no bilge pump: every leak and hole must be bailed by bucket. Fit a hand bilge pump at least.", null, "P")

/datum/design_check/ship/anchor
	order = 75

/datum/design_check/ship/anchor/ship_check(datum/ship_draught/D, datum/design_report/R)
	// Small craft need no anchor (hull_anchors.dm).
	if (D.size_class() == HULL_CLASS_SMALL)
		return
	var/holding = 0
	var/list/anchors = list()
	for (var/key in D.cells)
		var/list/C = D.cells[key]
		if (!C[2])
			continue
		var/list/P = ship_draught_pieces()[C[2]]
		if (!ispath(P["path"], /obj/structure/hull_anchor))
			continue
		var/obj/structure/hull_anchor/A = P["path"]
		holding += initial(A.holds)
		anchors += key
	if (!anchors.len)
		R.warning("She has no anchor: unless she lies beside a mooring post or a bollard, she drifts with anyone aboard and no way on. Fit a killick or an iron anchor.", null, "K")
	else if (holding < D.cells.len)
		R.warning("Her anchors hold [holding] tiles of hull and she has [D.cells.len]: they must cover every tile, so she drags. Fit another killick or an iron anchor.", anchors, "A")

/datum/design_check/ship/reach
	order = 80

/datum/design_check/ship/reach/ship_check(datum/ship_draught/D, datum/design_report/R)
	var/list/walk = D.reachable_cells()
	if (!walk.len)
		R.warning("Nobody can step aboard: every tile along her sides is blocked. Leave an open tile, a door or a bench at her side.")
		return
	// Pieces that are worked by hand must stand on or beside a tile crew reach.
	var/list/stranded = list()
	var/list/names = list()
	var/first = null
	for (var/key in D.cells)
		var/list/C = D.cells[key]
		if (!C[2])
			continue
		var/list/P = ship_draught_pieces()[C[2]]
		if (!P || ispath(P["path"], /obj/covers) || ispath(P["path"], /obj/structure/window_frame))
			continue
		var/reached = walk[key] ? TRUE : FALSE
		if (!reached)
			for (var/d in cardinal)
				if (walk[ship_draught_step_key(key, d)])
					reached = TRUE
					break
		if (!reached)
			stranded += key
			names |= P["name"]
			if (!first)
				first = C[2]
	if (stranded.len)
		R.warning("Crew cannot reach [english_list(names)]: walls, windows or other fittings shut [stranded.len == 1 ? "it" : "them"] in. Put a door in the way or move [stranded.len == 1 ? "it" : "them"].", stranded, first)

/datum/design_check/ship/aim
	order = 85

/datum/design_check/ship/aim/ship_check(datum/ship_draught/D, datum/design_report/R)
	var/list/inboard = list()
	var/list/cramped = list()
	var/first = null
	for (var/key in D.flagged_cells("fires"))
		var/list/C = D.cells[key]
		var/ahead = ship_draught_step_key(key, C[3])
		var/behind = ship_draught_step_key(key, turn(C[3], 180))
		if (D.cells[ahead])
			inboard += key
			if (!first)
				first = C[2]
		if (!D.walkable(behind))
			cramped += key
			if (!first)
				first = C[2]
	if (inboard.len)
		R.warning("[inboard.len == 1 ? "A gun points" : "[inboard.len] guns point"] across her own deck: turn [inboard.len == 1 ? "it" : "them"] to face out over the side or the bow.", inboard, first)
	if (cramped.len)
		R.warning("[cramped.len == 1 ? "A gun has" : "[cramped.len] guns have"] no open deck behind to load and fire from.", cramped, first)

/datum/design_check/ship/cabin
	order = 90

/datum/design_check/ship/cabin/ship_check(datum/ship_draught/D, datum/design_report/R)
	var/list/loose = list()
	for (var/key in D.cells)
		var/list/C = D.cells[key]
		if (C[2] != "D" && C[2] != "I")
			continue
		var/walled = FALSE
		for (var/d in cardinal)
			var/list/N = D.cells[ship_draught_step_key(key, d)]
			if (N && N[2] && (N[2] in list("W", "G", "V", "D", "I")))
				walled = TRUE
				break
		if (!walled)
			loose += key
	if (loose.len)
		R.note("[loose.len == 1 ? "A door stands" : "[loose.len] doors stand"] with no wall or window beside it: doors close off a cabin drawn with walls.", loose, "D")

/datum/design_check/ship/upper
	order = 95

/datum/design_check/ship/upper/ship_check(datum/ship_draught/D, datum/design_report/R)
	if (!D.upper_tiles())
		return
	R.note("Her deck above is roofed over her hull on the slipway, with open air over the berth, and sails with her. Climb to it by a ladder.", null, "u")

// Her decks off the main deck (ship_draught_decks): every ladder needs a clear
// tile of deck above it, and every part of her hold a ladder up out of it.
// A deck above no ladder reaches can still be climbed to by stairs or a
// ladder stood up afloat, so that is only a note.
/datum/design_check/ship/decks
	order = 97

/datum/design_check/ship/decks/ship_check(datum/ship_draught/D, datum/design_report/R)
	if (!D.decks.len && !D.piece_count("X"))
		return
	var/list/nowhere = D.nowhere_ladders()
	var/list/by_deck = list()
	for (var/list/L in nowhere)
		var/level = "[L[1]]"
		if (!by_deck[level])
			by_deck[level] = list()
		by_deck[level] += L[2]
	for (var/level in by_deck)
		var/list/keys = by_deck[level]
		R.error("[keys.len] ladder\s on her [ship_draught_level_name(text2num(level))] lead[keys.len == 1 ? "s" : ""] nowhere: a ladder needs a clear tile of the deck above it.", keys, "X", text2num(level))
	var/list/unreached = D.unreached_decks()
	for (var/level in unreached)
		var/list/parts = unreached[level]
		var/list/keys = list()
		for (var/list/part in parts)
			keys += part
		var/name = ship_draught_decks[level]["name"]
		var/what = parts.len == 1 ? "a part" : "[parts.len] parts"
		if (level == "-1")
			R.error("Her [name] has [what] with no ladder up to her deck: stand a ladder in it under a clear tile of deck.", keys, "X", -1)
		else
			R.note("No ladder is drawn up to [what] of her [name]: climb to it by stairs or a ladder stood up once she is afloat.", keys, "X", text2num(level))
	var/list/loose = D.unsupported_deck_tiles(1)
	if (loose.len)
		R.error("[loose.len] tile\s of her deck above [loose.len == 1 ? "has" : "have"] nothing to carry [loose.len == 1 ? "it" : "them"]: stand a deck pillar within 3 tiles below, or a plank wall beside [loose.len == 1 ? "it" : "them"].", loose, "S", 1)
	if (D.deck_tiles(2))
		R.note("Her second deck above is drawn for later: a ship afloat carries one deck above hers.", null, "u", 2)

// ---- Submarines ----

/datum/design_check/sub
	kind = "sub"
	abstract_type = /datum/design_check/sub

/datum/design_check/sub/check(datum/sub_draught/D, datum/design_report/R)
	if (istype(D))
		sub_check(D, R)

/datum/design_check/sub/proc/sub_check(datum/sub_draught/D, datum/design_report/R)
	return

/datum/sub_draught/proc/fitting_cells(fitting)
	. = list()
	for (var/key in cells)
		var/list/C = cells[key]
		if (C[2] == fitting)
			. += key

/datum/design_check/sub/fittings
	order = 10

/datum/design_check/sub/fittings/sub_check(datum/sub_draught/D, datum/design_report/R)
	for (var/fitting in sub_draught_fittings)
		var/list/P = sub_draught_fittings[fitting]
		var/need = P["need"]
		if (!need)
			continue
		var/count = D.fitting_count(fitting)
		if (count < need)
			R.error("She has no [P["name"]]: put one in a section.", null, fitting)
		else if (count > need)
			R.error("She has [count] of the [P["name"]]: only one works her.", D.fitting_cells(fitting), fitting)

/datum/design_check/sub/hatch
	order = 20

/datum/design_check/sub/hatch/sub_check(datum/sub_draught/D, datum/design_report/R)
	if (!D.hatches())
		R.error("She has no lock-out hatch: crew cannot board her or leave her under water. Make one of her side sections a hatch.", null, "x")

/datum/design_check/sub/bulkheads
	order = 30

/datum/design_check/sub/bulkheads/sub_check(datum/sub_draught/D, datum/design_report/R)
	// A bulkhead right across her with no door shuts off the rooms aft of it.
	for (var/row = 2, row <= D.length, row++)
		var/sealed = TRUE
		var/list/row_cells = list()
		for (var/col = 1, col <= SUB_DRAUGHT_BEAM, col++)
			var/list/C = D.cell(col, row)
			row_cells += "[col],[row]"
			if (!D.stern_tank(col, row) && C[3] != "b")
				sealed = FALSE
				break
		if (sealed)
			R.error("Row [row] is a bulkhead right across her: put a watertight door in it or nobody can reach the rooms aft.", row_cells, "wd")

/datum/design_check/sub/banks
	order = 40

/datum/design_check/sub/banks/sub_check(datum/sub_draught/D, datum/design_report/R)
	if (!D.fitting_count("E"))
		R.warning("She has no battery bank: her battery holds half what a Scout's does, so she runs flat under water twice as fast. Each bank adds another half.", null, "E")
	if (!D.fitting_count("A"))
		R.warning("She has no air bank: her reserve of air is half a Scout's, so a long dive turns foul twice as soon. Each bank adds another half.", null, "A")

/datum/design_check/sub/crew
	order = 50

/datum/design_check/sub/crew/sub_check(datum/sub_draught/D, datum/design_report/R)
	if (!D.fitting_count("B"))
		R.note("She has no berth: crew have nowhere to sleep on a long patrol.", null, "B")
	if (D.hatches() == 1)
		R.note("She has one lock-out hatch: only one diver at a time can leave or board her under water.", null, "x")
