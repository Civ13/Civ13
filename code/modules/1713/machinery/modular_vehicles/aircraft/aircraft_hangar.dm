// Player construction of aircraft: an assembly press like the automobile
// workshop, gated on Powered Flight research. It builds the light or cabin plane in
// the clear 4x4 bay northeast of the press with an empty fuel tank.

/obj/structure/car_workshop/hangar
	name = "aircraft hangar"
	desc = "An assembly press and jig for light airframes. Feed steel, glass, cloth, cable and four unattached wheels. It builds an aircraft in the clear square northeast of the press. Finished aircraft need fuel and room for a takeoff roll."
	icon_state = "workbench"

/obj/structure/car_workshop/hangar/models()
	return aircraft_models().Copy()

/obj/structure/car_workshop/hangar/required_nodes()
	return list("powered_flight")

/obj/structure/car_workshop/hangar/model_size(model)
	return (model in models()) ? 4 : 0

/obj/structure/car_workshop/hangar/costs(model)
	if (!(model in models()))
		return null
	if (model == "Cabin plane")
		return list("steel" = 65, "glass" = 8, "cloth" = 8, "cable" = 8, "wheels" = 4)
	return list("steel" = 50, "glass" = 6, "cloth" = 4, "cable" = 8, "wheels" = 4)

/obj/structure/car_workshop/hangar/menu_text()
	return "Stored: [stock["steel"]] steel, [stock["glass"]] glass, [stock["cloth"]] cloth, [stock["cable"]] cable, [stock["wheels"]] wheels. The light plane (2 seats) costs 50/6/4/8/4; the cabin plane (4 seats) costs 65/8/8/8/4 and needs a slightly longer roll. Keep the northeast 4x4 bay empty; the plane needs a long clear roll to take off, shorter on a runway. Taxi a landed plane into the bay to hangar it."

/obj/structure/car_workshop/hangar/assembled_message(model)
	return "Your [model] is assembled. Fill its tank with gasoline, then roll it at full throttle to take off: [model == "Cabin plane" ? "10 tiles on a runway or 20" : "8 tiles on a runway or 16"] on open ground."

// The light plane comes from the aircraft builder, not a car template, and
// leaves the press with an empty tank like every workshop vehicle.
/obj/structure/car_workshop/hangar/complete_assembly(model)
	if (!has_inputs(model) || !clear_footprint(model))
		return null
	var/turf/origin = locate(x + 1, y + 1, z)
	var/obj/structure/vehicleparts/axis/aircraft/A = build_aircraft_model(model, origin)
	if (!A)
		return null
	if (A.engine && A.engine.fueltank)
		var/obj/item/weapon/reagent_containers/glass/barrel/fueltank/old = A.engine.fueltank
		var/obj/item/weapon/reagent_containers/glass/barrel/fueltank/tank/empty = new(old.loc)
		empty.anchored = TRUE
		empty.icon_state = "fueltank_incar"
		A.engine.fueltank = empty
		qdel(old)
	var/list/required = costs(model)
	for (var/key in required)
		stock[key] -= required[key]
	stock["woolcloth"] = min(stock["woolcloth"] || 0, stock["cloth"])
	if (!vehicle_key_service.issue_constructed(A, get_turf(src)))
		return null
	return A
