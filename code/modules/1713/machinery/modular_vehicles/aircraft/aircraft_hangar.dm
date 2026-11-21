// Player construction of aircraft: an assembly press like the automobile
// workshop, gated on Powered Flight research. It builds the light plane or
// trainer, and with Aviation & Rocketry the cabin, cargo or twin-engine plane,
// in the clear bay northeast of the press with an empty fuel tank.

/obj/structure/car_workshop/hangar
	name = "aircraft hangar"
	desc = "An assembly press and jig for light airframes. Feed wood or aluminium for the airframe, steel for the engine, glass, cloth, cable and four unattached wheels. It builds an aircraft in the clear square northeast of the press. Finished aircraft need fuel and room for a takeoff roll."
	icon_state = "workbench"

/obj/structure/car_workshop/hangar/models()
	return aircraft_models().Copy()

/obj/structure/car_workshop/hangar/required_nodes()
	return list("powered_flight")

// Powered Flight builds the wood-and-cloth trainer and light plane; the
// heavier all-metal cabin, cargo and twin-engine planes of the 1920s and
// 1930s need Aviation & Rocketry as well.
/proc/aircraft_model_node(model)
	switch (model)
		if ("Cabin plane", "Cargo plane", "Twin-engine plane", "Airliner")
			return "aviation_rocketry"
		// A turboshaft helicopter (helicopter.dm) is a 1950s machine.
		if ("Helicopter")
			return "rocketry"
	return "powered_flight"

/obj/structure/car_workshop/hangar/model_missing_research(mob/living/human/H, model)
	. = list()
	var/node_id = aircraft_model_node(model)
	if (node_id in required_nodes())
		return
	if (!H || !map || !research_node_known(H, node_id))
		var/datum/research_node/N = get_research_node(node_id)
		. += N ? N.name : node_id

/obj/structure/car_workshop/hangar/model_size(model)
	return aircraft_model_size(model)

// The hangar only has to fit the light planes where it stands; a twin-engine
// plane needs its larger square clear when it is built, and is too big to
// hangar.
/obj/structure/car_workshop/hangar/largest_model_size()
	return model_size("Light plane")

/obj/structure/car_workshop/hangar/costs(model)
	if (!(model in models()))
		return null
	// Early planes are spruce, fabric and wire; all-metal airframes are
	// light alloy (aluminium.dm). The engine is steel in both.
	switch (model)
		if ("Cabin plane")
			return list("aluminium" = 48, "steel" = 16, "glass" = 8, "cloth" = 8, "cable" = 8, "wheels" = 4)
		if ("Trainer")
			return list("wood" = 28, "steel" = 8, "glass" = 4, "cloth" = 6, "cable" = 6, "wheels" = 4)
		if ("Cargo plane")
			return list("aluminium" = 44, "steel" = 16, "glass" = 6, "cloth" = 2, "cable" = 8, "wheels" = 4)
		if ("Twin-engine plane")
			return list("aluminium" = 64, "steel" = 26, "glass" = 8, "cloth" = 6, "cable" = 14, "wheels" = 4)
		if ("Airliner")
			return list("aluminium" = 90, "steel" = 26, "glass" = 14, "cloth" = 12, "cable" = 16, "wheels" = 4)
		// The four "wheels" are its skids.
		if ("Helicopter")
			return list("aluminium" = 80, "steel" = 34, "glass" = 12, "cloth" = 8, "cable" = 20, "wheels" = 4)
	return list("wood" = 40, "steel" = 10, "glass" = 6, "cloth" = 8, "cable" = 8, "wheels" = 4)

/obj/structure/car_workshop/hangar/menu_text()
	return "Stored: [stock["wood"] || 0] wood, [stock["aluminium"] || 0] aluminium, [stock["steel"]] steel, [stock["glass"]] glass, [stock["cloth"]] cloth, [stock["cable"]] cable, [stock["wheels"]] wheels. Costs are airframe/steel/glass/cloth/cable/wheels. Wooden airframes: the light plane (2 seats) costs 40 wood/10/6/8/8/4; the trainer (2 seats, 3x3) costs 28 wood/8/4/6/6/4 and lifts off soonest. Aluminium airframes: the cabin plane (4 seats) costs 48 aluminium/16/8/8/8/4 and needs a slightly longer roll; the cargo plane (pilot and three cargo bays) costs 44 aluminium/16/6/2/8/4; the twin-engine plane (4 seats, two engines) costs 64 aluminium/26/8/6/14/4 and needs the 5x5 square northeast of the press clear; the airliner (pilot and six cabin seats either side of an aisle, two engines) costs 90 aluminium/26/14/12/16/4 and needs a 6x6 square clear; the helicopter (pilot, co-pilot and five cabin seats, a turboshaft engine burning diesel) costs 80 aluminium/34/12/8/20/4, needs Rocketry research and a 7x7 square clear. Use a plane vehicle sheet on the press to build its design; the bay it needs depends on the sheet. Keep the northeast 4x4 bay empty; the plane needs a long clear roll to take off, shorter on a runway. Taxi a landed plane into the bay to hangar it."

/obj/structure/car_workshop/hangar/assembled_message(model)
	if (model == "Helicopter")
		return "Your helicopter is assembled. Fill its tank with diesel and start the engine. Climb spools the rotor up and lifts it straight up; it needs no runway, and Descend close to the ground at low speed sets it down on any dry, fairly level ground."
	var/obj/structure/vehicleparts/axis/aircraft/kind = aircraft_models()[model]
	return "Your [model] is assembled. Fill its tank with gasoline and taxi it like a car. To take off, roll at full throttle along [initial(kind.takeoff_roll)] tiles of runway, or press Climb first and roll [initial(kind.rough_takeoff_roll)] tiles of open ground."

// The light plane comes from the aircraft builder, not a car template, and
// leaves the press with an empty tank like every workshop vehicle.
/obj/structure/car_workshop/hangar/complete_assembly(model)
	if (!has_inputs(model) || !clear_footprint(model))
		return null
	var/turf/origin = locate(x + 1, y + 1, z)
	var/obj/structure/vehicleparts/axis/aircraft/A = build_aircraft_model(model, origin)
	if (!A)
		return null
	// A wooden or aluminium airframe (vehicle_hulls.dm).
	A.set_hull(vehicle_project_hull(costs(model)))
	var/list/engines = A.wing_engines()
	if (A.engine)
		engines += A.engine
	for (var/obj/structure/engine/internal/E in engines)
		if (!E.fueltank)
			continue
		var/obj/item/weapon/reagent_containers/glass/barrel/fueltank/old = E.fueltank
		var/obj/item/weapon/reagent_containers/glass/barrel/fueltank/tank/empty = new(old.loc)
		empty.anchored = TRUE
		empty.icon_state = "fueltank_incar"
		E.fueltank = empty
		qdel(old)
	var/list/required = costs(model)
	for (var/key in required)
		stock[key] -= required[key]
	stock["woolcloth"] = min(stock["woolcloth"] || 0, stock["cloth"])
	if (!vehicle_key_service.issue_constructed(A, get_turf(src)))
		return null
	return A
