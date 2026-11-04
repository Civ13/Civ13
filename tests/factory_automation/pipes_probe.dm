// Chemistry automation phase 1: pipe networks, pumps, holding tanks, water
// intakes and the phase 0 machines on pipes. Runs the production sources
// through the shared resource-extraction fixture with ordinary game startup
// disabled; network steps are called directly.
/world
	hub = ""
	hub_password = ""
	maxx = 20
	maxy = 20
	maxz = 1
	turf = /turf
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/obj/map_metadata/pipe_probe/New()
	return
var/pipe_failures = 0
var/pipe_runtime_error = FALSE
/proc/pipe_check(condition, label)
	if (!condition)
		pipe_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	pipe_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/proc/pipe_floor(x, y)
	var/turf/T = locate(x, y, 1)
	return T.ChangeTurf(/turf/floor/dirt, FALSE, FALSE)
/proc/pipe_power(obj/O, x, y)
	var/obj/structure/cable/C = new(locate(x, y, 1))
	var/obj/structure/engine/E = new(locate(x, y, 1))
	E.on = TRUE
	E.maxpower = 50
	E.connections = list(C)
	C.connections = list(O, E)
	O.powersource = C
	C.rebuild_supply()
	return list(C, E)
/proc/pipe_line(x1, x2, y)
	var/list/L = list()
	for (var/x in x1 to x2)
		L += new /obj/structure/fluid_pipe(locate(x, y, 1))
	return L
/proc/pipe_gas(obj/O)
	return round(O.reagents.get_reagent_amount("gasoline"), 0.01)
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
		map = new /obj/map_metadata/pipe_probe
		map.ordinal_age = 8
		for (var/x in 1 to 20)
			for (var/y in 1 to 20)
				pipe_floor(x, y)
		pipe_check(!world.port, "fixture has no listening port")
		pipe_network_checks()
		pipe_intake_checks()
		pipe_refinery_checks()
		pipe_save_checks()
		pipe_catalog_checks()
	catch(var/exception/e)
		pipe_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = pipe_failures, "runtime_error" = pipe_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

// Station (source) -> pipes -> holding tank (buffer) and engine (sink).
/proc/pipe_network_checks()
	var/list/pipes = pipe_line(3, 8, 2)
	var/obj/structure/reagent_dispensers/largebarrel/factory_station/S = new(locate(2, 2, 1))
	S.anchored = TRUE
	S.reagents.add_reagent("gasoline", 100)
	var/obj/structure/fluid_tank/T = new(locate(5, 3, 1))
	var/obj/structure/engine/internal/gasoline/E = new(locate(9, 2, 1))
	E.anchored = TRUE
	var/obj/item/weapon/reagent_containers/glass/barrel/fueltank/tank = new(locate(10, 2, 1))
	E.fueltank = tank
	var/obj/structure/fluid_pump/P = new(locate(6, 1, 1))
	factory_fluids_step()
	var/datum/fluid_network/N = fluid_network_of(S)
	pipe_check(N && N.pipes.len == 6 && (T in N.members) && (E in N.members) && (P in N.members), "pipes join into one network with the station, tank, engine and pump")
	var/obj/structure/fluid_pipe/first = pipes[1]
	var/obj/structure/fluid_pipe/middle = pipes[3]
	pipe_check(first.icon_state == "intact" && first.dir == EAST && middle.icon_state == "manifold" && middle.dir == SOUTH, "pipes draw straight runs and a junction toward the tank")
	pipe_check(!N.last_moved && pipe_gas(S) == 100, "a network without a running pump moves nothing")
	var/list/power = pipe_power(P, 6, 1)
	P.on = TRUE
	N.idle_steps = 0
	factory_fluids_step()
	var/obj/structure/cable/C = power[1]
	pipe_check(P.powered && C.power_consumers[P] == P.powerneeded, "a switched-on cabled pump draws its power")
	pipe_check(pipe_gas(tank) == 20 && pipe_gas(S) == 80 && !T.reagents.total_volume, "a powered pump moves twenty units a step, sinks first")
	tank.reagents.add_reagent("gasoline", 230)
	factory_fluids_step()
	pipe_check(pipe_gas(T) == 20 && pipe_gas(S) == 60, "with the engine's tank full, the holding tank fills from the source")
	T.reagents.del_reagent("gasoline")
	T.filter_reagent = "water"
	factory_fluids_step()
	pipe_check(!T.reagents.total_volume && pipe_gas(S) == 60 && N.idle_steps == 1, "a tank filtered to another reagent takes nothing and the network goes idle")
	T.filter_reagent = null
	var/waited = 0
	while (!T.reagents.total_volume && waited < 10)
		waited++
		factory_fluids_step()
	pipe_check(waited == 5 && pipe_gas(T) == 20, "an idle network looks again within five steps")
	tank.reagents.remove_reagent("gasoline", 100)
	T.reagents.add_reagent("gasoline", 100)
	S.reagents.clear_reagents()
	N.idle_steps = 0
	factory_fluids_step()
	pipe_check(pipe_gas(tank) == 170 && pipe_gas(T) == 100, "a sink draws from a holding tank, and tanks never trade with each other")
	// A closed valve splits the line; the engine is then on its own network.
	var/obj/structure/fluid_pipe/old = pipes[5]
	var/turf/valve_turf = old.loc
	qdel(old)
	var/obj/structure/fluid_pipe/valve/V = new(valve_turf)
	V.open = FALSE
	fluid_mark_dirty()
	factory_fluids_step()
	pipe_check(fluid_network_of(S) != fluid_network_of(E) && !(E in fluid_network_of(S).members), "a closed valve splits the network")
	pipe_check(pipe_gas(tank) == 170, "the engine beyond a closed valve gets nothing")
	V.open = TRUE
	fluid_mark_dirty()
	factory_fluids_step()
	pipe_check(fluid_network_of(S) == fluid_network_of(E) && pipe_gas(tank) == 190, "an open valve rejoins the network")
	// Filling station as a sink.
	S.station_fill = TRUE
	tank.reagents.add_reagent("gasoline", 100)
	fluid_mark_dirty()
	factory_fluids_step()
	pipe_check(pipe_gas(S) == 20, "a filling barrel station draws from the network")
	P.on = FALSE
	factory_fluids_step()
	pipe_check(!P.powered && !(P in C.power_consumers), "a switched-off pump releases its power")
	for (var/obj/O in pipes + list(S, T, E, tank, P, V) + power)
		if (!QDELETED(O))
			qdel(O)
	fluid_mark_dirty()

/proc/pipe_intake_checks()
	var/turf/water = locate(12, 5, 1)
	water.ChangeTurf(/turf/floor/beach/water/swamp, FALSE, FALSE)
	var/obj/structure/fluid_intake/I = new(locate(12, 6, 1))
	var/obj/structure/fluid_pipe/pipe = new(locate(13, 6, 1))
	var/obj/structure/fluid_tank/T = new(locate(14, 6, 1))
	var/obj/structure/fluid_pump/P = new(locate(13, 7, 1))
	var/list/power = pipe_power(P, 13, 8)
	P.on = TRUE
	factory_fluids_step()
	var/turf/floor/beach/water/W = water
	var/sick = 10 * W.sickness * 0.05
	pipe_check(abs(T.reagents.total_volume - 10) < 0.01 && abs(T.reagents.get_reagent_amount("water") - (10 - sick)) < 0.01, "a water intake beside open water supplies what a person filling a container there would get")
	var/obj/structure/fluid_intake/dry = new(locate(17, 6, 1))
	pipe_check(!dry.water_turf() && !dry.fluid_supply_holder().total_volume, "an intake away from water supplies nothing")
	for (var/obj/O in list(I, pipe, T, P, dry) + power)
		qdel(O)
	fluid_mark_dirty()

// Oil well (source) -> refinery feed (sink); refinery output -> filtered tank.
/proc/pipe_refinery_checks()
	new /obj/structure/oil_spring(locate(2, 12, 1))
	var/obj/structure/oilwell/W = new(locate(2, 12, 1))
	var/obj/item/weapon/reagent_containers/glass/barrel/head = new(locate(1, 12, 1))
	head.reagents.add_reagent("petroleum", 100)
	W.factory_insert(head)
	var/list/pipes = pipe_line(3, 5, 12)
	var/obj/structure/refinery/R = new(locate(6, 12, 1))
	var/obj/item/weapon/reagent_containers/glass/barrel/out = new(locate(7, 13, 1))
	R.factory_insert(out)
	var/obj/structure/fluid_tank/T = new(locate(4, 13, 1))
	T.filter_reagent = "gasoline"
	var/obj/structure/fluid_pump/P = new(locate(4, 11, 1))
	var/list/power = pipe_power(P, 4, 10)
	P.on = TRUE
	factory_fluids_step()
	pipe_check(R.volume == 20 && head.reagents.get_reagent_amount("petroleum") == 80, "a refinery draws petroleum from an oil well's barrel through pipes")
	R.volume = 300
	out.reagents.add_reagent("gasoline", 50)
	factory_fluids_step()
	pipe_check(pipe_gas(T) == 20 && pipe_gas(out) == 30 && head.reagents.get_reagent_amount("petroleum") == 80, "a full refinery's output barrel feeds a gasoline tank and petroleum stays in the well")
	for (var/obj/O in pipes + list(W, R, T, P, out) + power)
		if (!QDELETED(O))
			qdel(O)
	fluid_mark_dirty()

/proc/pipe_save_checks()
	var/obj/structure/fluid_pipe/P = new(locate(15, 15, 1))
	var/obj/structure/fluid_pipe/valve/V = new(locate(16, 15, 1))
	V.open = FALSE
	var/obj/structure/fluid_pump/pump = new(locate(15, 16, 1))
	pump.on = TRUE
	pump.powered = TRUE
	var/obj/structure/fluid_tank/T = new(locate(15, 14, 1))
	T.filter_reagent = "water"
	factory_fluids_step()
	pipe_check(P.network && P.persistence_runtime_var("network") && !("network" in P.get_saved_vars()), "a pipe's network is runtime-only")
	pipe_check(("open" in V.get_saved_vars()) && ("on" in pump.get_saved_vars()) && pump.persistence_runtime_var("powered") && ("filter_reagent" in T.get_saved_vars()), "valve, pump switch and tank filter are saved; pump power is not")
	fluid_networks_dirty = FALSE
	pump.after_load()
	pipe_check(!pump.powered && fluid_networks_dirty, "a reloaded pump starts unpowered and networks are rebuilt")
	fluid_networks_dirty = FALSE
	fluid_pipes -= P
	P.after_load()
	pipe_check((P in fluid_pipes) && fluid_networks_dirty, "a reloaded pipe rejoins the pipe list")
	pipe_check(T.flags & NOREACT, "holding tanks are inert")
	for (var/obj/O in list(P, V, pump, T))
		qdel(O)

/proc/pipe_catalog_checks()
	var/list/paths = list("/obj/structure/fluid_pipe", "/obj/structure/fluid_pipe/valve", "/obj/structure/fluid_pump", "/obj/structure/fluid_tank", "/obj/structure/fluid_intake")
	var/gated = 0
	for (var/path in paths)
		if (get_recipe_node_req(path) == "factories")
			gated++
	pipe_check(gated == 5, "pipes, valves, pumps, tanks and intakes unlock with Factories")
	var/list/states = icon_states('icons/obj/machines/pipes.dmi')
	pipe_check(("intact" in states) && ("manifold" in states) && ("compressor" in states) && ("inlet" in states) && ("air" in icon_states('icons/obj/barrel.dmi')), "the parts reuse existing sprites")
	var/list/found = list()
	for (var/line in splittext(file2text("config/crafting/material_recipes_global.txt"), "\n"))
		for (var/path in paths)
			if (findtext(line, "RECIPE: ") == 1 && findtext(line, ",[path],"))
				found |= path
	pipe_check(found.len == 5, "all five parts have global recipes")
