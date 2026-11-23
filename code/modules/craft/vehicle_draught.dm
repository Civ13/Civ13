// ============================================================
// Vehicle sheets (docs/vehicle-sheets.md)
// ------------------------------------------------------------
// A ship's draught can carry a land vehicle or a plane instead of a ship:
// the plan of a hand-built vehicle (vehicle_assembly.dm) tile by tile, front
// to the top of the sheet and the vehicle's left on the left. Each tile has
// a frame, may have a wheel or track under it and may have one part standing
// on it. The sheet also names the axis the vehicle is built on and the
// engine it is drawn for, by kind and size, as the engine maker makes it.
//
// A sheet is built by hand: clip it to a loose axis and the axis's survey
// compares the frames and parts laid around it with the drawing, tile by
// tile, in whichever of the four facings fits best, and says what is still
// missing or different. Assembling then offers that facing first.
//
// "Draw its lines" at an assembled vehicle's axis draws any vehicle on a
// blank sheet of paper.
//
// A sheet travels as a design code (design_codes.dm):
//   C13CAR/1/<name>/<axis>/<engine>/<cc>/<width>/<length>/<col,row,frame,mover,part>;...
// where mover and part are "-" for none.
// The checks are design checks of kind "vehicle_sheet" (vehicle_draught_checks.dm).
// ============================================================

#define VEHICLE_DRAUGHT_NAME_MAX 40
#define VEHICLE_DRAUGHT_CREW_WEIGHT 40 // a seated crewman: MOB_MEDIUM * 2, as total_weight() counts him

// What the vehicle is built on. "frames" are the frame keys it takes; a
// plane's sizes are its airframe's (aircraft_assembly.dm).
var/global/list/vehicle_draught_axes = list(
	"car" = list("name" = "light axis", "path" = /obj/structure/vehicleparts/axis/car, "cost" = list("steel" = 10), "frames" = list("s", "w")),
	"heavy" = list("name" = "heavy axis", "path" = /obj/structure/vehicleparts/axis/heavy, "cost" = list("steel" = 30), "frames" = list("s", "w")),
	"plane" = list("name" = "airframe controls", "path" = /obj/structure/vehicleparts/axis/aircraft/airframe, "cost" = list("steel" = 12), "frames" = list("a")),
)

var/global/list/vehicle_draught_frames = list(
	"s" = list("name" = "steel vehicle frame", "path" = /obj/structure/vehicleparts/frame, "cost" = list("steel" = 2)),
	"w" = list("name" = "wood vehicle frame", "path" = /obj/structure/vehicleparts/frame/wood, "cost" = list("wood" = 2)),
	"a" = list("name" = "airframe section", "path" = /obj/structure/vehicleparts/frame/car/aircraft/section, "cost" = list("steel" = 4)),
)

// What runs under a frame. Only the four corners' are fitted.
var/global/list/vehicle_draught_movers = list(
	"W" = list("name" = "rubber wheel", "path" = /obj/structure/vehicleparts/movement, "cost" = list("steel" = 1)),
	"K" = list("name" = "tank track", "path" = /obj/structure/vehicleparts/movement/tracks, "cost" = list("steel" = 4)),
)

// What can stand on a frame. "E" is the sheet's own engine. "crew" is how
// many people the part seats; "with" are paths that stand with it.
var/global/list/vehicle_draught_parts = list(
	"E" = list("name" = "engine", "path" = /obj/structure/engine/internal),
	"Y" = list("name" = "small fuel tank (120u)", "path" = /obj/item/weapon/reagent_containers/glass/barrel/fueltank/small, "cost" = list("steel" = 10), "tank" = TRUE),
	"M" = list("name" = "medium fuel tank (180u)", "path" = /obj/item/weapon/reagent_containers/glass/barrel/fueltank/smalltank, "cost" = list("steel" = 15), "tank" = TRUE),
	"T" = list("name" = "large fuel tank (250u)", "path" = /obj/item/weapon/reagent_containers/glass/barrel/fueltank, "cost" = list("steel" = 20), "tank" = TRUE),
	"X" = list("name" = "huge fuel tank (450u)", "path" = /obj/item/weapon/reagent_containers/glass/barrel/fueltank/tank, "cost" = list("steel" = 36), "tank" = TRUE),
	"D" = list("name" = "driver's seat", "path" = /obj/structure/bed/chair/drivers, "cost" = list("steel" = 8), "crew" = 1, "driver" = TRUE),
	"G" = list("name" = "gunner's seat", "path" = /obj/structure/bed/chair/gunner, "cost" = list("steel" = 6), "crew" = 1),
	"L" = list("name" = "loader's seat", "path" = /obj/structure/bed/chair/loader, "cost" = list("steel" = 6), "crew" = 1),
	"C" = list("name" = "commander's seat", "path" = /obj/structure/bed/chair/commander, "cost" = list("steel" = 10), "crew" = 1),
	"U" = list("name" = "turret with cannon", "path" = /obj/structure/turret/built, "cost" = list("steel" = 76), "crew" = 1, "with" = list(/obj/structure/cannon/modern/tank, /obj/structure/bed/chair/gunner)),
	"H" = list("name" = "cargo hold", "path" = /obj/structure/cargo_hold, "cost" = list("steel" = 8)),
)

// The engines the engine maker makes (engines.dm): steel per 1000 cc, the
// sizes it allows and what each burns.
var/global/list/vehicle_draught_engines = list(
	"gasoline" = list("name" = "4-stroke gasoline engine", "path" = /obj/structure/engine/internal/gasoline, "steel" = 50, "min" = 80, "max" = 30000, "fuels" = list("gasoline")),
	"twostroke" = list("name" = "2-stroke gasoline engine", "path" = /obj/structure/engine/internal/gasoline/twostroke, "steel" = 40, "min" = 49, "max" = 1000, "fuels" = list("gasoline")),
	"efficient" = list("name" = "high efficiency gasoline engine", "path" = /obj/structure/engine/internal/gasoline/efficient, "steel" = 100, "min" = 100, "max" = 30000, "fuels" = list("gasoline")),
	"ethanol" = list("name" = "ethanol-gasoline engine", "path" = /obj/structure/engine/internal/gasoline/ethanol, "steel" = 60, "min" = 80, "max" = 30000, "fuels" = list("gasoline", "ethanol")),
	"diesel" = list("name" = "diesel engine", "path" = /obj/structure/engine/internal/diesel, "steel" = 40, "min" = 300, "max" = 45000, "fuels" = list("diesel")),
	"biodiesel" = list("name" = "biodiesel engine", "path" = /obj/structure/engine/internal/diesel/biodiesel, "steel" = 45, "min" = 300, "max" = 45000, "fuels" = list("diesel", "biodiesel")),
	"hesselman" = list("name" = "Hesselman engine", "path" = /obj/structure/engine/internal/hesselman, "steel" = 43, "min" = 200, "max" = 55000, "fuels" = list("diesel", "biodiesel", "gasoline")),
	"hotbulb" = list("name" = "hot bulb engine", "path" = /obj/structure/engine/internal/hotbulb, "steel" = 33, "min" = 200, "max" = 45000, "fuels" = list("any oil or fuel")),
	"turbine" = list("name" = "turbine engine", "path" = /obj/structure/engine/internal/turbine, "steel" = 73, "min" = 250, "max" = 18000, "fuels" = list("any oil or fuel")),
)

/datum/vehicle_draught
	var/name = "vehicle"
	var/axis = "car"
	var/engine = "gasoline"
	var/cc = 2000
	var/width = 2
	var/length = 3
	// "col,row" = list(frame key or null, mover key or null, part key or null).
	// Column 1 is the vehicle's left, row 1 its front.
	var/list/cells = list()

/datum/vehicle_draught/New(new_axis = "car", new_width = 2, new_length = 3)
	..()
	if (vehicle_draught_axes[new_axis])
		axis = new_axis
	if (!set_size(new_width, new_length))
		set_size(axis == "plane" ? 3 : 2, axis == "plane" ? 4 : 3)

/datum/vehicle_draught/proc/cell(col, row)
	return cells["[col],[row]"]

/datum/vehicle_draught/proc/plane()
	return axis == "plane"

// TRUE when a vehicle on this axis may be width by length.
/datum/vehicle_draught/proc/size_allowed(w, l)
	if (!isnum(w) || !isnum(l) || w != round(w) || l != round(l))
		return FALSE
	if (plane())
		return aircraft_airframe_size_ok(w, l)
	return w >= VEHICLE_DRAUGHT_MIN && w <= VEHICLE_DRAUGHT_MAX && l >= VEHICLE_DRAUGHT_MIN && l <= VEHICLE_DRAUGHT_MAX

// Resizes the sheet, keeping what is drawn on the tiles it keeps. New tiles
// get the axis's first frame.
/datum/vehicle_draught/proc/set_size(w, l)
	if (!size_allowed(w, l))
		return FALSE
	width = w
	length = l
	var/list/kept = cells
	cells = list()
	var/list/A = vehicle_draught_axes[axis]
	for (var/row = 1, row <= length, row++)
		for (var/col = 1, col <= width, col++)
			var/list/old = kept["[col],[row]"]
			cells["[col],[row]"] = old ? old.Copy() : list(A["frames"][1], null, null)
	return TRUE

// Changes the axis, swapping frames the new axis cannot take for its own.
/datum/vehicle_draught/proc/set_axis(new_axis)
	var/list/A = vehicle_draught_axes[new_axis]
	if (!A)
		return FALSE
	axis = new_axis
	if (!size_allowed(width, length))
		var/list/kept = cells
		width = plane() ? 3 : min(max(width, VEHICLE_DRAUGHT_MIN), VEHICLE_DRAUGHT_MAX)
		length = plane() ? min(max(length, 3), AIRCRAFT_MAX_LENGTH) : min(max(length, VEHICLE_DRAUGHT_MIN), VEHICLE_DRAUGHT_MAX)
		cells = kept
		set_size(width, length)
	for (var/key in cells)
		var/list/C = cells[key]
		if (C[1] && !(C[1] in A["frames"]))
			C[1] = A["frames"][1]
	return TRUE

/datum/vehicle_draught/proc/set_engine(new_engine, new_cc)
	var/list/E = vehicle_draught_engines[new_engine]
	if (!E || !isnum(new_cc) || new_cc != round(new_cc) || new_cc < E["min"] || new_cc > E["max"])
		return FALSE
	engine = new_engine
	cc = new_cc
	return TRUE

// A frame key, or null to leave the tile empty.
/datum/vehicle_draught/proc/set_frame(col, row, frame)
	var/list/C = cell(col, row)
	var/list/A = vehicle_draught_axes[axis]
	if (!C || (frame && !(frame in A["frames"])))
		return FALSE
	C[1] = frame
	if (!frame)
		C[2] = null
		C[3] = null
	return TRUE

/datum/vehicle_draught/proc/set_mover(col, row, mover)
	var/list/C = cell(col, row)
	if (!C || (mover && (!vehicle_draught_movers[mover] || !C[1])))
		return FALSE
	C[2] = mover
	return TRUE

/datum/vehicle_draught/proc/set_part(col, row, part)
	var/list/C = cell(col, row)
	if (!C || (part && (!vehicle_draught_parts[part] || !C[1])))
		return FALSE
	C[3] = part
	return TRUE

/datum/vehicle_draught/proc/is_corner(col, row)
	return (col == 1 || col == width) && (row == 1 || row == length)

// The "col,row" keys of the tiles with this part (or mover, or frame) key.
/datum/vehicle_draught/proc/part_cells(part)
	. = list()
	for (var/key in cells)
		var/list/C = cells[key]
		if (C[3] == part)
			. += key

/datum/vehicle_draught/proc/count_parts(part)
	var/list/L = part_cells(part)
	return L.len

/datum/vehicle_draught/proc/tank_cells()
	. = list()
	for (var/key in cells)
		var/list/C = cells[key]
		var/list/P = C[3] ? vehicle_draught_parts[C[3]] : null
		if (P && P["tank"])
			. += key

/datum/vehicle_draught/proc/frame_count()
	. = 0
	for (var/key in cells)
		var/list/C = cells[key]
		if (C[1])
			.++

// The path a part key stands for on this sheet: its engine, or a pilot's
// seat in a plane.
/datum/vehicle_draught/proc/part_path(part)
	if (part == "E")
		var/list/E = vehicle_draught_engines[engine]
		return E ? E["path"] : null
	if (part == "D" && plane())
		return /obj/structure/bed/chair/drivers/aircraft/loose
	var/list/P = vehicle_draught_parts[part]
	return P ? P["path"] : null

/datum/vehicle_draught/proc/part_name(part)
	if (part == "E")
		return "[cc]cc [engine_name()]"
	if (part == "D" && plane())
		return "pilot's seat"
	var/list/P = vehicle_draught_parts[part]
	return P ? P["name"] : part

/datum/vehicle_draught/proc/engine_name()
	var/list/E = vehicle_draught_engines[engine]
	return E ? E["name"] : engine

// How much a part weighs on its frame, the way total_weight() counts it.
/proc/vehicle_draught_path_weight(path)
	if (!ispath(path, /obj))
		return 0
	var/obj/O = path
	return initial(O.w_class) * 2

/datum/vehicle_draught/proc/part_weight(part)
	. = vehicle_draught_path_weight(part_path(part))
	var/list/P = vehicle_draught_parts[part]
	if (P && P["with"])
		for (var/path in P["with"])
			. += vehicle_draught_path_weight(path)

/datum/vehicle_draught/proc/crew()
	. = 0
	for (var/key in cells)
		var/list/C = cells[key]
		var/list/P = C[3] ? vehicle_draught_parts[C[3]] : null
		if (P && P["crew"])
			. += P["crew"]

// What it weighs empty, as the axis weighs it once assembled: the axis, and
// each frame with what stands on it. Fitted wheels lie inside their frames
// and weigh nothing.
/datum/vehicle_draught/proc/weight()
	var/list/A = vehicle_draught_axes[axis]
	. = 5 + vehicle_draught_path_weight(A["path"])
	for (var/key in cells)
		var/list/C = cells[key]
		if (!C[1])
			continue
		var/list/F = vehicle_draught_frames[C[1]]
		. += 10 + vehicle_draught_path_weight(F["path"])
		if (C[3])
			. += part_weight(C[3])

/datum/vehicle_draught/proc/crewed_weight()
	return weight() + crew() * VEHICLE_DRAUGHT_CREW_WEIGHT

// The most it can move: what the axis bears, and twice each engine's power
// (a twin-engine plane's wing engines share the load).
/datum/vehicle_draught/proc/axis_power()
	var/list/A = vehicle_draught_axes[axis]
	var/obj/structure/vehicleparts/axis/P = A["path"]
	. = initial(P.maxpower)
	if (plane() && width == 5)
		. = max(., aircraft_twin_wing_load(length))

/datum/vehicle_draught/proc/engine_power()
	var/list/E = vehicle_draught_engines[engine]
	if (!E)
		return 0
	var/obj/structure/engine/internal/P = E["path"]
	return initial(P.maxpower) * cc / 1000

/datum/vehicle_draught/proc/engine_limit()
	var/engines = count_parts("E")
	if (!engines)
		return 0
	return engine_power() * 2 * ((plane() && width == 5) ? min(engines, 3) : 1)

/datum/vehicle_draught/proc/move_limit()
	return min(axis_power(), engine_limit())

/datum/vehicle_draught/proc/engine_steel()
	var/list/E = vehicle_draught_engines[engine]
	return E ? -round(-E["steel"] * cc / 1000) : 0

/datum/vehicle_draught/proc/costs()
	. = list()
	var/list/A = vehicle_draught_axes[axis]
	ship_draught_add_cost(., A["cost"])
	for (var/key in cells)
		var/list/C = cells[key]
		if (C[1])
			var/list/F = vehicle_draught_frames[C[1]]
			ship_draught_add_cost(., F["cost"])
		if (C[2])
			var/list/M = vehicle_draught_movers[C[2]]
			ship_draught_add_cost(., M["cost"])
		if (C[3] == "E")
			ship_draught_add_cost(., list("steel" = engine_steel()))
		else if (C[3])
			var/list/P = vehicle_draught_parts[C[3]]
			ship_draught_add_cost(., P["cost"])

/datum/vehicle_draught/proc/costs_text()
	var/list/C = costs()
	var/list/parts = list()
	for (var/material in C)
		parts += "[C[material]] [material]"
	return english_list(parts)

/datum/vehicle_draught/proc/kind_word()
	if (plane())
		return "plane"
	if (count_parts("U"))
		return "tank"
	for (var/key in cells)
		var/list/C = cells[key]
		if (C[2] == "K")
			return "tracked vehicle"
	return count_parts("H") ? "truck" : "car"

// Why it could not be assembled as drawn; an empty list when it could.
/datum/vehicle_draught/proc/problems()
	return design_errors("vehicle_sheet", src)

// Everything the checks find. The caller owns the report.
/datum/vehicle_draught/proc/check_design()
	return design_report("vehicle_sheet", src)

/datum/vehicle_draught/proc/summary_text()
	var/list/A = vehicle_draught_axes[axis]
	var/list/lines = list()
	lines += "<b>[name]</b>: a [kind_word()] [width] tiles wide and [length] long on a [A["name"]], front to the top of the sheet."
	lines += "Building it takes [costs_text()]. It is drawn for a [cc]cc [engine_name()]."
	lines += "It weighs [round(weight())] empty and [round(crewed_weight())] with a crew of [crew()]; it can move [round(move_limit())] at most."
	var/datum/design_report/R = check_design()
	lines += R.blocked() ? "<span class='warning'>Not ready to build:</span>" : "As drawn it can be built by hand and assembled."
	lines += R.chat_lines()
	qdel(R)
	return jointext(lines, "<br>")

// ---- Design codes ----

/datum/vehicle_draught/proc/to_code()
	var/list/tiles = list()
	for (var/row = 1, row <= length, row++)
		for (var/col = 1, col <= width, col++)
			var/list/C = cell(col, row)
			tiles += "[col],[row],[C[1] ? C[1] : "-"],[C[2] ? C[2] : "-"],[C[3] ? C[3] : "-"]"
	return "C13CAR/1/[ship_draught_code_name(name)]/[axis]/[engine]/[cc]/[width]/[length]/[jointext(tiles, ";")]"

// A sheet from a code, or null when the code is not a working vehicle code.
/proc/vehicle_draught_from_code(code)
	var/list/F = design_code_fields(code, "CAR", DESIGN_CODE_CAR_MAX)
	if (!F || F.len != 7)
		return null
	if (!vehicle_draught_axes[F[2]])
		return null
	var/w = text2num(F[5])
	var/l = text2num(F[6])
	var/datum/vehicle_draught/D = new(F[2], w, l)
	if (D.width != w || D.length != l || !D.set_engine(F[3], text2num(F[4])))
		qdel(D)
		return null
	D.name = vehicle_draught_clean_name(replacetext(F[1], "_", " "))
	var/list/tiles = length(F[7]) ? splittext(F[7], ";") : list()
	if (tiles.len != w * l)
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
		if (seen["[col],[row]"] || !D.cell(col, row))
			qdel(D)
			return null
		seen["[col],[row]"] = TRUE
		if (!D.set_frame(col, row, T[3] == "-" ? null : T[3]) || !D.set_mover(col, row, T[4] == "-" ? null : T[4]) || !D.set_part(col, row, T[5] == "-" ? null : T[5]))
			qdel(D)
			return null
	return D

/proc/vehicle_draught_clean_name(text)
	if (!istext(text))
		return "vehicle"
	text = replacetext(replacetext(replacetext(text, "/", " "), ";", " "), ",", " ")
	text = trim(sanitize(copytext(text, 1, VEHICLE_DRAUGHT_NAME_MAX + 1)))
	return length(text) ? text : "vehicle"

// ---- Ready-made sheets ----

// A sheet from rows of "frame mover part" triples, front row first, left
// tile first; "." is none.
/proc/vehicle_draught_from_rows(new_name, new_axis, new_engine, new_cc, list/rows)
	var/list/first = splittext(rows[1], " ")
	var/datum/vehicle_draught/D = new(new_axis, first.len, rows.len)
	D.name = new_name
	D.set_engine(new_engine, new_cc)
	for (var/row = 1, row <= rows.len, row++)
		var/list/tiles = splittext(rows[row], " ")
		for (var/col = 1, col <= tiles.len, col++)
			var/t = tiles[col]
			D.set_frame(col, row, copytext(t, 1, 2) == "." ? null : copytext(t, 1, 2))
			D.set_mover(col, row, copytext(t, 2, 3) == "." ? null : copytext(t, 2, 3))
			D.set_part(col, row, copytext(t, 3, 4) == "." ? null : copytext(t, 3, 4))
	return D

// Each one can be built as drawn (the probe checks).
/proc/vehicle_draught_examples()
	. = list()
	. += vehicle_draught_from_rows("field car", "car", "gasoline", 2000, list("sWE sWT", "s.D s.C", "sW. sW."))
	. += vehicle_draught_from_rows("cargo truck", "car", "diesel", 4000, list("sWE sWT", "s.D s.C", "s.H s.H", "sWH sWH"))
	. += vehicle_draught_from_rows("light tank", "heavy", "diesel", 5000, list("sKE s.X sKC", "s.D s.U s.L", "sK. s.. sK."))
	. += vehicle_draught_from_rows("light plane", "plane", "gasoline", 3000, list("aWE a.. aWT", "a.. a.D a..", "a.. a.. a..", "aW. a.. aW."))
	// A twin's engines stand in the nacelles each side of the nose, each with
	// its tank; the cabin rows between the wings and the tail carry the seats.
	. += vehicle_draught_from_rows("twin transport", "plane", "gasoline", 3000, list("aW. a.E a.. a.E aW.", "a.Y a.. a.D a.. a.Y", "a.. a.C a.. a.C a..", "a.. a.C a.. a.C a..", "aW. a.. a.. a.. aW."))

// ---- The sheet ----

/obj/item/ship_draught/proc/vehicle_draught()
	return draught_code ? vehicle_draught_from_code(draught_code) : null

/obj/item/ship_draught/proc/vehicle_draught_kind()
	return draught_code && design_code_kind(draught_code) == "CAR"

/obj/item/ship_draught/proc/take_vehicle(datum/vehicle_draught/D)
	draught_code = D ? D.to_code() : ""
	name = D ? "vehicle sheet ([D.name])" : initial(name)

/obj/item/ship_draught/proc/vehicle_sheet_menu(mob/living/human/H, datum/vehicle_draught/D)
	var/choice = WWinput(H, D.summary_text(), name, "Cancel", list("Draw on the sheet", DRAUGHT_EXPORT_LABEL, DRAUGHT_IMPORT_LABEL, "Cancel"))
	if (choice == "Draw on the sheet")
		open_vehicle_designer(H)
	else if (choice == DRAUGHT_EXPORT_LABEL)
		draught_export(H, D.name)
	else if (choice == DRAUGHT_IMPORT_LABEL)
		draught_import(H)

// ---- Building from a sheet ----

/obj/structure/vehicleparts/axis
	// Saved: the design code of the vehicle sheet clipped to this axis.
	var/vehicle_sheet_code = null

/obj/structure/vehicleparts/axis/proc/clipped_sheet()
	return vehicle_sheet_code ? vehicle_draught_from_code(vehicle_sheet_code) : null

/obj/structure/vehicleparts/axis/attackby(obj/item/I, mob/living/human/H)
	var/obj/item/ship_draught/S = I
	if (istype(S) && istype(H) && !ship && S.vehicle_draught_kind())
		clip_sheet(S, H)
		return
	return ..()

/obj/structure/vehicleparts/axis/proc/clip_sheet(obj/item/ship_draught/S, mob/living/human/H)
	if (components.len)
		to_chat(H, SPAN_WARNING("\The [src] is assembled already. Take it apart first to build it again from a sheet."))
		return FALSE
	var/datum/vehicle_draught/D = S.vehicle_draught()
	if (!D)
		to_chat(H, SPAN_WARNING("The sheet cannot be read."))
		return FALSE
	var/list/A = vehicle_draught_axes[D.axis]
	if (!istype(src, A["path"]))
		to_chat(H, SPAN_WARNING("The [D.name] is drawn on a [A["name"]], not \a [src]."))
		qdel(D)
		return FALSE
	vehicle_sheet_code = S.draught_code
	to_chat(H, SPAN_NOTICE("You copy the [D.name] onto a tag and clip it to \the [src]. Click the axis to see what the frames around it still need."))
	qdel(D)
	return TRUE

// Where the sheet's tile (col, row) lies when the frames' rectangle faces
// facing, or null when the rectangle is not the sheet's size that way.
/datum/vehicle_survey/proc/sheet_turf(datum/vehicle_draught/D, col, row, facing)
	var/along = (facing & (NORTH | SOUTH)) ? height : width
	var/across = (facing & (NORTH | SOUTH)) ? width : height
	if (along != D.length || across != D.width)
		return null
	var/z = axis ? axis.z : 0
	switch (facing)
		if (NORTH)
			return locate(min_x + col - 1, max_y - row + 1, z)
		if (SOUTH)
			return locate(max_x - col + 1, min_y + row - 1, z)
		if (EAST)
			return locate(max_x - row + 1, max_y - col + 1, z)
		if (WEST)
			return locate(min_x + row - 1, min_y + col - 1, z)
	return null

// What the tile T lacks of the sheet's tile C, in words.
/datum/vehicle_survey/proc/sheet_tile_lacks(datum/vehicle_draught/D, list/C, turf/T)
	. = list()
	var/obj/structure/vehicleparts/frame/F = T ? vehicle_assembly_frame(T, axis) : null
	if (!F)
		var/list/FR = vehicle_draught_frames[C[1]]
		. += "\a [FR["name"]]"
		return
	if (C[1] == "w" && !istype(F, /obj/structure/vehicleparts/frame/wood))
		. += "a wood frame in place of \the [F]"
	else if (C[1] == "s" && istype(F, /obj/structure/vehicleparts/frame/wood))
		. += "a steel frame in place of \the [F]"
	if (C[2])
		var/list/M = vehicle_draught_movers[C[2]]
		var/found = FALSE
		var/list/runs = list()
		if (F.mwheel)
			runs += F.mwheel
		for (var/obj/structure/vehicleparts/movement/W in T)
			runs += W
		for (var/obj/structure/vehicleparts/movement/W in runs)
			if (istype(W, /obj/structure/vehicleparts/movement/sail))
				continue
			if (istype(W, /obj/structure/vehicleparts/movement/tracks) == (C[2] == "K"))
				found = TRUE
		if (!found)
			. += "\a [M["name"]]"
	if (C[3])
		var/path = D.part_path(C[3])
		var/atom/movable/P = path ? locate(path) in T : null
		if (!P)
			. += "\a [D.part_name(C[3])]"
		else if (C[3] == "E")
			var/obj/structure/engine/internal/E = P
			if (istype(E) && E.enginesize < D.cc)
				. += "a bigger engine: \the [E] is smaller than the [D.cc]cc drawn"
		var/list/PT = vehicle_draught_parts[C[3]]
		if (PT && PT["with"])
			for (var/with in PT["with"])
				if (!(locate(with) in T))
					var/atom/W = with
					. += "\a [initial(W.name)] with the turret"

// How the frames compare with the clipped sheet: list(best facing or null,
// lines of words).
/datum/vehicle_survey/proc/against_sheet(datum/vehicle_draught/D)
	var/list/lines = list()
	var/best = null
	var/list/best_lacks = null
	if (width && height)
		for (var/facing in list(NORTH, EAST, SOUTH, WEST))
			if (!sheet_turf(D, 1, 1, facing))
				continue
			var/list/lacks = list()
			for (var/row = 1, row <= D.length, row++)
				for (var/col = 1, col <= D.width, col++)
					var/list/C = D.cell(col, row)
					if (!C[1])
						continue
					var/list/L = sheet_tile_lacks(D, C, sheet_turf(D, col, row, facing))
					if (L.len)
						lacks += "[vehicle_draught_place(D, col, row)]: [english_list(L)]"
			if (!best_lacks || lacks.len < best_lacks.len)
				best = facing
				best_lacks = lacks
	lines += "<b>The sheet:</b> the [D.name], [D.width] wide and [D.length] long."
	if (!best_lacks)
		lines += "The frames here do not lie [D.width] by [D.length] tiles yet. Lay [D.frame_count()] frames in that rectangle around the axis, front to whichever side it should drive."
		return list(null, lines)
	if (!best_lacks.len)
		lines += "Everything on the sheet is laid out, front to the [dir2text(best)]."
		return list(best, lines)
	lines += "Laid front to the [dir2text(best)], it still needs:"
	for (var/i = 1, i <= min(best_lacks.len, 8), i++)
		lines += "- [best_lacks[i]]"
	if (best_lacks.len > 8)
		lines += "- and [best_lacks.len - 8] more tile\s."
	return list(best, lines)

// A tile in words, from the front left: "front row, 2nd from the left".
/proc/vehicle_draught_place(datum/vehicle_draught/D, col, row)
	var/row_word = row == 1 ? "front row" : (row == D.length ? "back row" : "row [row] from the front")
	var/col_word = col == 1 ? "left" : (col == D.width ? "right" : "[col][col == 2 ? "nd" : (col == 3 ? "rd" : "th")] from the left")
	return "[row_word], [col_word]"

// The clipped sheet's lines for the survey's report.
/datum/vehicle_survey/proc/sheet_lines()
	var/datum/vehicle_draught/D = axis ? axis.clipped_sheet() : null
	if (!D)
		return list()
	var/list/result = against_sheet(D)
	qdel(D)
	return result[2]

// The facing the clipped sheet fits best, for the assembly menu.
/obj/structure/vehicleparts/axis/proc/sheet_facing()
	var/datum/vehicle_draught/D = clipped_sheet()
	if (!D)
		return null
	var/datum/vehicle_survey/S = new(src)
	var/list/result = S.against_sheet(D)
	qdel(D)
	return result[1]

// ---- Drawing a vehicle ----

// The sheet of an assembled vehicle, or the reason it cannot be drawn.
/proc/vehicle_draught_survey(obj/structure/vehicleparts/axis/A)
	if (!A || !A.components.len || A.ship)
		return "Only an assembled land vehicle or plane can have its lines drawn."
	var/list/frames = list()
	for (var/obj/structure/vehicleparts/frame/F in A.components)
		if (F.axis == A)
			frames += F
	if (!frames.len)
		return "It has no frames to draw."
	var/min_x = frames[1]:x
	var/max_x = min_x
	var/min_y = frames[1]:y
	var/max_y = min_y
	for (var/obj/structure/vehicleparts/frame/F in frames)
		min_x = min(min_x, F.x)
		max_x = max(max_x, F.x)
		min_y = min(min_y, F.y)
		max_y = max(max_y, F.y)
	var/facing = A.dir
	var/w = (facing & (NORTH | SOUTH)) ? max_x - min_x + 1 : max_y - min_y + 1
	var/l = (facing & (NORTH | SOUTH)) ? max_y - min_y + 1 : max_x - min_x + 1
	var/new_axis = istype(A, /obj/structure/vehicleparts/axis/aircraft) ? "plane" : (A.maxpower > 800 ? "heavy" : "car")
	var/datum/vehicle_draught/D = new(new_axis, w, l)
	if (D.width != w || D.length != l)
		qdel(D)
		return "It is [w] by [l] tiles; a sheet holds vehicles [VEHICLE_DRAUGHT_MIN] to [VEHICLE_DRAUGHT_MAX] tiles each way[new_axis == "plane" ? ", and planes 3 wide and 3 to [AIRCRAFT_MAX_LENGTH] long or 5 wide and 4 to [AIRCRAFT_MAX_LENGTH] long" : ""]."
	D.name = vehicle_draught_clean_name(A.name)
	for (var/key in D.cells)
		D.set_frame(text2num(splittext(key, ",")[1]), text2num(splittext(key, ",")[2]), null)
	for (var/obj/structure/vehicleparts/frame/F in frames)
		var/col
		var/row
		switch (facing)
			if (NORTH)
				col = F.x - min_x + 1
				row = max_y - F.y + 1
			if (SOUTH)
				col = max_x - F.x + 1
				row = F.y - min_y + 1
			if (EAST)
				col = max_y - F.y + 1
				row = max_x - F.x + 1
			else
				col = F.y - min_y + 1
				row = F.x - min_x + 1
		D.set_frame(col, row, new_axis == "plane" ? "a" : (istype(F, /obj/structure/vehicleparts/frame/wood) ? "w" : "s"))
		if (F.mwheel && !istype(F.mwheel, /obj/structure/vehicleparts/movement/sail))
			D.set_mover(col, row, istype(F.mwheel, /obj/structure/vehicleparts/movement/tracks) ? "K" : "W")
		D.set_part(col, row, vehicle_draught_part_on(D, get_turf(F)))
	if (A.engine)
		for (var/key in vehicle_draught_engines)
			var/list/E = vehicle_draught_engines[key]
			if (A.engine.type == E["path"])
				var/obj/structure/engine/internal/I = A.engine
				D.set_engine(key, istype(I) ? I.enginesize : D.cc)
	return D

// The sheet's part key for what stands on T, or null. The most telling part
// wins: the engine, then a turret, a seat, a tank and a hold.
/proc/vehicle_draught_part_on(datum/vehicle_draught/D, turf/T)
	if (!T)
		return null
	if (locate(/obj/structure/engine/internal) in T)
		return "E"
	if (locate(/obj/structure/turret) in T)
		return "U"
	if (locate(/obj/structure/bed/chair/drivers) in T)
		return "D"
	for (var/key in list("C", "G", "L"))
		if (locate(D.part_path(key)) in T)
			return key
	for (var/key in list("X", "T", "M", "Y"))
		var/path = D.part_path(key)
		for (var/obj/O in T)
			if (O.type == path)
				return key
	if (locate(/obj/item/weapon/reagent_containers/glass/barrel/fueltank) in T)
		return "M"
	if (locate(/obj/structure/cargo_hold) in T)
		return "H"
	return null

// "Draw its lines" at the axis: a blank sheet in hand becomes its sheet.
/obj/structure/vehicleparts/axis/proc/draw_vehicle_lines(mob/living/human/H)
	var/obj/item/weapon/paper/P = H.get_active_hand()
	if (!recipe_blank_paper(P))
		P = H.get_inactive_hand()
	if (!recipe_blank_paper(P))
		to_chat(H, SPAN_WARNING("Hold a blank sheet of paper to draw its lines on."))
		return
	var/survey = vehicle_draught_survey(src)
	if (istext(survey))
		to_chat(H, SPAN_WARNING(survey))
		return
	var/datum/vehicle_draught/D = survey
	if (!do_after(H, 50, src) || !recipe_blank_paper(P) || P.loc != H)
		qdel(D)
		return
	var/obj/item/ship_draught/S = new(get_turf(H))
	S.take_vehicle(D)
	H.drop_from_inventory(P)
	qdel(P)
	H.put_in_hands(S)
	to_chat(H, SPAN_NOTICE("You draw the lines of [name] on the sheet: [D.width] by [D.length] tiles, front to the top."))
	qdel(D)

#undef VEHICLE_DRAUGHT_NAME_MAX
#undef VEHICLE_DRAUGHT_CREW_WEIGHT
