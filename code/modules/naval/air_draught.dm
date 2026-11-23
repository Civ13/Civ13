// ============================================================
// Airship sheets (docs/airship-sheets.md)
// ------------------------------------------------------------
// A ship's draught can carry a crewed airship (air_hull.dm): her deck tile
// by tile, bow to the top of the sheet and her port side on the left. Each
// tile may have a tile of deck, a gas cell hung over it and one part
// standing on it. The sheet also names the engine her engines are drawn for,
// by kind and size, as the engine maker makes them, and the crew she is
// drawn to carry.
//
// An airship yard (airship_yard.dm) builds a sheet from its stock; "Draw her
// lines" at an airship's helm draws an airship on a blank sheet of paper.
//
// A sheet travels as a design code (design_codes.dm):
//   C13AIR/1/<name>/<engine>/<cc>/<crew>/<width>/<length>/<col,row,deck,cell,part>;...
// where deck, cell and part are "-" for none.
// The checks are design checks of kind "air_sheet" (air_draught_checks.dm).
// ============================================================

#define AIR_DRAUGHT_NAME_MAX 40

// What her deck is laid from: each tile weighs air_weight against her lift.
/proc/air_draught_decks()
	var/static/list/table
	if (!table)
		table = list(
		"p" = list("name" = "airship planks", "path" = /obj/covers/airship_deck, "cost" = list("wood" = 3), "node" = "lighter_than_air_flight"),
		"a" = list("name" = "aluminium airship frame", "path" = /obj/covers/airship_deck/aluminium, "cost" = list("aluminium" = 3), "node" = "powered_flight"),
		"s" = list("name" = "steel airship frame", "path" = /obj/covers/airship_deck/steel, "cost" = list("steel" = 3), "node" = "powered_flight"),
		)
	return table

// The gas cells hung over a tile of deck; each holds up max_lift when full.
/proc/air_draught_cells()
	var/static/list/table
	if (!table)
		table = list(
		"c" = list("name" = "gas cell", "path" = /obj/structure/airship_gas_cell, "cost" = list("cloth" = 20), "node" = "lighter_than_air_flight"),
		"r" = list("name" = "rubberised gas cell", "path" = /obj/structure/airship_gas_cell/rubber, "cost" = list("cloth" = 20, "plastic" = 5), "node" = "lighter_than_air_flight"),
		"k" = list("name" = "goldbeater's skin cell", "path" = /obj/structure/airship_gas_cell/skin, "cost" = list("cloth" = 20, "casings" = 6), "node" = "lighter_than_air_flight"),
		)
	return table

// What can stand on a tile of deck. "E" is the sheet's own engine; the fuel
// tanks are the vehicle sheet's (craft/vehicle_draught.dm).
/proc/air_draught_parts()
	var/static/list/table
	if (!table)
		table = list(
		"W" = list("name" = "airship helm", "path" = /obj/structure/airship_helm, "cost" = list("wood" = 10), "node" = "lighter_than_air_flight"),
		"E" = list("name" = "engine", "path" = /obj/structure/engine/internal, "node" = "combustion"),
		"Y" = list("name" = "small fuel tank (120u)", "path" = /obj/item/weapon/reagent_containers/glass/barrel/fueltank/small, "cost" = list("steel" = 10), "tank" = TRUE, "node" = "combustion"),
		"M" = list("name" = "medium fuel tank (180u)", "path" = /obj/item/weapon/reagent_containers/glass/barrel/fueltank/smalltank, "cost" = list("steel" = 15), "tank" = TRUE, "node" = "combustion"),
		"T" = list("name" = "large fuel tank (250u)", "path" = /obj/item/weapon/reagent_containers/glass/barrel/fueltank, "cost" = list("steel" = 20), "tank" = TRUE, "node" = "combustion"),
		"X" = list("name" = "huge fuel tank (450u)", "path" = /obj/item/weapon/reagent_containers/glass/barrel/fueltank/tank, "cost" = list("steel" = 36), "tank" = TRUE, "node" = "combustion"),
		"B" = list("name" = "bomb hatch", "path" = /obj/structure/airship_bomb_hatch, "cost" = list("steel" = 6), "node" = "powered_flight"),
		)
	return table

/datum/air_draught
	var/name = "airship"
	var/engine = "gasoline"
	var/cc = 2000
	var/crew = 4
	var/width = 3
	var/length = 5
	// "col,row" = list(deck key or null, cell key or null, part key or null).
	// Column 1 is her port side, row 1 her bow.
	var/list/cells = list()

/datum/air_draught/New(new_width = 3, new_length = 5)
	..()
	if (!set_size(new_width, new_length))
		set_size(3, 5)

/datum/air_draught/proc/cell(col, row)
	return cells["[col],[row]"]

/datum/air_draught/proc/size_allowed(w, l)
	if (!isnum(w) || !isnum(l) || w != round(w) || l != round(l))
		return FALSE
	return w >= AIR_DRAUGHT_MIN && w <= AIR_DRAUGHT_MAX && l >= AIR_DRAUGHT_MIN && l <= AIR_DRAUGHT_MAX

// Resizes the sheet, keeping what is drawn on the tiles it keeps. New tiles
// are empty air.
/datum/air_draught/proc/set_size(w, l)
	if (!size_allowed(w, l))
		return FALSE
	width = w
	length = l
	var/list/kept = cells
	cells = list()
	for (var/row = 1, row <= length, row++)
		for (var/col = 1, col <= width, col++)
			var/list/old = kept["[col],[row]"]
			cells["[col],[row]"] = old ? old.Copy() : list(null, null, null)
	return TRUE

/datum/air_draught/proc/set_engine(new_engine, new_cc)
	var/list/E = vehicle_draught_engines[new_engine]
	if (!E || !isnum(new_cc) || new_cc != round(new_cc) || new_cc < E["min"] || new_cc > E["max"])
		return FALSE
	engine = new_engine
	cc = new_cc
	return TRUE

/datum/air_draught/proc/set_crew(new_crew)
	if (!isnum(new_crew) || new_crew != round(new_crew) || new_crew < 0 || new_crew > AIR_DRAUGHT_MAX_DECK)
		return FALSE
	crew = new_crew
	return TRUE

// A deck key, or null to leave the tile open air (taking its cell and part).
/datum/air_draught/proc/set_deck(col, row, deck)
	var/list/C = cell(col, row)
	if (!C || (deck && !air_draught_decks()[deck]))
		return FALSE
	C[1] = deck
	if (!deck)
		C[2] = null
		C[3] = null
	return TRUE

/datum/air_draught/proc/set_gas_cell(col, row, gas_cell)
	var/list/C = cell(col, row)
	if (!C || (gas_cell && (!air_draught_cells()[gas_cell] || !C[1])))
		return FALSE
	C[2] = gas_cell
	return TRUE

/datum/air_draught/proc/set_part(col, row, part)
	var/list/C = cell(col, row)
	if (!C || (part && (!air_draught_parts()[part] || !C[1])))
		return FALSE
	C[3] = part
	return TRUE

// The "col,row" keys of the tiles with this part key.
/datum/air_draught/proc/part_cells(part)
	. = list()
	for (var/key in cells)
		var/list/C = cells[key]
		if (C[3] == part)
			. += key

/datum/air_draught/proc/count_parts(part)
	var/list/L = part_cells(part)
	return L.len

/datum/air_draught/proc/tank_cells()
	. = list()
	for (var/key in cells)
		var/list/C = cells[key]
		var/list/P = C[3] ? air_draught_parts()[C[3]] : null
		if (P && P["tank"])
			. += key

/datum/air_draught/proc/deck_cells()
	. = list()
	for (var/key in cells)
		var/list/C = cells[key]
		if (C[1])
			. += key

/datum/air_draught/proc/gas_cells()
	. = list()
	for (var/key in cells)
		var/list/C = cells[key]
		if (C[2])
			. += key

// The tiles of deck joined edge to edge to the first, as the helm's survey
// takes her deck; the rest would be left behind.
/datum/air_draught/proc/joined_deck()
	var/list/deck = deck_cells()
	if (!deck.len)
		return list()
	var/list/found = list(deck[1])
	var/list/queue = list(deck[1])
	while (queue.len)
		var/list/at = splittext(queue[1], ",")
		queue.Cut(1, 2)
		var/col = text2num(at[1])
		var/row = text2num(at[2])
		for (var/list/step in list(list(0, 1), list(0, -1), list(1, 0), list(-1, 0)))
			var/key = "[col + step[1]],[row + step[2]]"
			var/list/N = cells[key]
			if (N && N[1] && !(key in found))
				found += key
				queue += key
	return found

/datum/air_draught/proc/part_path(part)
	if (part == "E")
		var/list/E = vehicle_draught_engines[engine]
		return E ? E["path"] : null
	var/list/P = air_draught_parts()[part]
	return P ? P["path"] : null

/datum/air_draught/proc/part_name(part)
	if (part == "E")
		return "[cc]cc [engine_name()]"
	var/list/P = air_draught_parts()[part]
	return P ? P["name"] : part

/datum/air_draught/proc/engine_name()
	var/list/E = vehicle_draught_engines[engine]
	return E ? E["name"] : engine

// What her deck weighs against her lift, as the helm weighs it: each tile's
// air_weight. People aboard weigh one each.
/datum/air_draught/proc/weight()
	. = 0
	for (var/key in cells)
		var/list/C = cells[key]
		var/list/K = C[1] ? air_draught_decks()[C[1]] : null
		if (K)
			var/obj/covers/airship_deck/P = K["path"]
			. += initial(P.air_weight)

/datum/air_draught/proc/crewed_weight()
	return weight() + crew

// What her gas cells hold up full of hydrogen, whole. Helium lifts a tenth less.
/datum/air_draught/proc/lift()
	. = 0
	for (var/key in cells)
		var/list/C = cells[key]
		var/list/G = C[2] ? air_draught_cells()[C[2]] : null
		if (G)
			var/obj/structure/airship_gas_cell/P = G["path"]
			. += initial(P.max_lift)

// What her engines push: each one's power, against her tiles of deck.
/datum/air_draught/proc/engine_power()
	var/list/E = vehicle_draught_engines[engine]
	if (!E)
		return 0
	var/obj/structure/engine/internal/P = E["path"]
	return initial(P.maxpower) * cc / 1000

/datum/air_draught/proc/engine_steel()
	var/list/E = vehicle_draught_engines[engine]
	return E ? -round(-E["steel"] * cc / 1000) : 0

/datum/air_draught/proc/costs()
	. = list()
	for (var/key in cells)
		var/list/C = cells[key]
		if (C[1])
			ship_draught_add_cost(., air_draught_decks()[C[1]]["cost"])
		if (C[2])
			ship_draught_add_cost(., air_draught_cells()[C[2]]["cost"])
		if (C[3] == "E")
			ship_draught_add_cost(., list("steel" = engine_steel()))
		else if (C[3])
			ship_draught_add_cost(., air_draught_parts()[C[3]]["cost"])

/datum/air_draught/proc/costs_text()
	var/list/C = costs()
	var/list/parts = list()
	for (var/material in C)
		parts += "[C[material]] [material == "casings" ? "sausage casings" : material]"
	return english_list(parts)

// The research nodes what is drawn needs.
/datum/air_draught/proc/nodes()
	. = list("lighter_than_air_flight")
	for (var/key in cells)
		var/list/C = cells[key]
		if (C[1])
			. |= air_draught_decks()[C[1]]["node"]
		if (C[2])
			. |= air_draught_cells()[C[2]]["node"]
		if (C[3])
			. |= air_draught_parts()[C[3]]["node"]

// Why she could not be built and flown as drawn; an empty list when she could.
/datum/air_draught/proc/problems()
	return design_errors("air_sheet", src)

// Everything the checks find. The caller owns the report.
/datum/air_draught/proc/check_design()
	return design_report("air_sheet", src)

/datum/air_draught/proc/summary_text()
	var/list/lines = list()
	var/list/deck = deck_cells()
	lines += "<b>[name]</b>: an airship of [deck.len] tile\s of deck in a [width] by [length] rectangle, bow to the top of the sheet."
	lines += "Building her takes [costs_text()]. Her engines are drawn as [cc]cc [engine_name()]s."
	lines += "Her deck weighs [weight()] and [weight() + crew] with a crew of [crew]; her gas cells hold up [lift()] full of hydrogen."
	var/datum/design_report/R = check_design()
	lines += R.blocked() ? "<span class='warning'>Not ready to build:</span>" : "As drawn she can be built at an airship yard."
	lines += R.chat_lines()
	qdel(R)
	return jointext(lines, "<br>")

// ---- Design codes ----

/datum/air_draught/proc/to_code()
	var/list/tiles = list()
	for (var/row = 1, row <= length, row++)
		for (var/col = 1, col <= width, col++)
			var/list/C = cell(col, row)
			if (!C[1])
				continue
			tiles += "[col],[row],[C[1]],[C[2] ? C[2] : "-"],[C[3] ? C[3] : "-"]"
	return "C13AIR/1/[ship_draught_code_name(name)]/[engine]/[cc]/[crew]/[width]/[length]/[jointext(tiles, ";")]"

// A sheet from a code, or null when the code is not a working airship code.
// Only tiles with deck are written; the rest are open air.
/proc/air_draught_from_code(code)
	var/list/F = design_code_fields(code, "AIR", DESIGN_CODE_AIR_MAX)
	if (!F || F.len != 7)
		return null
	var/w = text2num(F[5])
	var/l = text2num(F[6])
	var/datum/air_draught/D = new(w, l)
	if (D.width != w || D.length != l || !D.set_engine(F[2], text2num(F[3])) || !D.set_crew(text2num(F[4])))
		qdel(D)
		return null
	D.name = air_draught_clean_name(replacetext(F[1], "_", " "))
	var/list/tiles = length(F[7]) ? splittext(F[7], ";") : list()
	if (tiles.len > w * l)
		qdel(D)
		return null
	var/list/seen = list()
	for (var/tile in tiles)
		var/list/T = splittext(tile, ",")
		if (T.len != 5)
			qdel(D)
			return null
		var/col = text2num(T[1])
		var/row = text2num(T[2])
		if (seen["[col],[row]"] || !D.cell(col, row) || T[3] == "-")
			qdel(D)
			return null
		seen["[col],[row]"] = TRUE
		if (!D.set_deck(col, row, T[3]) || !D.set_gas_cell(col, row, T[4] == "-" ? null : T[4]) || !D.set_part(col, row, T[5] == "-" ? null : T[5]))
			qdel(D)
			return null
	return D

/proc/air_draught_clean_name(text)
	if (!istext(text))
		return "airship"
	text = replacetext(replacetext(replacetext(text, "/", " "), ";", " "), ",", " ")
	text = trim(sanitize(copytext(text, 1, AIR_DRAUGHT_NAME_MAX + 1)))
	return length(text) ? text : "airship"

// ---- Ready-made sheets ----

// A sheet from rows of "deck cell part" triples, bow row first, port tile
// first; "." is none, and a tile whose deck is "." is open air.
/proc/air_draught_from_rows(new_name, new_engine, new_cc, new_crew, list/rows)
	var/list/first = splittext(rows[1], " ")
	var/datum/air_draught/D = new(first.len, rows.len)
	D.name = new_name
	D.set_engine(new_engine, new_cc)
	D.set_crew(new_crew)
	for (var/row = 1, row <= rows.len, row++)
		var/list/tiles = splittext(rows[row], " ")
		for (var/col = 1, col <= tiles.len, col++)
			var/t = tiles[col]
			if (copytext(t, 1, 2) == ".")
				continue
			D.set_deck(col, row, copytext(t, 1, 2))
			D.set_gas_cell(col, row, copytext(t, 2, 3) == "." ? null : copytext(t, 2, 3))
			D.set_part(col, row, copytext(t, 3, 4) == "." ? null : copytext(t, 3, 4))
	return D

// Each one can be built as drawn (the probe checks).
/proc/air_draught_examples()
	. = list()
	// A wooden scout gondola with a small engine aft.
	. += air_draught_from_rows("scout airship", "gasoline", 1000, 3, list(
		".. pcW ..",
		"pc. pc. pc.",
		"pc. pcE pcY",
		".. pc. ..",
	))
	// An aluminium cargo ship with two engines and her tanks.
	. += air_draught_from_rows("cargo airship", "diesel", 3000, 6, list(
		"ac. arW ac.",
		"ac. ar. ac.",
		"ac. ar. ac.",
		"acE ar. acE",
		"acT ac. acT",
	))
	// A steel-framed bomber with skin cells and bomb hatches.
	. += air_draught_from_rows("airship bomber", "gasoline", 4000, 6, list(
		"sk. skW sk.",
		"skB sk. skB",
		"sk. skB sk.",
		"sk. sk. sk.",
		"skE skX skE",
		"sk. sk. sk.",
	))

// ---- The sheet ----

/obj/item/ship_draught/proc/air_draught()
	return draught_code ? air_draught_from_code(draught_code) : null

/obj/item/ship_draught/proc/air_draught_kind()
	return draught_code && design_code_kind(draught_code) == "AIR"

/obj/item/ship_draught/proc/take_air(datum/air_draught/D)
	draught_code = D ? D.to_code() : ""
	name = D ? "airship sheet ([D.name])" : initial(name)

/obj/item/ship_draught/proc/air_sheet_menu(mob/living/human/H, datum/air_draught/D)
	var/choice = WWinput(H, D.summary_text(), name, "Cancel", list("Draw on the sheet", DRAUGHT_EXPORT_LABEL, DRAUGHT_IMPORT_LABEL, "Cancel"))
	if (choice == "Draw on the sheet")
		open_air_designer(H)
	else if (choice == DRAUGHT_EXPORT_LABEL)
		draught_export(H, D.name)
	else if (choice == DRAUGHT_IMPORT_LABEL)
		draught_import(H)

// ---- Drawing an airship ----

// The sheet of a commissioned airship, or the reason she cannot be drawn.
// Her bow is the way her helm faces.
/proc/air_draught_survey(obj/structure/airship_helm/helm)
	if (!helm || !helm.craft || !helm.craft.body)
		return "Only a commissioned airship can have her lines drawn."
	var/datum/craft_body/built/air/B = helm.craft.body
	var/list/deck = B.cells()
	if (!deck.len)
		return "She has no deck to draw."
	var/turf/first = deck[1]
	var/min_x = first.x
	var/max_x = first.x
	var/min_y = first.y
	var/max_y = first.y
	for (var/turf/T in deck)
		min_x = min(min_x, T.x)
		max_x = max(max_x, T.x)
		min_y = min(min_y, T.y)
		max_y = max(max_y, T.y)
	var/facing = helm.dir
	if (!(facing in list(NORTH, SOUTH, EAST, WEST)))
		facing = NORTH
	var/w = (facing & (NORTH | SOUTH)) ? max_x - min_x + 1 : max_y - min_y + 1
	var/l = (facing & (NORTH | SOUTH)) ? max_y - min_y + 1 : max_x - min_x + 1
	var/datum/air_draught/D = new(w, l)
	if (D.width != w || D.length != l)
		qdel(D)
		return "She is [w] by [l] tiles; a sheet holds airships [AIR_DRAUGHT_MIN] to [AIR_DRAUGHT_MAX] tiles each way."
	D.name = air_draught_clean_name(helm.craft.name)
	for (var/turf/T in deck)
		var/col
		var/row
		switch (facing)
			if (NORTH)
				col = T.x - min_x + 1
				row = max_y - T.y + 1
			if (SOUTH)
				col = max_x - T.x + 1
				row = T.y - min_y + 1
			if (EAST)
				col = max_y - T.y + 1
				row = max_x - T.x + 1
			else
				col = T.y - min_y + 1
				row = T.x - min_x + 1
		D.set_deck(col, row, air_draught_deck_on(T))
		D.set_gas_cell(col, row, air_draught_cell_on(T))
		D.set_part(col, row, air_draught_part_on(D, T))
	for (var/turf/T in deck)
		var/obj/structure/engine/internal/E = locate() in T
		if (!E)
			continue
		for (var/key in vehicle_draught_engines)
			var/list/K = vehicle_draught_engines[key]
			if (E.type == K["path"])
				D.set_engine(key, E.enginesize)
		break
	return D

/proc/air_draught_deck_on(turf/T)
	var/obj/covers/airship_deck/K = locate() in T
	if (!K)
		return null
	for (var/key in air_draught_decks())
		if (K.type == air_draught_decks()[key]["path"])
			return key
	return "p"

/proc/air_draught_cell_on(turf/T)
	var/obj/structure/airship_gas_cell/G = locate() in T
	if (!G)
		return null
	for (var/key in air_draught_cells())
		if (G.type == air_draught_cells()[key]["path"])
			return key
	return "c"

// The most telling part on T: the helm, an engine, a bomb hatch, a tank.
/proc/air_draught_part_on(datum/air_draught/D, turf/T)
	if (locate(/obj/structure/airship_helm) in T)
		return "W"
	if (locate(/obj/structure/engine/internal) in T)
		return "E"
	if (locate(/obj/structure/airship_bomb_hatch) in T)
		return "B"
	for (var/key in list("X", "T", "M", "Y"))
		var/path = air_draught_parts()[key]["path"]
		for (var/obj/O in T)
			if (O.type == path)
				return key
	return null

// "Draw her lines" at the helm: a blank sheet in hand becomes her sheet.
/obj/structure/airship_helm/proc/draw_air_lines(mob/living/human/H)
	var/obj/item/weapon/paper/P = H.get_active_hand()
	if (!recipe_blank_paper(P))
		P = H.get_inactive_hand()
	if (!recipe_blank_paper(P))
		to_chat(H, SPAN_WARNING("Hold a blank sheet of paper to draw her lines on."))
		return
	var/survey = air_draught_survey(src)
	if (istext(survey))
		to_chat(H, SPAN_WARNING(survey))
		return
	var/datum/air_draught/D = survey
	if (!do_after(H, 50, src) || !recipe_blank_paper(P) || P.loc != H)
		qdel(D)
		return
	var/obj/item/ship_draught/S = new(get_turf(H))
	S.take_air(D)
	H.drop_from_inventory(P)
	qdel(P)
	H.put_in_hands(S)
	to_chat(H, SPAN_NOTICE("You draw the lines of the [D.name] on the sheet: [D.width] by [D.length] tiles, bow to the top."))
	qdel(D)

#undef AIR_DRAUGHT_NAME_MAX
