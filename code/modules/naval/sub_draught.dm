// ============================================================
// Submarine sheets (docs/ship-draught.md, "Submarine sheets")
// ------------------------------------------------------------
// A ship's draught can carry a submarine instead of a ship: the plan of her
// inside, section by section, three sections across and four to seven long,
// bow to the top of the sheet. Each section is pressure hull or a lock-out
// hatch, may have one fitting standing in it, and may have a bulkhead or a
// watertight door across its bow side.
//
// What every submarine has is drawn for the builder: the glass bow on the
// first row, the hull down both sides (open where a hatch is), and the
// stern row as the engine room, its outer sections sealed fuel and ballast
// tanks, the diesel and its tank in the middle. That is the Scout's and the
// Explorer's plan (submarine_layouts), and both are example sheets.
//
// layout() turns a sheet into the same "column,row" layout the pen and the
// hand assembly build from, with column 1 on the starboard side.
//
// A sheet travels as a design code (design_codes.dm):
//   C13SUB/1/<name>/<length>/<col,row,frame,fitting,wall>;...
// where fitting and wall are "-" for none.
// ============================================================

#define SUB_DRAUGHT_NAME_MAX 40
#define SUB_DRAUGHT_SECTION_STEEL 6 // a submarine hull section (material_recipes_global.txt)

// What a section is. "side" when it can only stand at the boat's sides.
var/global/list/sub_draught_frames = list(
	"h" = list("name" = "pressure hull", "path" = /obj/structure/vehicleparts/frame/ship/steel/submarine),
	"x" = list("name" = "lock-out hatch", "path" = /obj/structure/vehicleparts/frame/ship/steel/submarine/hatch, "side" = TRUE),
)

// What can stand in a section. Costs are the hand recipes (tests/ship_draught
// checks them). "need" is how many a working boat must have (0 for any).
var/global/list/sub_draught_fittings = list(
	"W" = list("name" = "ship's wheel", "path" = /obj/structure/vehicleparts/shipwheel, "cost" = list("wood" = 10), "need" = 1),
	"S" = list("name" = "ballast and periscope station", "path" = /obj/structure/vehicleparts/sub_station/loose, "cost" = list("steel" = 10), "need" = 1),
	"E" = list("name" = "battery bank", "path" = /obj/structure/vehicleparts/sub_fitting/battery/loose, "cost" = list("steel" = 8)),
	"A" = list("name" = "air bank", "path" = /obj/structure/vehicleparts/sub_fitting/air/loose, "cost" = list("steel" = 8)),
	"L" = list("name" = "locker", "path" = /obj/structure/closet, "cost" = list("iron" = 4)),
	"B" = list("name" = "berth", "path" = /obj/structure/bed/wood, "cost" = list("wood" = 4)),
)

// What can close a section's bow side: the letter set_hull_walls() reads.
var/global/list/sub_draught_walls = list(
	"b" = "bulkhead",
	"d" = "watertight door",
)

// What every boat carries besides her sections and fittings: the submarine
// controls and the stern fuel tank (the diesel is any engine the crew fits).
var/global/list/sub_draught_fixed_cost = list("steel" = 56)

/datum/sub_draught
	var/name = "submarine"
	var/length = 5
	// "col,row" = list(frame key, fitting key or null, bow-side wall key or null)
	var/list/cells = list()

/datum/sub_draught/New(new_length = 5)
	..()
	set_length(new_length)

/datum/sub_draught/proc/cell(col, row)
	return cells["[col],[row]"]

// Lengthens or shortens her, keeping what is drawn in the rows she keeps.
// The stern row is always the engine room, so a row that becomes the stern
// loses its fittings and its sides become tanks.
/datum/sub_draught/proc/set_length(new_length)
	if (!isnum(new_length) || new_length != round(new_length) || new_length < SUB_DRAUGHT_MIN_LENGTH || new_length > SUB_DRAUGHT_MAX_LENGTH)
		return FALSE
	length = new_length
	var/list/kept = cells
	cells = list()
	for (var/row = 1, row <= length, row++)
		for (var/col = 1, col <= SUB_DRAUGHT_BEAM, col++)
			var/list/old = kept["[col],[row]"]
			cells["[col],[row]"] = old ? old.Copy() : list("h", null, null)
			if (row == length || row == 1)
				var/list/C = cells["[col],[row]"]
				C[1] = "h"
				if (row == length)
					C[2] = null
					if (col != 2)
						C[3] = null
				if (row == 1)
					C[3] = null
	return TRUE

/datum/sub_draught/proc/stern_tank(col, row)
	return row == length && col != 2

/datum/sub_draught/proc/set_frame(col, row, frame)
	var/list/C = cell(col, row)
	var/list/F = sub_draught_frames[frame]
	if (!C || !F)
		return FALSE
	if (F["side"] && (col == 2 || row == 1 || row == length))
		return FALSE
	C[1] = frame
	return TRUE

/datum/sub_draught/proc/set_fitting(col, row, fitting)
	var/list/C = cell(col, row)
	if (!C || (fitting && !sub_draught_fittings[fitting]) || (fitting && row == length))
		return FALSE
	C[2] = fitting
	return TRUE

// A bulkhead or door across the bow side of a section. The first row's bow
// side is the glass, and the stern tanks are sealed already.
/datum/sub_draught/proc/set_wall(col, row, wall)
	var/list/C = cell(col, row)
	if (!C || (wall && !sub_draught_walls[wall]) || row == 1 || stern_tank(col, row))
		return FALSE
	C[3] = wall
	return TRUE

/datum/sub_draught/proc/fitting_count(fitting)
	. = 0
	for (var/key in cells)
		var/list/C = cells[key]
		if (C[2] == fitting)
			.++

/datum/sub_draught/proc/hatches()
	. = 0
	for (var/key in cells)
		var/list/C = cells[key]
		if (C[1] == "x")
			.++

// The walls of a section as set_hull_walls() reads them ("Fg Rh").
/datum/sub_draught/proc/wall_code(col, row)
	var/list/C = cell(col, row)
	if (!C)
		return ""
	var/list/parts = list()
	var/bow = row == 1
	var/stern = row == length
	if (bow)
		parts += "Fg"
	else if (stern_tank(col, row))
		parts += "Ft"
	else if (C[3])
		parts += "F[C[3]]"
	if (stern)
		parts += "Bh"
	if (C[1] != "x")
		if (col == 1)
			parts += bow ? "Rg" : "Rh"
		if (col == SUB_DRAUGHT_BEAM)
			parts += bow ? "Lg" : "Lh"
	// The stern tanks are walled off from the engine between them.
	if (stern_tank(col, row))
		parts += col == 1 ? "Lt" : "Rt"
	return jointext(parts, " ")

// Her plan in the submarine_layouts format: "col,row" = list(frame path,
// wall code, fittings...). The diesel and its tank stand in the stern.
/datum/sub_draught/proc/layout()
	. = list()
	for (var/row = 1, row <= length, row++)
		for (var/col = 1, col <= SUB_DRAUGHT_BEAM, col++)
			var/list/C = cell(col, row)
			var/list/F = sub_draught_frames[C[1]]
			var/list/entry = list(F["path"], wall_code(col, row))
			if (C[2])
				var/list/P = sub_draught_fittings[C[2]]
				entry += P["path"]
			if (row == length && col == 2)
				entry += /obj/structure/engine/internal/diesel/premade/chiha
				entry += /obj/item/weapon/reagent_containers/glass/barrel/fueltank/tank
			.["[col],[row]"] = entry

// Why she could not be assembled as drawn; an empty list when she could.
// The checks themselves are design checks of kind "sub" (draught_checks.dm).
/datum/sub_draught/proc/problems()
	return design_errors("sub", src)

// Everything the checks find: errors, warnings and advice. The caller owns
// the report.
/datum/sub_draught/proc/check_design()
	return design_report("sub", src)

/datum/sub_draught/proc/buildable()
	var/list/P = problems()
	return !P.len

/datum/sub_draught/proc/costs()
	. = list("steel" = length * SUB_DRAUGHT_BEAM * SUB_DRAUGHT_SECTION_STEEL)
	ship_draught_add_cost(., sub_draught_fixed_cost)
	for (var/key in cells)
		var/list/C = cells[key]
		if (C[2])
			var/list/P = sub_draught_fittings[C[2]]
			ship_draught_add_cost(., P["cost"])

/datum/sub_draught/proc/costs_text()
	var/list/C = costs()
	var/list/parts = list()
	for (var/material in C)
		parts += "[C[material]] [material]"
	return english_list(parts)

/datum/sub_draught/proc/summary_text()
	var/list/lines = list()
	lines += "<b>[name]</b>: a submarine [SUB_DRAUGHT_BEAM] sections across and [length] long, bow to the top of the sheet."
	lines += "Building her takes [costs_text()], and a diesel engine for her stern."
	var/batteries = fitting_count("E")
	var/air = fitting_count("A")
	var/list/banks = list()
	banks += batteries ? "[batteries] battery bank\s" : "no battery bank"
	banks += air ? "[air] air bank\s" : "no air bank"
	lines += "She carries [english_list(banks)], [hatches()] lock-out hatch[hatches() == 1 ? "" : "es"] and [fitting_count("B")] berth\s."
	// The same reckoning as battery_capacity() and air_capacity(): half a bank
	// in her hull and one more for each bank fitted.
	lines += "Her battery holds [round(50 * (1 + batteries))]% of a Scout's and her air bank [round(50 * (1 + air))]%."
	var/datum/design_report/R = check_design()
	if (R.blocked())
		lines += "<span class='warning'>Not ready to assemble:</span>"
	else
		lines += "As drawn she can be assembled on the water."
	lines += R.chat_lines()
	qdel(R)
	return jointext(lines, "<br>")

// ---- Design codes ----

/datum/sub_draught/proc/to_code()
	var/list/tiles = list()
	for (var/row = 1, row <= length, row++)
		for (var/col = 1, col <= SUB_DRAUGHT_BEAM, col++)
			var/list/C = cell(col, row)
			tiles += "[col],[row],[C[1]],[C[2] ? C[2] : "-"],[C[3] ? C[3] : "-"]"
	return "C13SUB/1/[ship_draught_code_name(name)]/[length]/[jointext(tiles, ";")]"

// A sheet from a code, or null when the code is not a working submarine code.
/proc/sub_draught_from_code(code)
	var/list/F = design_code_fields(code, "SUB", DESIGN_CODE_SUB_MAX)
	if (!F || F.len != 3)
		return null
	var/new_length = text2num(F[2])
	if (!isnum(new_length) || new_length < SUB_DRAUGHT_MIN_LENGTH || new_length > SUB_DRAUGHT_MAX_LENGTH || new_length != round(new_length))
		return null
	var/datum/sub_draught/D = new(new_length)
	D.name = sub_draught_clean_name(replacetext(F[1], "_", " "))
	var/list/tiles = length(F[3]) ? splittext(F[3], ";") : list()
	if (tiles.len != new_length * SUB_DRAUGHT_BEAM)
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
		if (seen["[col],[row]"])
			qdel(D)
			return null
		seen["[col],[row]"] = TRUE
		var/list/C = D.cell(col, row)
		if (!C || !sub_draught_frames[T[3]])
			qdel(D)
			return null
		// The fixed parts of her plan read back as drawn; anything else must
		// be something a builder could draw there.
		if ((T[3] != C[1] && !D.set_frame(col, row, T[3])) || (T[4] != "-" && !D.set_fitting(col, row, T[4])) || (T[5] != "-" && !D.set_wall(col, row, T[5])))
			qdel(D)
			return null
	return D

/proc/sub_draught_clean_name(text)
	if (!istext(text))
		return "submarine"
	text = replacetext(replacetext(replacetext(text, "/", " "), ";", " "), ",", " ")
	text = trim(sanitize(copytext(text, 1, SUB_DRAUGHT_NAME_MAX + 1)))
	return length(text) ? text : "submarine"

// ---- From a layout ----

// The fitting key for a path in a layout or on a deck, or null.
/proc/sub_draught_fitting_for(path)
	if (ispath(path, /obj/structure/closet))
		return "L"
	if (ispath(path, /obj/structure/bed))
		return "B"
	if (ispath(path, /obj/structure/vehicleparts/sub_station))
		return "S"
	if (ispath(path, /obj/structure/vehicleparts/sub_fitting/battery))
		return "E"
	if (ispath(path, /obj/structure/vehicleparts/sub_fitting/air))
		return "A"
	if (ispath(path, /obj/structure/vehicleparts/shipwheel))
		return "W"
	return null

// The bow-side wall key of a wall code, or null.
/proc/sub_draught_wall_for(code)
	for (var/part in splittext(code, " "))
		if (copytext(part, 1, 2) == "F" && sub_draught_walls[copytext(part, 2, 3)])
			return copytext(part, 2, 3)
	return null

// A sheet of a layout in the submarine_layouts format.
/proc/sub_draught_from_layout(list/layout, new_name)
	var/rows = 0
	for (var/coords in layout)
		rows = max(rows, text2num(splittext(coords, ",")[2]))
	var/datum/sub_draught/D = new(rows)
	if (D.length != rows)
		qdel(D)
		return null
	D.name = sub_draught_clean_name(new_name)
	for (var/coords in layout)
		var/list/xy = splittext(coords, ",")
		var/col = text2num(xy[1])
		var/row = text2num(xy[2])
		var/list/entry = layout[coords]
		if (ispath(entry[1], /obj/structure/vehicleparts/frame/ship/steel/submarine/hatch))
			D.set_frame(col, row, "x")
		D.set_wall(col, row, sub_draught_wall_for(entry[2]))
		for (var/i = 3, i <= entry.len, i++)
			var/fitting = sub_draught_fitting_for(entry[i])
			if (fitting)
				D.set_fitting(col, row, fitting)
	return D

// The ready-made sheets: the pen's Scout and Explorer.
/proc/sub_draught_examples()
	. = list()
	var/datum/sub_draught/scout = sub_draught_from_layout(submarine_layouts["scout"], "Scout")
	if (scout)
		. += scout
	var/datum/sub_draught/explorer = sub_draught_from_layout(submarine_layouts["explorer"], "Explorer")
	if (explorer)
		. += explorer

// ---- Drawing a submarine afloat ----

// Her sheet, read from the "class_col_row" art tile of each hull section, or
// the reason she cannot be drawn.
/proc/sub_draught_survey(obj/structure/vehicleparts/axis/ship/submarine/B)
	if (!B || !B.components.len)
		return "Only an assembled submarine can have her lines drawn."
	// A boat built from a sheet is drawn from it: her art tiles are the pen
	// boat's nearest length, not her own rows.
	var/datum/sub_draught/plan = B.sheet()
	if (plan)
		plan.name = sub_draught_clean_name(B.name)
		return plan
	var/list/layout = list()
	for (var/obj/structure/vehicleparts/frame/ship/steel/submarine/F in B.components)
		var/list/parts = splittext(F.hull_tile, "_")
		if (parts.len < 3)
			continue
		var/col = text2num(parts[parts.len - 1])
		var/row = text2num(parts[parts.len])
		if (!isnum(col) || !isnum(row))
			continue
		var/list/entry = list(F.type, F.wall_code())
		var/turf/T = get_turf(F)
		for (var/obj/O in T)
			if (O != F && sub_draught_fitting_for(O.type))
				entry += O.type
		layout["[col],[row]"] = entry
	var/datum/sub_draught/D = layout.len ? sub_draught_from_layout(layout, B.name) : null
	return D ? D : "Her hull is not one a sheet can show."

// The bow-side wall of a hull section as a wall code letter pair.
/obj/structure/vehicleparts/frame/ship/steel/submarine/proc/wall_code()
	if (!islist(w_front) || !length(w_front))
		return ""
	switch (w_front[1])
		if ("sub_bulkhead")
			return "Fb"
		if ("sub_door")
			return "Fd"
	return ""

// "Draw her lines" at the ballast station: a blank sheet in hand becomes her
// submarine sheet.
/obj/structure/vehicleparts/axis/ship/submarine/proc/draw_lines(mob/living/human/H, obj/structure/vehicleparts/sub_station/station)
	var/obj/item/weapon/paper/P = H.get_active_hand()
	if (!recipe_blank_paper(P))
		P = H.get_inactive_hand()
	if (!recipe_blank_paper(P))
		to_chat(H, SPAN_WARNING("Hold a blank sheet of paper to draw her lines on."))
		return
	var/survey = sub_draught_survey(src)
	if (istext(survey))
		to_chat(H, SPAN_WARNING(survey))
		return
	var/datum/sub_draught/D = survey
	if (!do_after(H, 50, station) || !recipe_blank_paper(P) || P.loc != H)
		qdel(D)
		return
	var/obj/item/ship_draught/S = new(get_turf(H))
	S.take_sub(D)
	H.drop_from_inventory(P)
	qdel(P)
	H.put_in_hands(S)
	to_chat(H, SPAN_NOTICE("You draw the lines of [name] on the sheet: [D.length] sections long, bow to the top."))
	qdel(D)

// ---- The sheet ----

/obj/item/ship_draught/proc/sub_draught()
	return draught_code ? sub_draught_from_code(draught_code) : null

/obj/item/ship_draught/proc/take_sub(datum/sub_draught/D)
	draught_code = D ? D.to_code() : ""
	name = D ? "submarine sheet ([D.name])" : initial(name)

// The sheet in hand when it carries a submarine.
/obj/item/ship_draught/proc/sub_sheet_menu(mob/living/human/H, datum/sub_draught/D)
	var/choice = WWinput(H, D.summary_text(), name, "Cancel", list("Draw on the sheet", "Copy her design code", "Paste a design code", "Cancel"))
	if (choice == "Draw on the sheet")
		open_sub_designer(H)
	else if (choice == "Copy her design code")
		design_code_show(H, "Submarine sheet: [D.name]", draught_code, "Paste it into any ship's draught to draw the same submarine.")
	else if (choice == "Paste a design code")
		paste_any_code(H)

// Pasting any kind of sheet's code onto it (draught_kinds).
/obj/item/ship_draught/proc/paste_any_code(mob/living/human/H)
	var/typed = design_code_ask(H, name, "Paste a ship, submarine, vehicle or airship design code (C13SHIP/..., C13SUB/..., C13CAR/... or C13AIR/...). It replaces what is drawn on this sheet.", draught_code_max())
	if (!typed || H.get_active_hand() != src)
		return
	var/kind = design_code_kind(typed)
	var/list/K = draught_kinds[kind]
	var/datum/D = K ? call(K["read"])(typed) : null
	if (!D)
		to_chat(H, SPAN_WARNING(design_code_refusal(typed, K ? kind : "SHIP")))
		return
	call(src, K["take"])(D)
	design_code_log(H, K["name"], name, typed)
	to_chat(H, SPAN_NOTICE("You draw the [D:name] on the sheet."))
	qdel(D)

#undef SUB_DRAUGHT_NAME_MAX
#undef SUB_DRAUGHT_SECTION_STEEL

// TRUE when the sheet carries a submarine code (read or not).
/obj/item/ship_draught/proc/sub_draught_kind()
	return draught_code && design_code_kind(draught_code) == "SUB"
