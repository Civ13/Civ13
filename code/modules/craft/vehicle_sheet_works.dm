// ============================================================
// Building a vehicle sheet in a workshop (docs/vehicle-sheets.md)
// ------------------------------------------------------------
// A vehicle sheet can be built by hand around a clipped axis
// (vehicle_draught.dm), or handed to a press: use the sheet on the
// automobile workshop for a car, truck or tank drawn on a light or heavy
// axis, or on the aircraft hangar for a plane. The press reads the sheet's
// design checks and builds nothing from a sheet that fails them. It then
// makes every frame, wheel, track, engine, tank, seat, turret and hold the
// sheet draws from its stock and assembles them the way a hand builder
// would (vehicle_assembly.dm), front to the north, in the clear square
// northeast of the press. The vehicle leaves with empty tanks and a key,
// like every workshop vehicle, and can be taken apart like a hand-built one.
//
// What it costs is what the sheet's parts cost (vehicle_draught.dm costs()),
// with the corner wheels taken from the press's wheel stock in place of
// their steel, and 10 cable for the wiring. Only the corner movers are made:
// a vehicle fits no others.
// ============================================================

#define VEHICLE_SHEET_WORK_CABLE 10
// Steel a sheet press holds: a 5x5 tank with a big diesel and two turrets.
#define VEHICLE_SHEET_STOCK_STEEL 1000

// The axes of the sheets this press builds; none for presses with their own
// fixed models.
/obj/structure/car_workshop/proc/sheet_axes()
	return list("car", "heavy")

/obj/structure/car_workshop/hangar/sheet_axes()
	return list("plane")

/obj/structure/car_workshop/shipyard/sheet_axes()
	return list()

/obj/structure/car_workshop/submarine_pen/sheet_axes()
	return list()

/obj/structure/car_workshop/rover_bay/sheet_axes()
	return list()

/obj/structure/car_workshop/extraction_private/sheet_axes()
	return list()

// The most of key a sheet press holds, so a big sheet can be paid for.
/obj/structure/car_workshop/proc/sheet_stock_cap(key)
	if (!length(sheet_axes()))
		return 0
	return key == "steel" ? VEHICLE_SHEET_STOCK_STEEL : 0

// TRUE when I is a vehicle sheet this press should answer.
/obj/structure/car_workshop/proc/sheet_offered(obj/item/I)
	var/obj/item/ship_draught/S = I
	return istype(S) && S.vehicle_draught_kind() && length(sheet_axes())

// What the press takes from its stock to build D.
/obj/structure/car_workshop/proc/sheet_costs(datum/vehicle_draught/D)
	. = D.costs()
	var/wheels = 0
	var/skipped_steel = 0
	for (var/key in D.cells)
		var/list/C = D.cells[key]
		if (!C[1] || !C[2])
			continue
		var/list/at = splittext(key, ",")
		var/list/M = vehicle_draught_movers[C[2]]
		var/list/M_cost = M ? M["cost"] : null
		var/steel = M_cost ? (M_cost["steel"] || 0) : 0
		if (!D.is_corner(text2num(at[1]), text2num(at[2])))
			skipped_steel += steel
		else if (C[2] == "W")
			wheels++
			skipped_steel += steel
	if (skipped_steel)
		.["steel"] = max(0, (.["steel"] || 0) - skipped_steel)
		if (!.["steel"])
			. -= "steel"
	if (wheels)
		.["wheels"] = wheels
	.["cable"] = (.["cable"] || 0) + VEHICLE_SHEET_WORK_CABLE

/proc/vehicle_sheet_costs_text(list/costs)
	var/list/parts = list()
	for (var/key in costs)
		parts += "[costs[key]] [key]"
	return english_list(parts)

// Research a sheet needs beyond the press's own: a turret or tracks are
// armoured vehicles, as the works vehicles' tanks and carriers; a twin's
// wings are the later all-metal planes.
/proc/vehicle_sheet_nodes(datum/vehicle_draught/D)
	. = list()
	if (!D)
		return
	if (D.count_parts("U") || length(D.part_cells("K")))
		. += "mechanized_war"
	if (D.plane() && D.width == 5)
		. += aircraft_model_node("Twin-engine plane")

/obj/structure/car_workshop/proc/sheet_missing_research(mob/living/human/H, datum/vehicle_draught/D)
	. = list()
	for (var/node_id in vehicle_sheet_nodes(D))
		if (node_id in required_nodes())
			continue
		if (!H || !map || !research_node_known(H, node_id))
			var/datum/research_node/N = get_research_node(node_id)
			. += N ? N.name : node_id

// The side of the square bay a sheet needs: its turning square.
/proc/vehicle_sheet_bay_size(datum/vehicle_draught/D)
	return D ? max(D.width, D.length) : 0

// TRUE when the size x size square northeast of the press is dry, open floor
// with nothing physical standing in it.
/obj/structure/car_workshop/proc/bay_clear(size)
	if (!size || !isturf(loc))
		return FALSE
	for (var/dx = 1, dx <= size, dx++)
		for (var/dy = 1, dy <= size, dy++)
			var/turf/T = locate(x + dx, y + dy, z)
			if (!bay_floor(T))
				return FALSE
			for (var/atom/movable/M in T)
				if (M.simulated)
					return FALSE
	return TRUE

// Why this press will not build D for H now, or null.
/obj/structure/car_workshop/proc/sheet_refusal(mob/living/human/H, datum/vehicle_draught/D)
	if (!D)
		return "The sheet cannot be read."
	if (!(D.axis in sheet_axes()))
		return "The [D.name] is [D.plane() ? "a plane" : "a land vehicle"]; \the [src] does not build those. Take it to an [D.plane() ? "aircraft hangar" : "automobile workshop"]."
	var/list/errors = D.problems()
	if (errors.len)
		var/list/first = list()
		for (var/i = 1, i <= min(errors.len, 3), i++)
			var/t = errors[i]
			if (copytext(t, -1) == ".")
				t = copytext(t, 1, -1)
			first += t
		return "The sheet's checks fail, so the press will not build it: [jointext(first, "; ")][errors.len > 3 ? "; and [errors.len - 3] more" : ""]. Fix the drawing first."
	var/list/research = sheet_missing_research(H, D)
	if (research.len)
		return "[english_list(research)] research [research.len == 1 ? "is" : "are"] required to build the [D.name]."
	if (project)
		return "A [project] is being built piece by piece in the bay. Finish or clear it first."
	var/size = vehicle_sheet_bay_size(D)
	if (!bay_clear(size))
		return "The [D.name] needs the [size]x[size] square northeast of the press clear: dry, open floor with nothing in it."
	var/list/costs = sheet_costs(D)
	var/list/short = list()
	for (var/key in costs)
		if ((stock[key] || 0) < costs[key])
			short += "[costs[key] - (stock[key] || 0)] more [key]"
	if (short.len)
		return "The [D.name] costs [vehicle_sheet_costs_text(costs)]. The press needs [english_list(short)]."
	return null

// Using a vehicle sheet on the press: read it, say what it costs and build.
/obj/structure/car_workshop/proc/build_from_sheet(mob/living/human/H, obj/item/ship_draught/S)
	var/datum/vehicle_draught/D = S.vehicle_draught()
	var/refusal = sheet_refusal(H, D)
	if (refusal)
		to_chat(H, SPAN_WARNING(refusal))
		qdel(D)
		return null
	var/size = vehicle_sheet_bay_size(D)
	var/choice = WWinput(H, "Build the [D.name], [D.width] by [D.length] tiles with its [D.cc]cc [D.engine_name()], for [vehicle_sheet_costs_text(sheet_costs(D))]? It will be built facing north in the clear [size]x[size] square northeast of the press, and leaves with empty tanks.", name, "Cancel", list("Build it", "Cancel"))
	if (choice != "Build it" || busy || !Adjacent(H) || !allowed(H) || S.loc != H)
		qdel(D)
		return null
	refusal = sheet_refusal(H, D)
	if (refusal)
		to_chat(H, SPAN_WARNING(refusal))
		qdel(D)
		return null
	busy = TRUE
	powerneeded = 20
	if (!draw_cable_power())
		finish_work()
		to_chat(H, SPAN_WARNING("Connect an active cable supply with 20 available power."))
		qdel(D)
		return null
	var/completed = wait_for_assembly(H)
	if (QDELETED(src))
		qdel(D)
		return null
	var/obj/structure/vehicleparts/axis/A = null
	if (completed && Adjacent(H) && allowed(H) && draw_cable_power())
		refusal = sheet_refusal(H, D)
		if (refusal)
			to_chat(H, SPAN_WARNING(refusal))
		else
			var/result = build_sheet_vehicle(D)
			if (istext(result))
				to_chat(H, SPAN_WARNING("The press could not assemble the [D.name]: [result]."))
			else
				A = result
				to_chat(H, SPAN_NOTICE("The [D.name] is assembled in the bay. Fill its tank[length(D.tank_cells()) == 1 ? "" : "s"] with [english_list(vehicle_draught_engines[D.engine]["fuels"], and_text = " or ")] before [D.plane() ? "you fly it. Taxi it like a car; take off at full throttle along a runway, or press Climb first on open ground" : "you drive it"]."))
	finish_work()
	qdel(D)
	return A

// Makes D's parts in the bay and assembles them front to the north: the
// axis, or why it could not be done. Spends the stock only on success.
/obj/structure/car_workshop/proc/build_sheet_vehicle(datum/vehicle_draught/D)
	var/size = vehicle_sheet_bay_size(D)
	if (!bay_clear(size))
		return "the bay is not clear"
	var/list/made = list()
	var/list/A_spec = vehicle_draught_axes[D.axis]
	var/axis_path = A_spec["path"]
	var/obj/structure/vehicleparts/axis/A = null
	// Front row at the north edge of the bay, the left column at its west.
	for (var/row = 1, row <= D.length, row++)
		for (var/col = 1, col <= D.width, col++)
			var/list/C = D.cell(col, row)
			if (!C || !C[1])
				continue
			var/turf/T = locate(x + col, y + size - row + 1, z)
			if (!T)
				for (var/obj/O in made)
					qdel(O)
				return "the bay runs off the map"
			var/list/F = vehicle_draught_frames[C[1]]
			var/frame_path = F["path"]
			made += new frame_path(T)
			if (!A)
				A = new axis_path(T)
				made += A
			if (C[2] && D.is_corner(col, row))
				var/list/M = vehicle_draught_movers[C[2]]
				var/mover_path = M["path"]
				made += new mover_path(T)
			if (C[3])
				made += make_sheet_part(D, C[3], T)
	if (!A)
		return "the sheet has no frames"
	A.name = D.name
	A.new_number()
	for (var/obj/O in made)
		O.dir = NORTH
	var/result = A.assemble(NORTH)
	if (result)
		for (var/obj/O in made)
			if (!QDELETED(O))
				qdel(O)
		return result
	var/list/costs = sheet_costs(D)
	for (var/key in costs)
		stock[key] -= costs[key]
	stock["woolcloth"] = min(stock["woolcloth"] || 0, stock["cloth"])
	vehicle_key_service.issue_constructed(A, get_turf(src))
	return A

// The objects for part key on T, made as their makers make them.
/obj/structure/car_workshop/proc/make_sheet_part(datum/vehicle_draught/D, part, turf/T)
	. = list()
	var/path = D.part_path(part)
	if (!path)
		return
	var/atom/movable/P = new path(T)
	. += P
	if (part == "E")
		var/obj/structure/engine/internal/E = P
		if (istype(E))
			E.enginesize = D.cc
			E.maxpower = initial(E.maxpower) * D.cc / 1000
			E.fuelefficiency = initial(E.fuelefficiency) * D.cc / 1000
			E.weight = 20 * D.cc / 1000
			E.name = "[D.cc]cc [initial(E.name)]"
	var/obj/item/weapon/reagent_containers/glass/barrel/fueltank/tank = P
	if (istype(tank) && tank.reagents)
		tank.reagents.clear_reagents()
	var/list/spec = vehicle_draught_parts[part]
	if (spec && spec["with"])
		for (var/with in spec["with"])
			. += new with(T)

#undef VEHICLE_SHEET_WORK_CABLE
#undef VEHICLE_SHEET_STOCK_STEEL
