// ============================================================
// Checks and part book for train sheets (docs/train-sheets.md)
// ------------------------------------------------------------
// Design checks (craft/design_checks.dm) of kind "train_sheet" judge a
// /datum/train_draught the way the rail works (train_works.dm) and the line
// will: an error stops the works building it, a warning is a train that runs
// badly or a car nobody can use, a note is advice. Cells are car numbers from
// the front, as text ("1", "2", ...).
// tests/train_draught wants a part book entry for every key in the tables.
// ============================================================

/datum/design_check/train_sheet
	kind = "train_sheet"
	abstract_type = /datum/design_check/train_sheet

/datum/design_check/train_sheet/check(datum/train_draught/D, datum/design_report/R)
	if (istype(D))
		sheet_check(D, R)

/datum/design_check/train_sheet/proc/sheet_check(datum/train_draught/D, datum/design_report/R)
	return

/proc/train_check_cells(list/indices)
	. = list()
	for (var/i in indices)
		. += "[i]"

/datum/design_check/train_sheet/size
	order = 10

/datum/design_check/train_sheet/size/sheet_check(datum/train_draught/D, datum/design_report/R)
	if (!D.cars.len)
		R.error("The sheet has no cars. Add a locomotive and the cars it should pull.", null, "loco_steam")
		return
	if (D.cars.len > TRAIN_DRAUGHT_MAX_CARS)
		R.error("The train has [D.cars.len] cars; a sheet holds [TRAIN_DRAUGHT_MAX_CARS] at most.")
	var/tiles = D.total_tiles()
	if (tiles > TRAIN_DRAUGHT_MAX_TILES)
		R.error("The train is [tiles] tiles long; a train can be [TRAIN_DRAUGHT_MAX_TILES] at most. Take some cars off.")
	else
		R.note("The rail works needs [tiles] tiles of straight track to build it on.")

/datum/design_check/train_sheet/engines
	order = 20

/datum/design_check/train_sheet/engines/sheet_check(datum/train_draught/D, datum/design_report/R)
	if (!D.cars.len)
		return
	var/list/engines = D.engines()
	if (!engines.len)
		R.warning("The train has no locomotive: it must be hauled by an engine coupled to it, or by a horse or ox harnessed to its front car.", null, "loco_steam")
		return
	if (engines.len > 1)
		R.note("It has [engines.len] engines. Diesels and electrics coupled next to each other work in multiple; steam engines each need their own crew.", train_check_cells(engines))
	var/list/electric = list()
	for (var/i in engines)
		if (D.cars[i] == "loco_electric" || D.cars[i] == "loco_tram")
			electric += i
	if (electric.len)
		R.note("Electric engines run only under a live overhead line.", train_check_cells(electric), "loco_electric")

/datum/design_check/train_sheet/tenders
	order = 30

/datum/design_check/train_sheet/tenders/sheet_check(datum/train_draught/D, datum/design_report/R)
	for (var/i in 1 to D.cars.len)
		var/kind = D.cars[i]
		var/before = i > 1 ? D.cars[i - 1] : null
		var/after = i < D.cars.len ? D.cars[i + 1] : null
		if (kind == "tender" && !train_draught_is_steam(before) && !train_draught_is_steam(after))
			R.warning("The tender in car [i] is not next to a steam engine; couple it right behind one.", list("[i]"), "tender")
		if (kind == "loco_mainline" && after != "tender" && before != "tender")
			R.warning("The main-line steam engine in car [i] carries no coal or water of its own: put a tender right behind it.", list("[i]"), "tender")

/datum/design_check/train_sheet/brakes
	order = 40

/datum/design_check/train_sheet/brakes/sheet_check(datum/train_draught/D, datum/design_report/R)
	if (D.cars.len < 4)
		return
	for (var/kind in D.cars)
		if (kind == "brake_van")
			return
		var/list/C = train_custom_car(kind)
		if (C)
			var/list/counts = train_custom_counts(C)
			var/list/fittings = counts["fittings"]
			if (fittings["H"])
				return
	R.note("A train of [D.cars.len] cars with no brake van or brake wheel stops on the engine's brakes alone. A guard winding a brake wheel at the back stops it far shorter.", null, "brake_van")

// The drawn cars: a way in, an aisle, an ice bunker for the cold lockers.
/datum/design_check/train_sheet/drawn
	order = 50

/datum/design_check/train_sheet/drawn/sheet_check(datum/train_draught/D, datum/design_report/R)
	for (var/i in 1 to D.cars.len)
		var/list/C = train_custom_car(D.cars[i])
		if (!C)
			continue
		var/list/where = list("[i]")
		var/list/counts = train_custom_counts(C)
		var/list/fittings = counts["fittings"]
		var/list/edges = counts["edges"]
		if (!train_custom_has_way_in(C))
			R.warning("The [C["name"]] (car [i]) is walled in all round with no door: nobody can get aboard. Draw a door, leave a side open or leave the middle of an end open.", where, "edge_d")
		var/blocked = 0
		for (var/S in C["sections"])
			if (copytext(S, 4, 5) != ".")
				blocked++
		var/list/sections = C["sections"]
		if (blocked == sections.len)
			R.warning("Every section of the [C["name"]] (car [i]) has something standing on its middle tile: nobody can walk its length.", where)
		if (fittings["L"] && !fittings["I"])
			R.warning("The [C["name"]] (car [i]) has cold lockers but no ice bunker to keep them cold.", where, "fit_I")
		if (fittings["I"] && !(edges["c"] || edges["k"]))
			R.note("The ice in the [C["name"]]'s bunker lasts four times as long with insulated sides on the car.", where, "edge_c")
		if ((fittings["S"] || fittings["B"] || fittings["D"]) && !C["roof"])
			R.note("The [C["name"]] (car [i]) has seats or berths but no roof over them.", where, "roof_c")
		if (fittings["O"] || fittings["K"])
			R.note("A galley stove and sink need fuel and water once the car is built.", where, "fit_O")

/proc/train_custom_has_way_in(list/C)
	var/list/door_keys = list(".", "d", "f", "o", "t", "k", "b")
	if (copytext(C["front"], 2, 3) in door_keys)
		return TRUE
	if (copytext(C["back"], 2, 3) in door_keys)
		return TRUE
	for (var/S in C["sections"])
		if ((copytext(S, 1, 2) in door_keys) || (copytext(S, 2, 3) in door_keys))
			return TRUE
	return FALSE

// ---- What each part is ----

/datum/design_part_book/train_sheet
	kind = "train_sheet"

/datum/design_part_book/train_sheet/entries()
	. = list()
	var/list/stock = train_draught_stock()
	for (var/kind in stock)
		var/list/L = train_car_layout(kind)
		if (!L)
			continue
		var/list/S = stock[kind]
		.[kind] = list(
			"what" = "A [L["name"]], [train_car_length(kind)] tiles long and three wide.",
			"use" = L["desc"],
			"how" = "The rail works builds it for [train_draught_costs_text(S["cost"])], or craft its kit and assemble it on straight track with a hammer.")
	.["custom"] = list(
		"what" = "A car drawn on the sheet: three tiles wide and four (four-wheel) or eight (bogie) long.",
		"use" = "Any car the stock kinds do not cover: lay its floor, put a roof over it, draw a side along each outer edge, an end wall across each end and a fitting on each tile.",
		"how" = "The rail works builds it for its frame (12 iron, or 22 for a bogie car) and what is drawn on it.")
	.["x"] = list("what" = "The eraser.", "use" = "Clears a side, an end or a fitting off a drawn car.", "how" = "Click what to clear.")
	var/list/tables = list("floor_" = train_draught_floors(), "roof_" = train_draught_roofs(), "edge_" = train_draught_edges(), "fit_" = train_draught_fittings())
	for (var/prefix in tables)
		var/list/T = tables[prefix]
		for (var/key in T)
			var/list/row = T[key]
			.["[prefix][key]"] = list("what" = "[capitalize(row["name"])].", "use" = row["use"], "how" = row["how"])
