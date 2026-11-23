// ============================================================
// Train sheets (docs/train-sheets.md)
// ------------------------------------------------------------
// A ship's draught can carry a whole train: its cars in order from the front,
// each one either a stock kind (any car or locomotive a kit builds, by its
// train_car_layout() kind) or a car drawn freely on the sheet. A drawn car is
// three tiles wide and four (four-wheel) or eight (bogie) long: a floor, a
// roof, a wall, window, door or railing along the outer edge of each side
// tile, an end wall across its front and back, and a fitting on each of the
// three tiles of every section.
//
// A drawn car travels as its own car kind string, so a built car keeps it as
// its car_kind and rebuilds from it after a save, in a rail warehouse and in
// a kit, like any stock car (train_car_layout() reads it):
//   c:<length>:<floor>:<roof>:<front>:<back>:<section>,<section>,...:<name>
// where roof is a roof key or ".", front and back are three edge keys (left,
// middle, right) and each section is five keys: the left and right side
// edges, then the fittings on the left, middle (rail) and right tiles. "." is
// none.
//
// A sheet travels as a design code (design_codes.dm):
//   C13TRAIN/1/<name>/<car>;<car>;...
// The checks are design checks of kind "train_sheet" (train_draught_checks.dm).
// The rail works (train_works.dm) builds a sheet on its track and couples it.
// ============================================================

#define TRAIN_DRAUGHT_NAME_MAX 40
#define TRAIN_CAR_NAME_MAX 30

// The stock kinds a sheet may carry: car kind -> its kit and the kit's cost
// (config/crafting/material_recipes_global.txt; tests/train_draught checks).
// Names, lengths and descriptions are the layouts' own.
/proc/train_draught_stock()
	var/static/list/table
	if (!table)
		table = list(
		"loco_steam" = list("kit" = /obj/structure/train_car_kit/loco_steam, "cost" = list("steel" = 45)),
		"loco_mainline" = list("kit" = /obj/structure/train_car_kit/loco_mainline, "cost" = list("steel" = 90)),
		"tender" = list("kit" = /obj/structure/train_car_kit/tender, "cost" = list("iron" = 24)),
		"loco_diesel" = list("kit" = /obj/structure/train_car_kit/loco_diesel, "cost" = list("steel" = 50)),
		"loco_dieselmain" = list("kit" = /obj/structure/train_car_kit/loco_dieselmain, "cost" = list("steel" = 100)),
		"loco_electric" = list("kit" = /obj/structure/train_car_kit/loco_electric, "cost" = list("steel" = 55)),
		"loco_tram" = list("kit" = /obj/structure/train_car_kit/loco_tram, "cost" = list("steel" = 30)),
		"loco_armored" = list("kit" = /obj/structure/train_car_kit/loco_armored, "cost" = list("steel" = 80)),
		"flatbed" = list("kit" = /obj/structure/train_car_kit, "cost" = list("iron" = 12)),
		"coach" = list("kit" = /obj/structure/train_car_kit/coach, "cost" = list("iron" = 16)),
		"sleeper" = list("kit" = /obj/structure/train_car_kit/sleeper, "cost" = list("steel" = 20)),
		"dining" = list("kit" = /obj/structure/train_car_kit/dining, "cost" = list("steel" = 20)),
		"storage" = list("kit" = /obj/structure/train_car_kit/storage, "cost" = list("steel" = 18)),
		"brake_van" = list("kit" = /obj/structure/train_car_kit/brake_van, "cost" = list("iron" = 24)),
		"crane_car" = list("kit" = /obj/structure/train_car_kit/crane_car, "cost" = list("iron" = 40)),
		"long_flatbed" = list("kit" = /obj/structure/train_car_kit/long_flatbed, "cost" = list("iron" = 22)),
		"bogie_coach" = list("kit" = /obj/structure/train_car_kit/bogie_coach, "cost" = list("steel" = 26)),
		"bogie_sleeper" = list("kit" = /obj/structure/train_car_kit/bogie_sleeper, "cost" = list("steel" = 30)),
		"bogie_dining" = list("kit" = /obj/structure/train_car_kit/bogie_dining, "cost" = list("steel" = 30)),
		"mail_van" = list("kit" = /obj/structure/train_car_kit/mail_van, "cost" = list("iron" = 30)),
		"boxcar" = list("kit" = /obj/structure/train_car_kit/boxcar, "cost" = list("iron" = 30)),
		"open_wagon" = list("kit" = /obj/structure/train_car_kit/open_wagon, "cost" = list("iron" = 26)),
		"hopper" = list("kit" = /obj/structure/train_car_kit/hopper, "cost" = list("iron" = 28)),
		"tank_car" = list("kit" = /obj/structure/train_car_kit/tank_car, "cost" = list("iron" = 30)),
		"stock_car" = list("kit" = /obj/structure/train_car_kit/stock_car, "cost" = list("iron" = 30)),
		"ice_car" = list("kit" = /obj/structure/train_car_kit/ice_car, "cost" = list("iron" = 34)),
		"railgun" = list("kit" = /obj/structure/train_car_kit/railgun, "cost" = list("steel" = 60)),
		"armored" = list("kit" = /obj/structure/train_car_kit/armored, "cost" = list("steel" = 40)),
		"flak" = list("kit" = /obj/structure/train_car_kit/flak, "cost" = list("steel" = 45)),
		)
	return table

// A drawn car's frame, wheels and deck: what a platform car kit (four tiles)
// or a bogie flatcar kit (eight) costs.
/proc/train_custom_frame_cost(car_length)
	return car_length == TRAIN_LONG_CAR_LENGTH ? list("iron" = 22) : list("iron" = 12)

// What a drawn car's deck is laid with: the rail tile's and the side tiles'
// deck states (train_platforms.dmi) and the cost per section over the frame.
/proc/train_draught_floors()
	var/static/list/table
	if (!table)
		table = list(
		"w" = list("name" = "plank deck", "center" = "wood", "side" = "wood", "cost" = list(), "use" = "A bare deck of planks, as on a flatcar.", "how" = "Comes with the frame."),
		"b" = list("name" = "worn boards", "center" = "boards", "side" = "boards", "cost" = list(), "use" = "The worn floor of goods stock.", "how" = "Comes with the frame."),
		"f" = list("name" = "boarded floor", "center" = "floor", "side" = "floor", "cost" = list("wood" = 1), "use" = "A smooth floor for a van, a galley or a workshop car.", "how" = "One wood a section over the frame."),
		"c" = list("name" = "carpeted aisle", "center" = "carpet", "side" = "floor", "cost" = list("wood" = 1, "cloth" = 1), "use" = "A carpet down the middle and boards under the seats, as in a coach.", "how" = "One wood and one cloth a section."),
		"a" = list("name" = "carpet throughout", "center" = "carpet", "side" = "carpet", "cost" = list("wood" = 1, "cloth" = 3), "use" = "Carpet wall to wall, for a saloon or a sleeper.", "how" = "One wood and three cloth a section."),
		"s" = list("name" = "steel floor", "center" = "steel", "side" = "steel", "cost" = list("steel" = 2), "use" = "A steel floor that does not burn, for armored and storage cars.", "how" = "Two steel a section."),
		"h" = list("name" = "straw-covered floor", "center" = "straw", "side" = "straw", "cost" = list("wood" = 1), "use" = "Boards under straw, for carrying animals.", "how" = "One wood a section."),
		)
	return table

// Roofs over a drawn car (the roof_<state>_* states).
/proc/train_draught_roofs()
	var/static/list/table
	if (!table)
		table = list(
		"c" = list("name" = "coach roof", "state" = "coach", "cost" = list("wood" = 2), "use" = "A curved carriage roof with a walkway down the middle.", "how" = "Two wood a section."),
		"v" = list("name" = "van roof", "state" = "boxcar", "cost" = list("wood" = 2), "use" = "The flat boarded roof of a goods van.", "how" = "Two wood a section."),
		"k" = list("name" = "stock car roof", "state" = "stock", "cost" = list("wood" = 2), "use" = "A slatted roof that lets air in, for animals.", "how" = "Two wood a section."),
		"r" = list("name" = "insulated roof", "state" = "reefer", "cost" = list("wood" = 3), "use" = "The thick white roof of an ice car.", "how" = "Three wood a section."),
		"s" = list("name" = "steel roof", "state" = "steel", "cost" = list("steel" = 2), "use" = "A riveted steel roof that does not burn.", "how" = "Two steel a section."),
		"a" = list("name" = "armored roof", "state" = "armor", "cost" = list("steel" = 4), "use" = "Plate over the whole car, as on an armored wagon.", "how" = "Four steel a section."),
		)
	return table

// What can stand along a tile's outer edge (edge_<style> states).
/proc/train_draught_edges()
	var/static/list/table
	if (!table)
		table = list(
		"r" = list("name" = "railing", "style" = "rail", "cost" = list("iron" = 1), "use" = "A waist-high rail that stops people falling off; things can be passed over it.", "how" = "One iron."),
		"w" = list("name" = "wall", "style" = "wall", "cost" = list("wood" = 2), "use" = "A panelled carriage wall.", "how" = "Two wood."),
		"n" = list("name" = "window", "style" = "window", "cost" = list("wood" = 1, "glass" = 1), "use" = "A carriage wall with a window to see out of.", "how" = "One wood and one glass."),
		"d" = list("name" = "door", "style" = "door", "cost" = list("wood" = 2), "use" = "A carriage door that opens by hand and can be locked with a train key.", "how" = "Two wood."),
		"p" = list("name" = "boarded side", "style" = "plank", "cost" = list("wood" = 2), "use" = "The tall boarded side of a goods van.", "how" = "Two wood."),
		"f" = list("name" = "sliding freight door", "style" = "freight_door", "cost" = list("wood" = 3), "use" = "A wide sliding door to load crates and barrels through.", "how" = "Three wood."),
		"s" = list("name" = "low side", "style" = "side", "cost" = list("wood" = 1), "use" = "The low plank side of an open wagon.", "how" = "One wood."),
		"o" = list("name" = "drop door", "style" = "drop_door", "cost" = list("wood" = 2), "use" = "A low side that lets down for loading.", "how" = "Two wood."),
		"l" = list("name" = "slatted side", "style" = "slat", "cost" = list("wood" = 1), "use" = "An airy slatted side for carrying animals.", "how" = "One wood."),
		"t" = list("name" = "slatted door", "style" = "slat_door", "cost" = list("wood" = 2), "use" = "A slatted sliding door to lead animals in and out.", "how" = "Two wood."),
		"c" = list("name" = "insulated side", "style" = "cold", "cost" = list("wood" = 3), "use" = "A thick white wall that keeps the cold in. A car with insulated sides makes the ice in its bunker last.", "how" = "Three wood."),
		"k" = list("name" = "insulated door", "style" = "cold_door", "cost" = list("wood" = 3), "use" = "A thick insulated door.", "how" = "Three wood."),
		"a" = list("name" = "armor plate", "style" = "armor", "cost" = list("steel" = 3), "use" = "Steel plate that stops bullets fired from outside while the crew shoots out.", "how" = "Three steel. Needs the research for armored wagons."),
		"b" = list("name" = "armored door", "style" = "armor_door", "cost" = list("steel" = 3), "use" = "A plated door that stops bullets from outside.", "how" = "Three steel. Needs the research for armored wagons."),
		"i" = list("name" = "partition", "style" = "partition", "cost" = list("wood" = 1), "use" = "A light inside wall, for closing off the end of a car.", "how" = "One wood."),
		)
	return table

// What can stand on one of a section's three tiles.
/proc/train_draught_fittings()
	var/static/list/table
	if (!table)
		table = list(
		"S" = list("name" = "seat", "path" = /obj/structure/bed/chair/comfy/blue, "cost" = list("wood" = 2, "cloth" = 4), "use" = "A padded seat facing the way the car does.", "how" = "Two wood and four cloth."),
		"B" = list("name" = "berth", "path" = /obj/structure/bed, "cost" = list("wood" = 4, "cloth" = 2), "use" = "A bed to sleep in on a long run.", "how" = "Four wood and two cloth."),
		"D" = list("name" = "diner booth", "path" = /obj/structure/bed/chair/comfy/diner_booth, "cost" = list("wood" = 4, "cloth" = 2), "use" = "A padded booth seat to eat at.", "how" = "Four wood and two cloth."),
		"T" = list("name" = "table", "path" = /obj/structure/table/modern/table, "cost" = list("wood" = 7), "use" = "A dining table.", "how" = "Seven wood."),
		"W" = list("name" = "wooden table", "path" = /obj/structure/table/wood, "cost" = list("wood" = 4), "use" = "A plain table, as on a mail van's sorting bench.", "how" = "Four wood."),
		"O" = list("name" = "stove", "path" = /obj/structure/oven/stove, "cost" = list("steel" = 8), "use" = "A galley stove to cook on.", "how" = "Eight steel."),
		"K" = list("name" = "sink", "path" = /obj/structure/sink, "cost" = list("glass" = 40), "use" = "A galley sink with water.", "how" = "Forty glass, as a hand-built sink."),
		"F" = list("name" = "fridge", "path" = /obj/structure/closet/fridge, "cost" = list("steel" = 15), "use" = "A fridge that keeps food cold.", "how" = "Fifteen steel. Needs the research for fridges."),
		"C" = list("name" = "cabinet", "path" = /obj/structure/closet/cabinet, "cost" = list("wood" = 5), "use" = "A wooden cabinet to keep things in.", "how" = "Five wood."),
		"X" = list("name" = "large crate", "path" = /obj/structure/closet/crate/large, "cost" = list("steel" = 15), "use" = "A big steel crate for goods.", "how" = "Fifteen steel."),
		"R" = list("name" = "metal crate", "path" = /obj/structure/closet/crate, "cost" = list("steel" = 3), "use" = "A small steel crate.", "how" = "Three steel."),
		"H" = list("name" = "brake wheel", "path" = /obj/structure/train_brake_wheel, "cost" = list("iron" = 6), "use" = "A guard's brake wheel. Wound on, it helps the driver stop the train.", "how" = "Six iron."),
		"I" = list("name" = "ice bunker", "path" = /obj/structure/closet/ice_house/reefer, "cost" = list("wood" = 10), "use" = "Packed with snow or cut ice, it keeps the cold lockers on its car cold.", "how" = "Ten wood."),
		"L" = list("name" = "cold locker", "path" = /obj/structure/closet/ice_house/cold_locker, "cost" = list("wood" = 10), "use" = "An insulated food locker, cold while the ice bunker on its car has ice.", "how" = "Ten wood."),
		)
	return table

// ---- Drawn cars ----

// The parts of a drawn car's kind string, or null when it is not a working
// one: list("length", "floor", "roof", "front", "back", "sections", "name").
/proc/train_custom_car(kind)
	if (!istext(kind) || copytext(kind, 1, 3) != "c:" || length(kind) > 200)
		return null
	var/list/F = splittext(copytext(kind, 3), ":")
	if (F.len != 7)
		return null
	var/car_length = text2num(F[1])
	if (car_length != TRAIN_CAR_LENGTH && car_length != TRAIN_LONG_CAR_LENGTH)
		return null
	if (!train_draught_floors()[F[2]])
		return null
	if (F[3] != "." && !train_draught_roofs()[F[3]])
		return null
	if (!train_custom_edges_ok(F[4], 3) || !train_custom_edges_ok(F[5], 3))
		return null
	var/list/sections = splittext(F[6], ",")
	if (sections.len != car_length)
		return null
	for (var/S in sections)
		if (length(S) != 5 || !train_custom_edges_ok(copytext(S, 1, 3), 2))
			return null
		for (var/i in 3 to 5)
			var/key = copytext(S, i, i + 1)
			if (key != "." && !train_draught_fittings()[key])
				return null
	var/car_name = train_car_clean_name(replacetext(F[7], "_", " "))
	return list("length" = car_length, "floor" = F[2], "roof" = F[3] == "." ? null : F[3], "front" = F[4], "back" = F[5], "sections" = sections, "name" = car_name)

/proc/train_custom_edges_ok(text, count)
	if (length(text) != count)
		return FALSE
	for (var/i in 1 to count)
		var/key = copytext(text, i, i + 1)
		if (key != "." && !train_draught_edges()[key])
			return FALSE
	return TRUE

// A drawn car's kind string from its parts (as train_custom_car() returns).
/proc/train_custom_kind(list/C)
	return "c:[C["length"]]:[C["floor"]]:[C["roof"] ? C["roof"] : "."]:[C["front"]]:[C["back"]]:[jointext(C["sections"], ",")]:[replacetext(train_car_clean_name(C["name"]), " ", "_")]"

/proc/train_car_clean_name(text)
	if (!istext(text))
		return "rail car"
	for (var/bad in list("/", ";", ",", ":", "_"))
		text = replacetext(text, bad, " ")
	text = trim(sanitize(copytext(text, 1, TRAIN_CAR_NAME_MAX + 1)))
	return length(text) ? text : "rail car"

// A drawn car from rows: name, length, floor, roof, front, back and one
// five-key section per row from the front. For the ready-made sheets.
/proc/train_custom_from(car_name, floor, roof, front, back, list/sections)
	return train_custom_kind(list("length" = sections.len, "floor" = floor, "roof" = roof, "front" = front, "back" = back, "sections" = sections, "name" = car_name))

// The layout train_car_layout() gives a drawn car, read once per kind.
/proc/train_custom_layout(kind)
	var/static/list/cache
	if (!cache)
		cache = list()
	if (kind in cache)
		return cache[kind]
	var/list/C = train_custom_car(kind)
	var/list/L = C ? train_custom_build_layout(C) : null
	if (cache.len >= 500)
		cache.Cut()
	cache[kind] = L
	return L

/proc/train_custom_build_layout(list/C)
	var/list/floor = train_draught_floors()[C["floor"]]
	var/list/edge_table = train_draught_edges()
	var/list/fit_table = train_draught_fittings()
	var/list/L = list("name" = C["name"], "center" = floor["center"], "side" = floor["side"], "drawn" = TRUE)
	if (C["roof"])
		L["roof"] = train_draught_roofs()[C["roof"]]["state"]
	var/list/segments = list()
	var/list/sections = C["sections"]
	var/armored = FALSE
	var/insulated = FALSE
	for (var/i in 1 to sections.len)
		var/S = sections[i]
		var/list/edges = list()
		var/list/fit = list(null, null, null)
		for (var/side in 1 to 2)
			var/key = copytext(S, side, side + 1)
			if (key != ".")
				edges += list(list(side == 1 ? TRAIN_LEFT : TRAIN_RIGHT, "out", edge_table[key]["style"]))
		if (i == 1)
			edges += train_custom_end_edges(C["front"], "front")
		if (i == sections.len)
			edges += train_custom_end_edges(C["back"], "back")
		for (var/list/E in edges)
			if (E[3] == "armor" || E[3] == "armor_door")
				armored = TRUE
			if (E[3] == "cold" || E[3] == "cold_door")
				insulated = TRUE
		for (var/slot in 1 to 3)
			var/key = copytext(S, slot + 2, slot + 3)
			if (key != ".")
				fit[slot] = fit_table[key]["path"]
		segments += list(list("edges" = edges, "fit" = fit))
	L["segments"] = segments
	if (armored)
		L["armored"] = TRUE
	if (insulated)
		L["insulated"] = TRUE
	L["desc"] = "A [sections.len == TRAIN_LONG_CAR_LENGTH ? "long car on two bogies" : "four-wheel car"] built to a train sheet, with [floor["name"]][C["roof"] ? " under a [train_draught_roofs()[C["roof"]]["name"]]" : " open to the sky"]."
	return L

/proc/train_custom_end_edges(ends, way)
	. = list()
	var/list/edge_table = train_draught_edges()
	for (var/i in 1 to 3)
		var/key = copytext(ends, i, i + 1)
		if (key != ".")
			. += list(list(i - 2, way, edge_table[key]["style"]))

// What a drawn car costs: its frame, floor, roof, edges and fittings.
/proc/train_custom_costs(list/C)
	. = list()
	var/list/sections = C["sections"]
	ship_draught_add_cost(., train_custom_frame_cost(C["length"]))
	var/list/edge_table = train_draught_edges()
	var/list/fit_table = train_draught_fittings()
	var/list/floor = train_draught_floors()[C["floor"]]
	var/list/roof = C["roof"] ? train_draught_roofs()[C["roof"]] : null
	var/ends = "[C["front"]][C["back"]]"
	for (var/i in 1 to length(ends))
		var/key = copytext(ends, i, i + 1)
		if (key != ".")
			ship_draught_add_cost(., edge_table[key]["cost"])
	for (var/S in sections)
		ship_draught_add_cost(., floor["cost"])
		if (roof)
			ship_draught_add_cost(., roof["cost"])
		for (var/i in 1 to 5)
			var/key = copytext(S, i, i + 1)
			if (key == ".")
				continue
			ship_draught_add_cost(., i <= 2 ? edge_table[key]["cost"] : fit_table[key]["cost"])

// Keys used anywhere on a drawn car: "edges" and "fittings" key -> count.
/proc/train_custom_counts(list/C)
	var/list/edges = list()
	var/list/fittings = list()
	var/ends = "[C["front"]][C["back"]]"
	for (var/i in 1 to length(ends))
		var/key = copytext(ends, i, i + 1)
		if (key != ".")
			edges[key] = (edges[key] || 0) + 1
	for (var/S in C["sections"])
		for (var/i in 1 to 5)
			var/key = copytext(S, i, i + 1)
			if (key == ".")
				continue
			if (i <= 2)
				edges[key] = (edges[key] || 0) + 1
			else
				fittings[key] = (fittings[key] || 0) + 1
	return list("edges" = edges, "fittings" = fittings)

// ---- The sheet ----

/datum/train_draught
	var/name = "train"
	// Car kinds from the front: stock kinds and drawn cars' kind strings.
	var/list/cars = list()
	var/left_off = 0 // one-tile stock a survey could not draw

// TRUE for a kind a sheet may carry.
/proc/train_draught_car_ok(kind)
	if (!istext(kind))
		return FALSE
	if (train_draught_stock()[kind])
		return TRUE
	return !!train_custom_car(kind)

/proc/train_draught_car_name(kind)
	var/list/L = train_car_layout(kind)
	return L ? L["name"] : "rail car"

/proc/train_draught_is_engine(kind)
	var/list/L = train_car_layout(kind)
	return L && L["engine"]

/proc/train_draught_is_steam(kind)
	return kind == "loco_steam" || kind == "loco_mainline" || kind == "loco_armored"

/datum/train_draught/proc/add_car(kind, at = 0)
	if (!train_draught_car_ok(kind) || cars.len >= TRAIN_DRAUGHT_MAX_CARS)
		return FALSE
	if (at >= 1 && at <= cars.len)
		cars.Insert(at, kind)
	else
		cars += kind
	return TRUE

/datum/train_draught/proc/total_tiles()
	. = 0
	for (var/kind in cars)
		. += train_car_length(kind)

/datum/train_draught/proc/engines()
	. = list()
	for (var/i in 1 to cars.len)
		if (train_draught_is_engine(cars[i]))
			. += i

/datum/train_draught/proc/car_costs(kind)
	var/list/S = train_draught_stock()[kind]
	if (S)
		var/list/C = S["cost"]
		return C.Copy()
	var/list/D = train_custom_car(kind)
	return D ? train_custom_costs(D) : list()

/datum/train_draught/proc/costs()
	. = list()
	for (var/kind in cars)
		ship_draught_add_cost(., car_costs(kind))

/proc/train_draught_costs_text(list/C)
	var/list/parts = list()
	for (var/material in C)
		parts += "[C[material]] [material]"
	return parts.len ? english_list(parts) : "nothing"

/datum/train_draught/proc/costs_text()
	return train_draught_costs_text(costs())

// The research nodes a car needs: its kit's, or for a drawn car the railway
// and whatever its fittings and armor need.
/proc/train_draught_car_nodes(kind)
	. = list("rail_steam")
	var/list/S = train_draught_stock()[kind]
	if (S)
		var/node = get_recipe_node_req("[S["kit"]]")
		if (node)
			. |= node
		return
	var/list/C = train_custom_car(kind)
	if (!C)
		return
	var/list/counts = train_custom_counts(C)
	var/list/edges = counts["edges"]
	if (edges["a"] || edges["b"])
		var/armor_node = get_recipe_node_req("[/obj/structure/train_car_kit/armored]")
		if (armor_node)
			. |= armor_node
	var/list/fittings = counts["fittings"]
	for (var/key in fittings)
		var/node = get_recipe_node_req("[train_draught_fittings()[key]["path"]]")
		if (node)
			. |= node

/datum/train_draught/proc/nodes()
	. = list()
	for (var/kind in cars)
		. |= train_draught_car_nodes(kind)

/datum/train_draught/proc/problems()
	return design_errors("train_sheet", src)

/datum/train_draught/proc/check_design()
	return design_report("train_sheet", src)

/datum/train_draught/proc/summary_text()
	var/list/lines = list()
	var/list/names = list()
	for (var/kind in cars)
		names += train_draught_car_name(kind)
	lines += "<b>[name]</b>: a train of [cars.len] car\s, [total_tiles()] tiles long[names.len ? ": [jointext(names, ", ")], from the front" : ""]."
	lines += "Building it takes [costs_text()]."
	var/datum/design_report/R = check_design()
	lines += R.blocked() ? "<span class='warning'>Not ready to build:</span>" : "As drawn it can be built at a rail works."
	lines += R.chat_lines()
	qdel(R)
	return jointext(lines, "<br>")

// ---- Design codes ----

/datum/train_draught/proc/to_code()
	return "C13TRAIN/1/[ship_draught_code_name(train_draught_clean_name(name))]/[jointext(cars, ";")]"

/proc/train_draught_from_code(code)
	var/list/F = design_code_fields(code, "TRAIN", DESIGN_CODE_TRAIN_MAX)
	if (!F || F.len != 2)
		return null
	var/datum/train_draught/D = new
	D.name = train_draught_clean_name(replacetext(F[1], "_", " "))
	var/list/kinds = length(F[2]) ? splittext(F[2], ";") : list()
	if (kinds.len > TRAIN_DRAUGHT_MAX_CARS)
		qdel(D)
		return null
	for (var/kind in kinds)
		if (!D.add_car(kind))
			qdel(D)
			return null
	return D

/proc/train_draught_clean_name(text)
	if (!istext(text))
		return "train"
	text = replacetext(replacetext(replacetext(text, "/", " "), ";", " "), ",", " ")
	text = replacetext(text, ":", " ")
	text = trim(sanitize(copytext(text, 1, TRAIN_DRAUGHT_NAME_MAX + 1)))
	return length(text) ? text : "train"

// ---- Ready-made sheets ----

/proc/train_draught_example(new_name, list/kinds)
	var/datum/train_draught/D = new
	D.name = new_name
	for (var/kind in kinds)
		D.add_car(kind)
	return D

// Each one can be built as drawn (the probe checks).
/proc/train_draught_examples()
	. = list()
	// A branch passenger train with a drawn saloon behind its coach.
	. += train_draught_example("branch passenger train", list(
		"loco_steam",
		"coach",
		train_custom_from("private saloon", "a", "c", "wdw", "wdw", list(
			"nn.T.",
			"nnS.S",
			"nnD.D",
			"ddC.C")),
		"brake_van"))
	// A main-line goods train with a drawn tool van.
	. += train_draught_example("goods train", list(
		"loco_mainline",
		"tender",
		"boxcar",
		"open_wagon",
		train_custom_from("tool van", "b", "v", "ppp", "pdp", list(
			"ppC.C",
			"ffX.X",
			"ffR.R",
			"ppHWS")),
		"brake_van"))
	// A diesel express with a drawn observation car at the back.
	. += train_draught_example("diesel express", list(
		"loco_dieselmain",
		"bogie_coach",
		"bogie_dining",
		train_custom_from("observation car", "c", "c", "ndn", "nnn", list(
			"dd...",
			"nnS.S",
			"nnS.S",
			"nnS.S",
			"nnS.S",
			"nnT.T",
			"nnS.S",
			"nnS.S"))))

// ---- On the ship's draught ----

/obj/item/ship_draught/proc/train_draught()
	return draught_code ? train_draught_from_code(draught_code) : null

/obj/item/ship_draught/proc/train_draught_kind()
	return draught_code && design_code_kind(draught_code) == "TRAIN"

/obj/item/ship_draught/proc/take_train(datum/train_draught/D)
	draught_code = D ? D.to_code() : ""
	name = D ? "train sheet ([D.name])" : initial(name)

/obj/item/ship_draught/proc/train_sheet_menu(mob/living/human/H, datum/train_draught/D)
	var/choice = WWinput(H, D.summary_text(), name, "Cancel", list("Draw on the sheet", "Copy its design code", "Paste a design code", "Cancel"))
	if (choice == "Draw on the sheet")
		open_train_designer(H)
	else if (choice == "Copy its design code")
		design_code_show(H, "Train sheet: [D.name]", draught_code, "Paste it into any ship's draught to draw the same train.")
	else if (choice == "Paste a design code")
		paste_any_code(H)

// ---- Drawing a train ----

// The sheet of the train headed by head, front first, or the reason it
// cannot be drawn. One-tile wagons and engines are left off.
/proc/train_draught_survey(obj/structure/trains/head)
	if (!head)
		return "There is no train to draw."
	var/datum/train_draught/D = new
	var/list/seen_ids = list()
	var/left_off = 0
	for (var/obj/structure/trains/car in train_consist_list(head))
		var/kind = null
		if (istype(car, /obj/structure/trains/platform))
			var/obj/structure/trains/platform/P = car
			kind = P.car_kind
		else if (istype(car, /obj/structure/trains/locomotive))
			var/obj/structure/trains/locomotive/L = car
			kind = L.body_kind ? "loco_[L.body_kind]" : null
		if (car.car_id && (car.car_id in seen_ids))
			continue
		if (car.car_id)
			seen_ids += car.car_id
		if (!kind || !train_draught_car_ok(kind))
			left_off++
			continue
		if (!D.add_car(kind))
			qdel(D)
			return "The train has more than [TRAIN_DRAUGHT_MAX_CARS] cars; a sheet holds that many."
	if (!D.cars.len)
		qdel(D)
		return "Only platform cars and heavy locomotives can be drawn on a train sheet."
	D.name = train_draught_clean_name(train_draught_car_name(D.cars[1]) == "rail car" ? "train" : "[train_draught_car_name(D.cars[1])] train")
	D.left_off = left_off
	return D

#undef TRAIN_DRAUGHT_NAME_MAX
#undef TRAIN_CAR_NAME_MAX
