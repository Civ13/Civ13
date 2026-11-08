// Player construction of aircraft: an assembly press like the automobile
// workshop, gated on Powered Flight research. It builds the light plane in
// the clear 4x4 bay northeast of the press with an empty fuel tank.

/obj/structure/car_workshop/hangar
	name = "aircraft hangar"
	desc = "An assembly press and jig for light airframes. Feed steel, glass, cloth, cable and four unattached wheels. It builds an aircraft in the clear square northeast of the press. Finished aircraft need fuel and a runway."
	icon_state = "workbench"

/obj/structure/car_workshop/hangar/models()
	return list("Light plane" = /obj/structure/vehicleparts/axis/aircraft/light_plane)

/obj/structure/car_workshop/hangar/allowed(mob/living/human/H)
	return H && map && map.is_node_done(H.civilization, "powered_flight")

/obj/structure/car_workshop/hangar/model_size(model)
	return (model in models()) ? 4 : 0

/obj/structure/car_workshop/hangar/costs(model)
	if (!(model in models()))
		return null
	return list("steel" = 50, "glass" = 6, "cloth" = 4, "cable" = 8, "wheels" = 4)

/obj/structure/car_workshop/hangar/requirement_text()
	return "Powered Flight research is required."

/obj/structure/car_workshop/hangar/menu_text()
	return "Stored: [stock["steel"]] steel, [stock["glass"]] glass, [stock["cloth"]] cloth, [stock["cable"]] cable, [stock["wheels"]] wheels. The light plane costs 50/6/4/8/4. Keep the northeast 4x4 bay empty; the plane needs a runway to take off. Taxi a landed plane into the bay to hangar it."

/obj/structure/car_workshop/hangar/assembled_message(model)
	return "Your [model] is assembled. Fill its tank with gasoline and roll it onto a runway before taking off."

// The light plane comes from the aircraft builder, not a car template, and
// leaves the press with an empty tank like every workshop vehicle.
/obj/structure/car_workshop/hangar/complete_assembly(model)
	if (!has_inputs(model) || !clear_footprint(model))
		return null
	var/turf/origin = locate(x + 1, y + 1, z)
	var/obj/structure/vehicleparts/axis/aircraft/A = build_light_plane(origin)
	if (!A)
		return null
	if (A.engine && A.engine.fueltank)
		var/obj/item/weapon/reagent_containers/glass/barrel/fueltank/old = A.engine.fueltank
		var/obj/item/weapon/reagent_containers/glass/barrel/fueltank/smalltank/empty = new(old.loc)
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
