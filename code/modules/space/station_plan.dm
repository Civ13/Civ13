// ============================================================
// Space station plans (docs/station-plans.md)
// ------------------------------------------------------------
// A ship's draught can carry a space station: her habitat modules on a grid
// of STATION_PLAN_SIDE slots each way, north to the top of the sheet. Each
// slot holds one module or nothing; side by side modules dock, a hatch in
// the wall they share. The plan names one command module (the console, the
// supply crate, the life support and the way home) and one keel airlock,
// whose outer hatch opens on the keel of truss carrying her solar power,
// fuel cell and reboost thruster.
//
// A launch complex office (orbit_project.dm) given a plan builds that
// station instead of the starter layout: the plan rides with the first
// member who flies up and the station is founded from it on a free plane.
// "Draw her plan" at an orbit console draws a station on a blank sheet, and
// the station designer (station_designer.dm) is the window a plan is drawn in.
//
// A plan travels as a design code (design_codes.dm):
//   C13STATION/1/<name>/<col,row,piece>;...
// The checks are design checks of kind "station_plan" (station_plan_checks.dm).
// ============================================================

#define STATION_PLAN_NAME_MAX 40
// What every station costs: her keel, machines and the first modules.
#define STATION_PLAN_BASE_STEEL 180
// Steel for each module past those the starter station of the age has.
#define STATION_PLAN_EXTRA_STEEL 60
// The keel, counted in tiles out from the keel airlock's core.
#define STATION_KEEL_PORCH 7
#define STATION_KEEL_BOOM 9
#define STATION_KEEL_BOOM_REACH 3
#define STATION_KEEL_ISOTOPE 10
#define STATION_KEEL_FUEL 11
#define STATION_KEEL_AFT 12

// The modules a plan can hold. kit: the module kit whose recipe gates it.
/proc/station_plan_pieces()
	var/static/list/table
	if (!table)
		table = list(
		"C" = list("name" = "command module", "kind" = "station", "core" = /obj/structure/habitat_core, "kit" = /obj/item/habitat_kit/orbital_workshop),
		"Q" = list("name" = "quarters module", "kind" = "quarters", "core" = /obj/structure/habitat_core, "kit" = /obj/item/habitat_kit),
		"G" = list("name" = "greenhouse module", "kind" = "greenhouse", "core" = /obj/structure/habitat_core, "kit" = /obj/item/habitat_kit/greenhouse),
		"W" = list("name" = "workshop module", "kind" = "workshop", "core" = /obj/structure/habitat_core, "kit" = /obj/item/habitat_kit/workshop),
		"S" = list("name" = "storage module", "kind" = "storage", "core" = /obj/structure/habitat_core, "kit" = /obj/item/habitat_kit/storage),
		"N" = list("name" = "node module", "kind" = "node", "core" = /obj/structure/habitat_core/node, "kit" = /obj/item/habitat_kit/node),
		"A" = list("name" = "airlock", "kind" = "airlock", "core" = /obj/structure/habitat_core/airlock, "kit" = /obj/item/habitat_kit/airlock),
		"K" = list("name" = "keel airlock", "kind" = "airlock", "core" = /obj/structure/habitat_core/airlock, "kit" = /obj/item/habitat_kit/airlock),
		)
	return table

// How many modules the starter station of the world's age has: a plan of up
// to that many costs what the starter does.
/proc/station_plan_allowance()
	if (!map || map.ordinal_age < 8)
		return 3
	return map.ordinal_age >= 9 ? 8 : 5

/datum/station_plan
	var/name = "space station"
	// "col,row" = piece key. Column 1 is west, row 1 north.
	var/list/cells = list()

/datum/station_plan/proc/piece(col, row)
	return cells["[col],[row]"]

/datum/station_plan/proc/in_grid(col, row)
	return isnum(col) && isnum(row) && col == round(col) && row == round(row) && col >= 1 && row >= 1 && col <= STATION_PLAN_SIDE && row <= STATION_PLAN_SIDE

// A piece key, or null to clear the slot.
/datum/station_plan/proc/set_piece(col, row, key)
	if (!in_grid(col, row) || (key && !station_plan_pieces()[key]))
		return FALSE
	if (key)
		cells["[col],[row]"] = key
	else
		cells -= "[col],[row]"
	return TRUE

/datum/station_plan/proc/piece_cells(key)
	. = list()
	for (var/at in cells)
		if (cells[at] == key)
			. += at

/datum/station_plan/proc/module_count()
	return cells.len

// The slots beside at (north, south, east, west) that hold a module.
/datum/station_plan/proc/neighbours(at)
	. = list()
	var/list/xy = splittext(at, ",")
	var/col = text2num(xy[1])
	var/row = text2num(xy[2])
	for (var/list/step in list(list(0, -1), list(0, 1), list(1, 0), list(-1, 0)))
		var/key = "[col + step[1]],[row + step[2]]"
		if (cells[key])
			. += key

// Every module joined to the command module side by side, nearest first.
/datum/station_plan/proc/joined()
	var/list/start = piece_cells("C")
	if (!start.len)
		return list()
	var/list/found = list(start[1])
	var/i = 1
	while (i <= found.len)
		for (var/key in neighbours(found[i]))
			if (!(key in found))
				found += key
		i++
	return found

// How many hatches each joined module is from the command module.
/datum/station_plan/proc/hops()
	. = list()
	var/list/start = piece_cells("C")
	if (!start.len)
		return
	.[start[1]] = 0
	var/list/queue = list(start[1])
	var/i = 1
	while (i <= queue.len)
		var/at = queue[i]
		for (var/key in neighbours(at))
			if (isnull(.[key]))
				.[key] = .[at] + 1
				queue += key
		i++

// The way the keel runs from the keel airlock (away from the one module it
// docks to), or 0.
/datum/station_plan/proc/keel_dir()
	var/list/K = piece_cells("K")
	if (K.len != 1)
		return 0
	var/list/docked = neighbours(K[1])
	if (docked.len != 1)
		return 0
	var/list/a = splittext(K[1], ",")
	var/list/b = splittext(docked[1], ",")
	var/dc = text2num(a[1]) - text2num(b[1])
	var/dr = text2num(a[2]) - text2num(b[2])
	if (dc > 0)
		return EAST
	if (dc < 0)
		return WEST
	return dr > 0 ? SOUTH : NORTH

// The slots the keel and its boom pass over, which must stay empty.
/datum/station_plan/proc/keel_slots()
	. = list()
	var/dir = keel_dir()
	if (!dir)
		return
	var/list/K = splittext(piece_cells("K")[1], ",")
	var/col = text2num(K[1])
	var/row = text2num(K[2])
	var/fc = dir == EAST ? 1 : (dir == WEST ? -1 : 0)
	var/fr = dir == SOUTH ? 1 : (dir == NORTH ? -1 : 0)
	// The porch and keel run straight out three slots; the boom crosses the
	// second slot out and reaches into the slots either side of it.
	for (var/list/O in list(list(1, 0), list(2, -1), list(2, 0), list(2, 1), list(3, 0)))
		. += "[col + fc * O[1] + fr * O[2]],[row + fr * O[1] + fc * O[2]]"

/datum/station_plan/proc/costs()
	. = list("steel" = STATION_PLAN_BASE_STEEL + max(0, module_count() - station_plan_allowance()) * STATION_PLAN_EXTRA_STEEL, "glass" = 40, "copper" = 40, "electronics" = 60)

/datum/station_plan/proc/costs_text()
	var/list/C = costs()
	var/list/parts = list()
	for (var/material in C)
		parts += "[C[material]] [material]"
	return english_list(parts)

// The research nodes its modules need: their kits' recipes.
/datum/station_plan/proc/nodes()
	. = list()
	for (var/at in cells)
		var/list/P = station_plan_pieces()[cells[at]]
		var/node_id = P ? get_recipe_node_req("[P["kit"]]") : null
		if (node_id)
			. |= node_id

/datum/station_plan/proc/bunks()
	return piece_cells("Q").len * 2

/datum/station_plan/proc/problems()
	return design_errors("station_plan", src)

/datum/station_plan/proc/check_design()
	return design_report("station_plan", src)

/datum/station_plan/proc/summary_text()
	var/list/lines = list()
	lines += "<b>[name]</b>: a space station of [module_count()] module\s, north to the top of the sheet."
	lines += "A launch complex office builds her for [costs_text()]."
	var/datum/design_report/R = check_design()
	lines += R.blocked() ? "<span class='warning'>Not ready to build:</span>" : "As drawn she can be launched from a launch complex office."
	lines += R.chat_lines()
	qdel(R)
	return jointext(lines, "<br>")

// ---- Design codes ----

/datum/station_plan/proc/to_code()
	var/list/slots = list()
	for (var/row = 1, row <= STATION_PLAN_SIDE, row++)
		for (var/col = 1, col <= STATION_PLAN_SIDE, col++)
			var/key = piece(col, row)
			if (key)
				slots += "[col],[row],[key]"
	return "C13STATION/1/[ship_draught_code_name(name)]/[jointext(slots, ";")]"

/proc/station_plan_from_code(code)
	var/list/F = design_code_fields(code, "STATION", DESIGN_CODE_STATION_MAX)
	if (!F || F.len != 2)
		return null
	var/datum/station_plan/D = new
	D.name = station_plan_clean_name(replacetext(F[1], "_", " "))
	var/list/slots = length(F[2]) ? splittext(F[2], ";") : list()
	if (slots.len > STATION_PLAN_MAX_MODULES)
		qdel(D)
		return null
	for (var/slot in slots)
		var/list/T = splittext(slot, ",")
		if (T.len != 3)
			qdel(D)
			return null
		var/col = text2num(T[1])
		var/row = text2num(T[2])
		if (D.piece(col, row) || !T[3] || !D.set_piece(col, row, T[3]))
			qdel(D)
			return null
	return D

/proc/station_plan_clean_name(text)
	if (!istext(text))
		return "space station"
	text = replacetext(replacetext(replacetext(text, "/", " "), ";", " "), ",", " ")
	text = trim(sanitize(copytext(text, 1, STATION_PLAN_NAME_MAX + 1)))
	return length(text) ? text : "space station"

// ---- Ready-made plans ----

// A plan from rows of piece keys, north row first; "." is an empty slot.
// Rows are centred on the grid.
/proc/station_plan_from_rows(new_name, list/rows)
	var/datum/station_plan/D = new
	D.name = new_name
	var/top = round((STATION_PLAN_SIDE - rows.len) / 2)
	for (var/r = 1, r <= rows.len, r++)
		var/text = rows[r]
		var/left = round((STATION_PLAN_SIDE - length(text)) / 2)
		for (var/c = 1, c <= length(text), c++)
			var/key = copytext(text, c, c + 1)
			if (key != ".")
				D.set_piece(left + c, top + r, key)
	return D

// Each one can be built as drawn (the probe checks).
/proc/station_plan_examples()
	. = list()
	// The 1969 starter: command module, quarters east, the keel south.
	. += station_plan_from_rows("starter station", list(
		".CQ",
		".K.",
	))
	// The 2013 starter's shape: a node hub with its arms.
	. += station_plan_from_rows("hub station", list(
		".Q.",
		"GNC",
		".K.",
	))
	// A long working station, two airlocks.
	. += station_plan_from_rows("research station", list(
		"QQSG",
		"ACNW",
		"..K.",
	))

// ---- The sheet ----

/obj/item/ship_draught/proc/station_plan()
	return draught_code ? station_plan_from_code(draught_code) : null

/obj/item/ship_draught/proc/station_plan_kind()
	return draught_code && design_code_kind(draught_code) == "STATION"

/obj/item/ship_draught/proc/take_station(datum/station_plan/D)
	draught_code = D ? D.to_code() : ""
	name = D ? "station plan ([D.name])" : initial(name)

/obj/item/ship_draught/proc/station_sheet_menu(mob/living/human/H, datum/station_plan/D)
	var/choice = WWinput(H, D.summary_text(), name, "Cancel", list("Draw on the sheet", DRAUGHT_EXPORT_LABEL, DRAUGHT_IMPORT_LABEL, "Cancel"))
	if (choice == "Draw on the sheet")
		open_station_designer(H)
	else if (choice == DRAUGHT_EXPORT_LABEL)
		draught_export(H, D.name)
	else if (choice == DRAUGHT_IMPORT_LABEL)
		draught_import(H)

// ---- Drawing a station ----

// The plan of the station on plane z, or the reason it cannot be drawn. Her
// command module is the one holding the return hatch.
/proc/station_plan_survey(z)
	var/obj/structure/habitat_core/command = null
	for (var/obj/structure/region_gate/station_hatch/hatch in region_gates)
		if (hatch.z == z && !QDELETED(hatch))
			command = spacecraft_core_at(get_turf(hatch))
			break
	if (!command)
		return "Only a station with its return hatch can have her plan drawn."
	var/s = HABITAT_MODULE_SPACING
	// Each module's slot from the command module, then the box round them
	// centred on the sheet.
	var/list/found = list()
	var/min_c = 0
	var/max_c = 0
	var/min_r = 0
	var/max_r = 0
	for (var/obj/structure/habitat_core/C in orbit_station_modules(z))
		var/dx = C.x - command.x
		var/dy = C.y - command.y
		if (dx % s || dy % s)
			continue
		var/dc = dx / s
		var/dr = -dy / s
		found += list(list(dc, dr, C == command ? "C" : station_plan_piece_of(C)))
		min_c = min(min_c, dc)
		max_c = max(max_c, dc)
		min_r = min(min_r, dr)
		max_r = max(max_r, dr)
	if (max_c - min_c >= STATION_PLAN_SIDE || max_r - min_r >= STATION_PLAN_SIDE)
		return "She is [max_c - min_c + 1] by [max_r - min_r + 1] modules; a plan holds [STATION_PLAN_SIDE] each way."
	if (found.len > STATION_PLAN_MAX_MODULES)
		return "She has [found.len] modules; a plan holds [STATION_PLAN_MAX_MODULES]."
	var/left = 1 - min_c + round((STATION_PLAN_SIDE - (max_c - min_c + 1)) / 2)
	var/top = 1 - min_r + round((STATION_PLAN_SIDE - (max_r - min_r + 1)) / 2)
	var/datum/station_plan/D = new
	D.name = station_plan_clean_name(orbit_station_party(z) ? "[party_train_party_name(orbit_station_party(z))] station" : "space station")
	for (var/list/F in found)
		D.set_piece(F[1] + left, F[2] + top, F[3])
	// The airlock with truss outside it carries the keel.
	for (var/at in D.piece_cells("A"))
		var/list/xy = splittext(at, ",")
		var/turf/centre = locate(command.x + (text2num(xy[1]) - left) * s, command.y - (text2num(xy[2]) - top) * s, z)
		for (var/obj/structure/orbit_truss/T in range(STATION_KEEL_PORCH, centre))
			D.set_piece(text2num(xy[1]), text2num(xy[2]), "K")
			break
		if (D.piece_cells("K").len)
			break
	return D

/proc/station_plan_piece_of(obj/structure/habitat_core/C)
	if (istype(C, /obj/structure/habitat_core/airlock))
		return "A"
	if (istype(C, /obj/structure/habitat_core/node))
		return "N"
	switch (C.kind)
		if ("greenhouse")
			return "G"
		if ("workshop", "orbital workshop", "station")
			return "W"
		if ("storage")
			return "S"
	return "Q"

// "Draw her plan" at an orbit console: a blank sheet becomes her plan.
/obj/structure/orbit_console/attackby(obj/item/W, mob/user)
	var/mob/living/human/H = user
	if (!istype(H) || !recipe_blank_paper(W))
		return ..()
	var/survey = station_plan_survey(z)
	if (istext(survey))
		to_chat(H, SPAN_WARNING(survey))
		return TRUE
	var/datum/station_plan/D = survey
	if (!do_after(H, 50, src) || !recipe_blank_paper(W) || W.loc != H)
		qdel(D)
		return TRUE
	var/obj/item/ship_draught/S = new(get_turf(H))
	S.take_station(D)
	H.drop_from_inventory(W)
	qdel(W)
	H.put_in_hands(S)
	to_chat(H, SPAN_NOTICE("You draw the plan of the [D.name] on the sheet: [D.module_count()] module\s, north to the top."))
	qdel(D)
	return TRUE

// ---- Building a station from a plan ----

// The turf of slot (col, row) when the middle slot lies on centre.
/proc/station_plan_turf(turf/centre, col, row)
	var/middle = (STATION_PLAN_SIDE + 1) / 2
	return locate(centre.x + (col - middle) * HABITAT_MODULE_SPACING, centre.y - (row - middle) * HABITAT_MODULE_SPACING, centre.z)

// Steps from T n tiles one way, then side tiles the other.
/proc/station_plan_offset(turf/T, forward, n, side = 0)
	if (!T)
		return null
	var/fx = forward == EAST ? 1 : (forward == WEST ? -1 : 0)
	var/fy = forward == NORTH ? 1 : (forward == SOUTH ? -1 : 0)
	return locate(T.x + fx * n - fy * side, T.y + fy * n + fx * side, T.z)

// A cable along the line from A to B (one row or one column).
/proc/station_plan_cable(turf/A, turf/B)
	if (!A || !B)
		return list()
	return orbit_station_cable_run(A.x, A.y, B.x, B.y, A.z)

// Builds plan D in the middle of plane z for party, returning the return
// hatch, or null with nothing left half built when it does not fit there.
/proc/orbit_found_station_plan(party, z, datum/station_plan/D)
	if (!D || length(D.problems()))
		return null
	var/turf/centre = locate(round(world.maxx / 2), round(world.maxy / 2), z)
	if (!centre)
		return null
	var/keel = D.keel_dir()
	var/list/K = splittext(D.piece_cells("K")[1], ",")
	var/turf/keel_lock = station_plan_turf(centre, text2num(K[1]), text2num(K[2]))
	// Every module and the whole keel must fit clear on the plane.
	var/list/order = D.joined()
	for (var/at in order)
		var/list/xy = splittext(at, ",")
		var/turf/T = station_plan_turf(centre, text2num(xy[1]), text2num(xy[2]))
		if (!T || habitat_module_refusal(T, null))
			return null
	var/turf/aft = station_plan_offset(keel_lock, keel, STATION_KEEL_AFT)
	if (!aft || aft.x < 3 || aft.y < 3 || aft.x > world.maxx - 2 || aft.y > world.maxy - 2)
		return null
	for (var/side in list(-STATION_KEEL_BOOM_REACH, STATION_KEEL_BOOM_REACH))
		var/turf/tip = station_plan_offset(keel_lock, keel, STATION_KEEL_BOOM, side)
		if (!tip || tip.x < 3 || tip.y < 3 || tip.x > world.maxx - 2 || tip.y > world.maxy - 2)
			return null
	var/modern = map && map.ordinal_age >= 8
	// The modules, nearest the command module first, so each docks to those built.
	var/obj/structure/habitat_core/command = null
	var/list/cores = list()
	for (var/at in order)
		var/list/xy = splittext(at, ",")
		var/list/P = station_plan_pieces()[D.cells[at]]
		var/turf/T = station_plan_turf(centre, text2num(xy[1]), text2num(xy[2]))
		var/obj/structure/habitat_core/C = habitat_unfold(T, P["kind"], P["core"], keel, D.cells[at] != "C")
		cores[at] = C
		if (D.cells[at] == "C")
			command = C
	// The cable: a bar along the command module's top row for its life
	// support, then core to core along the hatches to the keel airlock and
	// out along the keel.
	var/cx = command.x
	var/cy = command.y
	var/list/spine = orbit_station_cable_run(cx - 1, cy + 1, cx + 1, cy + 1, z)
	orbit_station_cable_run(cx, cy + 1, cx, cy, z)
	var/list/path = station_plan_path(D, cores)
	for (var/i = 1, i < path.len, i++)
		var/obj/structure/habitat_core/A = path[i]
		var/obj/structure/habitat_core/B = path[i + 1]
		station_plan_cable(get_turf(A), get_turf(B))
	station_plan_cable(keel_lock, aft)
	orbit_station_place(/obj/structure/life_support/heater, cx - 1, cy + 1, z)
	orbit_station_place(/obj/structure/life_support/scrubber, cx, cy + 1, z)
	orbit_station_place(/obj/structure/life_support/radiator, cx + 1, cy + 1, z)
	// The keel: a cross boom with a wing at each end, then the generators.
	station_plan_cable(station_plan_offset(keel_lock, keel, STATION_KEEL_BOOM, -STATION_KEEL_BOOM_REACH), station_plan_offset(keel_lock, keel, STATION_KEEL_BOOM, STATION_KEEL_BOOM_REACH))
	var/wing_type = modern ? /obj/structure/civ_generator/solar/wing/tracking : /obj/structure/civ_generator/solar/wing
	for (var/side in list(-STATION_KEEL_BOOM_REACH, STATION_KEEL_BOOM_REACH))
		var/turf/tip = station_plan_offset(keel_lock, keel, STATION_KEEL_BOOM, side)
		var/obj/structure/civ_generator/solar/wing/W = orbit_station_place(wing_type, tip.x, tip.y, z)
		W.enabled = TRUE
	if (modern)
		var/turf/iso = station_plan_offset(keel_lock, keel, STATION_KEEL_ISOTOPE)
		var/obj/structure/civ_generator/isotope/I = orbit_station_place(/obj/structure/civ_generator/isotope, iso.x, iso.y, z)
		I.enabled = TRUE
	var/turf/fuel = station_plan_offset(keel_lock, keel, STATION_KEEL_FUEL)
	var/obj/structure/civ_generator/fuel_cell/F = orbit_station_place(/obj/structure/civ_generator/fuel_cell, fuel.x, fuel.y, z)
	F.hydrogen = F.tank_max
	F.oxygen = F.tank_max
	var/obj/structure/cable/joint = spine[1]
	joint.rebuild_supply()
	var/obj/structure/orbit_thruster/thruster = new(aft)
	thruster.propellant = ORBIT_REBOOST_COST * (modern ? 6 : 3)
	orbit_set_station_altitude(party, ORBIT_ALTITUDE_START)
	// Truss from the porch to the aft end and along the boom, as handholds.
	var/list/frame = list()
	for (var/n = STATION_KEEL_PORCH, n <= STATION_KEEL_AFT, n++)
		frame |= station_plan_offset(keel_lock, keel, n)
	for (var/side = -STATION_KEEL_BOOM_REACH, side <= STATION_KEEL_BOOM_REACH, side++)
		frame |= station_plan_offset(keel_lock, keel, STATION_KEEL_BOOM, side)
	orbit_station_truss(frame)
	// The command module: a bench, the supply crate, the console and the way home.
	new /obj/structure/table(locate(cx - 1, cy, z))
	var/obj/structure/closet/crate/crate = new(locate(cx - 1, cy - 1, z))
	for (var/path_type in list(/obj/item/habitat_sealant, /obj/item/habitat_sealant, /obj/item/clothing/suit/pressure_suit, /obj/item/clothing/suit/pressure_suit, /obj/item/clothing/head/pressure_helmet, /obj/item/clothing/head/pressure_helmet, /obj/item/pressure_tank, /obj/item/pressure_tank, /obj/item/pressure_suit_patch, /obj/item/eva_tether, /obj/item/eva_tether, /obj/item/stack/cable_coil/yellow, /obj/item/sorbent_cartridge, /obj/item/sorbent_cartridge))
		new path_type(crate)
	if (modern)
		new /obj/item/habitat_kit/node(crate)
	if (map.ordinal_age >= 9)
		new /obj/item/sector_beacon(crate)
	for (var/i in 1 to 6)
		new /obj/item/weapon/reagent_containers/food/snacks/MRE/generic(crate)
	for (var/i in 1 to 3)
		new /obj/item/weapon/reagent_containers/food/drinks/bottle/canteen(crate)
	new /obj/structure/orbit_console(locate(cx + 1, cy - 1, z))
	var/obj/structure/region_gate/station_hatch/hatch = new(locate(cx, cy - 1, z))
	hatch.party = party
	log_game("Orbit station: [party] founded the [D.name] from a plan on plane [z] ([D.module_count()] modules).")
	return hatch

// The cores from the command module to the keel airlock, one hatch at a time.
/proc/station_plan_path(datum/station_plan/D, list/cores)
	var/list/start = D.piece_cells("C")
	var/list/goal = D.piece_cells("K")
	var/list/came = list()
	came[start[1]] = start[1]
	var/list/queue = list(start[1])
	var/i = 1
	while (i <= queue.len && isnull(came[goal[1]]))
		var/at = queue[i]
		for (var/key in D.neighbours(at))
			if (isnull(came[key]))
				came[key] = at
				queue += key
		i++
	var/list/way = list()
	var/at = goal[1]
	while (at && !isnull(came[at]))
		way.Insert(1, cores[at])
		if (at == start[1])
			break
		at = came[at]
	return way

#undef STATION_PLAN_NAME_MAX
#undef STATION_PLAN_BASE_STEEL
#undef STATION_PLAN_EXTRA_STEEL
#undef STATION_KEEL_PORCH
#undef STATION_KEEL_BOOM
#undef STATION_KEEL_BOOM_REACH
#undef STATION_KEEL_ISOTOPE
#undef STATION_KEEL_FUEL
#undef STATION_KEEL_AFT
