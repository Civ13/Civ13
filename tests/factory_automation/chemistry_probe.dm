// Chemistry automation phase 0: barrel ports on the oil well, refineries and
// internal combustion engines, the barrel station and the reagent gate. Runs
// the production sources through the shared resource-extraction fixture with
// ordinary game startup disabled; ports are called directly.
/world
	hub = ""
	hub_password = ""
	maxx = 16
	maxy = 16
	maxz = 1
	turf = /turf
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/obj/map_metadata/chem_probe/New()
	return
var/chem_failures = 0
var/chem_runtime_error = FALSE
/proc/chem_check(condition, label)
	if (!condition)
		chem_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	chem_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/proc/chem_floor(x, y)
	var/turf/T = locate(x, y, 1)
	return T.ChangeTurf(/turf/floor/dirt, FALSE, FALSE)
/proc/chem_barrel(x, y, id = null, amount = 0)
	var/obj/item/weapon/reagent_containers/glass/barrel/B = new(locate(x, y, 1))
	if (id && amount)
		B.reagents.add_reagent(id, amount)
	return B
/proc/chem_power(obj/O, x, y)
	var/obj/structure/cable/C = new(locate(x, y, 1))
	var/obj/structure/engine/E = new(locate(x, y, 1))
	E.on = TRUE
	E.maxpower = 50
	E.connections = list(C)
	C.connections = list(O, E)
	O.powersource = C
	C.rebuild_supply()
	return list(C, E)
/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		movementMachine = new
		populate_material_list()
		build_research_tree()
		map = new /obj/map_metadata/chem_probe
		map.ordinal_age = 8
		for (var/x in 1 to 16)
			for (var/y in 1 to 16)
				chem_floor(x, y)
		chem_check(!world.port, "fixture has no listening port")
		chem_oilwell_checks()
		chem_refinery_checks()
		chem_biofuel_checks()
		chem_engine_checks()
		chem_station_checks()
		chem_gate_checks()
		chem_arm_checks()
		chem_catalog_checks()
	catch(var/exception/e)
		chem_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = chem_failures, "runtime_error" = chem_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/chem_oilwell_checks()
	var/obj/structure/oilwell/dry = new(locate(1, 1, 1))
	var/obj/item/weapon/reagent_containers/glass/barrel/B = chem_barrel(2, 1)
	chem_check(!dry.factory_accepts(B), "an oil well off a spring has no port")
	qdel(dry)
	new /obj/structure/oil_spring(locate(4, 1, 1))
	var/obj/structure/oilwell/W = new(locate(4, 1, 1))
	var/obj/item/weapon/reagent_containers/glass/barrel/full = chem_barrel(3, 2, "water", 250)
	chem_check(!W.factory_accepts(full), "a full barrel is refused")
	chem_check(W.factory_insert(B) == 1 && W.work_barrel == B && B.loc == W && W.extracting_now, "an empty barrel from automation becomes the well's barrel and extraction starts")
	var/obj/item/weapon/reagent_containers/glass/barrel/second = chem_barrel(3, 1)
	chem_check(!W.factory_accepts(second), "a well with a barrel refuses another")
	chem_check(!W.factory_offer(), "a filling barrel is not offered")
	B.reagents.add_reagent("petroleum", 250)
	chem_check(W.factory_offer() == B, "a full barrel is offered")
	chem_check(!W.factory_offer(0, /obj/item/stack), "an arm filter that does not match is honoured")
	chem_check(W.factory_take(B, locate(5, 1, 1)) && B.loc == locate(5, 1, 1) && !W.work_barrel && !W.extracting_now, "taking the full barrel stops extraction and frees the well")
	chem_check(W.factory_accepts(second), "the freed well takes the next barrel")
	for (var/obj/O in list(B, second, full, W))
		qdel(O)

/proc/chem_refinery_checks()
	var/obj/structure/refinery/R = new(locate(2, 4, 1))
	var/obj/item/weapon/reagent_containers/glass/barrel/water = chem_barrel(1, 4, "water", 50)
	var/obj/item/weapon/reagent_containers/glass/barrel/first = chem_barrel(1, 5, "petroleum", 100)
	chem_check(R.factory_insert(first) == 1 && R.volume == 100 && first.loc == R && R.factory_output_barrel() == first, "a petroleum barrel is drained and, emptied, becomes the output barrel")
	chem_check(!R.factory_accepts(water), "a barrel without feedstock is refused once there is an output barrel")
	var/obj/item/weapon/reagent_containers/glass/barrel/second = chem_barrel(1, 6, "petroleum", 250)
	chem_check(R.factory_insert(second) == 1 && R.volume == 300 && second.loc == R.loc && second.reagents.get_reagent_amount("petroleum") == 50, "feed fills the refinery to its limit and the barrel waits on its tile with the rest")
	var/obj/item/weapon/reagent_containers/glass/barrel/third = chem_barrel(1, 7, "petroleum", 10)
	R.volume = 100
	chem_check(!R.factory_accepts(third), "no more feed is taken while a drained barrel waits")
	chem_check(R.factory_offer() == second && R.factory_take(second, locate(3, 4, 1)), "the waiting barrel is offered and taken")
	chem_check(R.factory_accepts(third), "feed is taken again once the tile is clear")
	chem_check(!R.active && !R.refine_scheduled, "a refinery without power does not start")
	var/list/power = chem_power(R, 2, 5)
	chem_check(R.factory_insert(third) == 1 && R.active && R.refine_scheduled, "feed with an output barrel and power starts the refinery")
	var/obj/structure/cable/C = power[1]
	chem_check(C.power_consumers[R] == R.powerneeded, "the refinery reserves its power")
	chem_check(!R.factory_try_start(), "a running refinery is not started twice")
	R.factory_take(third, locate(3, 5, 1))
	chem_check(R.factory_offer() == null, "an output barrel with room is not offered")
	first.reagents.add_reagent("gasoline", 250)
	chem_check(R.factory_offer() == first && R.factory_take(first, locate(3, 6, 1)) && !R.active && !length(R.barrel) && !(R in C.power_consumers), "a full output barrel is offered, and taking it stops the refinery and releases power")
	var/obj/item/weapon/reagent_containers/glass/barrel/empty = chem_barrel(1, 8)
	chem_check(R.factory_insert(empty) == 1 && R.factory_output_barrel() == empty && empty.loc == R, "an empty barrel becomes the new output barrel")
	chem_check(R.persistence_runtime_var("barrel") && R.persistence_runtime_var("refine_scheduled") && !R.persistence_runtime_var("volume"), "the barrel list and refine loop are runtime-only and feed is saved")
	R.barrel = list()
	R.active = TRUE
	R.after_load()
	chem_check(R.factory_output_barrel() == empty && !R.active && !R.refine_scheduled, "load restores the held output barrel and leaves the refinery stopped")
	var/turf/T = R.loc
	qdel(R)
	chem_check(empty.loc == T, "removing the refinery releases its barrel")
	for (var/obj/O in list(water, first, second, third, empty) + power)
		qdel(O)

/proc/chem_biofuel_checks()
	var/obj/structure/refinery/biofuel/R = new(locate(6, 4, 1))
	var/obj/item/weapon/reagent_containers/glass/barrel/oil = chem_barrel(5, 4, "olive_oil", 40)
	var/obj/item/weapon/reagent_containers/glass/barrel/ethanol = chem_barrel(5, 5, "ethanol", 50)
	chem_check(R.factory_insert(oil) == 1 && R.volume_di == 40 && R.factory_output_barrel() == oil, "olive oil feeds the biodiesel counter")
	for (var/datum/reagent/ethanol/E in ethanol.reagents.reagent_list)
		E.strength = 40 // a 40-strength mash counts at 60%, as by hand
	var/ins = R.factory_insert(ethanol)
	chem_check(ins == 1 && abs(R.volume_et - 30) < 0.01 && !ethanol.reagents.total_volume && ethanol.loc == R.loc, "ethanol feeds the ethanol counter at its purity")
	R.factory_take(ethanol, locate(7, 4, 1))
	var/obj/item/weapon/reagent_containers/glass/barrel/water = chem_barrel(5, 6, "water", 10)
	chem_check(!R.factory_accepts(water), "a biofuel refinery refuses barrels without precursors")
	for (var/obj/O in list(R, oil, ethanol, water))
		qdel(O)

/proc/chem_engine_checks()
	var/obj/structure/engine/internal/gasoline/E = new(locate(2, 9, 1))
	var/obj/item/weapon/reagent_containers/glass/barrel/fuel = chem_barrel(1, 9, "gasoline", 200)
	chem_check(!E.factory_accepts(fuel), "an engine without a fuel tank has no port")
	var/obj/item/weapon/reagent_containers/glass/barrel/fueltank/tank = new(E.loc)
	tank.reagents.add_reagent("gasoline", 100)
	E.fueltank = tank
	tank.anchored = TRUE
	chem_check(!E.factory_accepts(fuel), "an unsecured engine has no port")
	E.anchored = TRUE
	var/obj/item/weapon/reagent_containers/glass/barrel/water = chem_barrel(1, 10, "water", 50)
	chem_check(!E.factory_accepts(water), "a barrel without a fuel the engine burns is refused")
	chem_check(E.factory_insert(fuel) == 1 && tank.reagents.get_reagent_amount("gasoline") == 250 && fuel.reagents.get_reagent_amount("gasoline") == 50 && fuel.loc == E.loc, "a fuel barrel tops up the tank and waits on the engine's tile")
	chem_check(E.factory_offer() == fuel, "the engine offers the waiting barrel, never its own tank")
	tank.reagents.remove_reagent("gasoline", 100)
	var/obj/item/weapon/reagent_containers/glass/barrel/more = chem_barrel(1, 11, "gasoline", 10)
	chem_check(!E.factory_accepts(more), "no more fuel is taken while a barrel waits")
	chem_check(E.factory_take(fuel, locate(3, 9, 1)) && !E.factory_offer() && !E.factory_take(tank, locate(3, 10, 1)), "the waiting barrel is taken and the tank stays connected")
	chem_check(E.factory_insert(more) == 1 && tank.reagents.get_reagent_amount("gasoline") == 160, "the next fuel barrel tops up the tank")
	for (var/obj/O in list(E, tank, fuel, water, more))
		qdel(O)

/proc/chem_station_checks()
	var/obj/structure/reagent_dispensers/largebarrel/factory_station/S = new(locate(10, 2, 1))
	var/obj/item/weapon/reagent_containers/glass/barrel/water = chem_barrel(9, 2, "water", 100)
	chem_check(S.flags & NOREACT, "the station's tank is held inert")
	chem_check(!S.factory_accepts(water), "an unsecured station has no port")
	S.anchored = TRUE
	chem_check(S.factory_insert(water) == 1 && S.reagents.get_reagent_amount("water") == 100 && !water.reagents.total_volume && water.loc == S, "drain mode empties a barrel into the tank and holds it")
	var/obj/item/weapon/reagent_containers/glass/barrel/other = chem_barrel(9, 3, "potassium", 50)
	chem_check(!S.factory_accepts(other), "one barrel at a time")
	chem_check(S.factory_offer() == water && S.factory_take(water, locate(11, 2, 1)), "the held barrel is offered and taken")
	chem_check(S.factory_insert(other) == 1 && S.reagents.get_reagent_amount("potassium") == 50 && S.reagents.get_reagent_amount("water") == 100, "different deliveries share the inert tank")
	S.factory_take(other, locate(11, 3, 1))
	S.reagents.del_reagent("potassium")
	var/obj/item/weapon/reagent_containers/glass/barrel/empty = chem_barrel(9, 4)
	chem_check(!S.factory_accepts(empty), "drain mode refuses empty barrels")
	S.station_fill = TRUE
	chem_check(S.factory_insert(empty) == 1 && empty.reagents.get_reagent_amount("water") == 100 && !S.reagents.total_volume, "fill mode fills an empty barrel from the tank")
	chem_check(!S.factory_accepts(water), "fill mode refuses barrels when the tank is empty")
	S.locked = TRUE
	chem_check(!S.factory_offer(), "a locked station offers nothing")
	S.locked = FALSE
	var/turf/T = S.loc
	qdel(S)
	chem_check(empty.loc == T, "removing the station releases its barrel")
	for (var/obj/O in list(water, other, empty))
		qdel(O)

/proc/chem_gate_checks()
	var/obj/structure/factory_belt/routing/gate/reagent/G = new(locate(10, 8, 1))
	G.set_dir(EAST)
	var/obj/item/weapon/reagent_containers/glass/barrel/gas = chem_barrel(9, 8, "gasoline", 50)
	var/obj/item/weapon/reagent_containers/glass/barrel/water = chem_barrel(9, 9, "water", 50)
	var/obj/item/weapon/reagent_containers/glass/barrel/empty = chem_barrel(9, 10)
	var/obj/item/stack/material/stone/stone = new(locate(9, 11, 1), 5, FALSE)
	var/side = G.side_dir()
	chem_check(G.export_dirs(gas)[1] == EAST, "without a filter everything goes straight on")
	G.filter_reagent = "gasoline"
	chem_check(G.export_dirs(gas)[1] == side && G.export_dirs(water)[1] == EAST && G.export_dirs(stone)[1] == EAST, "a reagent filter sends matching containers to the side")
	G.filter_reagent = "empty"
	chem_check(G.export_dirs(empty)[1] == side && G.export_dirs(gas)[1] == EAST, "the empty filter sends empty containers to the side")
	chem_check("filter_reagent" in G.get_saved_vars(), "the reagent filter is saved")
	for (var/obj/O in list(G, gas, water, empty, stone))
		qdel(O)

// A powered feeder arm moves a drained barrel from a station into a refinery.
/proc/chem_arm_checks()
	var/obj/structure/reagent_dispensers/largebarrel/factory_station/S = new(locate(12, 12, 1))
	S.anchored = TRUE
	var/obj/item/weapon/reagent_containers/glass/barrel/B = chem_barrel(11, 12, "water", 30)
	S.factory_insert(B)
	var/obj/structure/factory_arm/arm = new(locate(13, 12, 1))
	arm.set_dir(EAST)
	var/obj/structure/refinery/R = new(locate(14, 12, 1))
	var/list/power = chem_power(arm, 13, 13)
	arm.on = TRUE
	arm.arm_wake()
	arm.next_swing = 0
	factory_arms_step()
	chem_check(B.loc == R && R.factory_output_barrel() == B, "a feeder arm carries a drained barrel from a station into a refinery as its output barrel")
	arm.on = FALSE
	arm.next_swing = 0
	factory_arms_step()
	for (var/obj/O in list(S, arm, R) + power)
		qdel(O)

/proc/chem_catalog_checks()
	chem_check(get_recipe_node_req("/obj/structure/reagent_dispensers/largebarrel/factory_station") == "factories", "the barrel station unlocks with Factories")
	chem_check(get_recipe_node_req("/obj/item/factory_belt_assembly/gate/reagent") == "automation", "the reagent gate unlocks with Automation")
	chem_check("welding_tank" in icon_states('icons/obj/barrel.dmi'), "the station reuses an existing sprite")
	var/list/found = list()
	for (var/line in splittext(file2text("config/crafting/material_recipes_global.txt"), "\n"))
		for (var/path in list("/obj/structure/reagent_dispensers/largebarrel/factory_station,", "/obj/item/factory_belt_assembly/gate/reagent,"))
			if (findtext(line, "RECIPE: ") == 1 && findtext(line, path))
				found |= path
	chem_check(found.len == 2, "both parts have global recipes")
