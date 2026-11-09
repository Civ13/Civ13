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
		pipe_wrench_checks()
		pipe_intake_checks()
		pipe_refinery_checks()
		pipe_save_checks()
		pipe_plumbing_checks()
		pipe_washing_machine_checks()
		pipe_habitat_checks()
		pipe_barrel_checks()
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

// Pipes and fluid machines can be unwrenched; while unfastened they join no
// network and supply or take nothing.
/proc/pipe_wrench_checks()
	var/list/fixed = list()
	for (var/path in list(/obj/structure/fluid_pipe, /obj/structure/fluid_pipe/valve, /obj/structure/fluid_pump, /obj/structure/fluid_tank, /obj/structure/fluid_intake, /obj/structure/fluid_vessel, /obj/structure/fluid_bottler, /obj/structure/fluid_tablet_press, /obj/structure/fluid_meter))
		var/obj/structure/S = path
		if (initial(S.not_movable))
			fixed += "[path]"
	pipe_check(!fixed.len, "pipes and fluid machines can be unwrenched[fixed.len ? " (fixed: [english_list(fixed)])" : ""]")
	var/list/pipes = pipe_line(3, 5, 18)
	var/obj/structure/fluid_tank/T = new(locate(4, 19, 1))
	factory_fluids_step()
	var/obj/structure/fluid_pipe/end = pipes[3]
	var/datum/fluid_network/N = end.network
	pipe_check(N && N.pipes.len == 3 && (T in N.members), "a fastened tank joins its pipe run")
	T.anchored = FALSE
	T.anchor_changed()
	end.anchored = FALSE
	end.anchor_changed()
	pipe_check(fluid_networks_dirty && !T.fluid_supply_tier() && !T.fluid_demand_tier() && !end.fluid_open(), "unfastening asks for a rebuild and leaves the tank and pipe without a role")
	factory_fluids_step()
	N = fluid_network_of(T)
	var/obj/structure/fluid_pipe/first = pipes[1]
	pipe_check(!N && !end.network && first.network && first.network.pipes.len == 2, "an unfastened tank and pipe leave the network")
	T.anchored = TRUE
	T.anchor_changed()
	end.anchored = TRUE
	end.anchor_changed()
	factory_fluids_step()
	pipe_check(end.network && end.network.pipes.len == 3 && (T in end.network.members), "fastening them again rejoins the network")
	for (var/obj/O in pipes + list(T))
		qdel(O)
	fluid_mark_dirty()

/proc/pipe_intake_checks()
	var/turf/water = locate(12, 5, 1)
	water.ChangeTurf(/turf/floor/beach/water/swamp, FALSE, FALSE)
	var/obj/structure/fluid_intake/I = new(locate(12, 6, 1))
	var/obj/structure/fluid_pipe/pipe = new(locate(13, 6, 1))
	var/obj/structure/fluid_tank/T = new(locate(14, 6, 1))
	var/obj/structure/fluid_tank/T2 = new(locate(13, 5, 1))
	var/obj/structure/fluid_pump/P = new(locate(13, 7, 1))
	var/list/power = pipe_power(P, 13, 8)
	P.on = TRUE
	factory_fluids_step()
	var/turf/floor/beach/water/W = water
	var/sick = 10 * W.sickness * 0.05
	var/total = T.reagents.total_volume + T2.reagents.total_volume
	var/water_in = T.reagents.get_reagent_amount("water") + T2.reagents.get_reagent_amount("water")
	pipe_check(abs(total - 10) < 0.01 && abs(water_in - (10 - sick)) < 0.01, "a water intake beside open water supplies what a person filling a container there would get, at most its rate per step even with two tanks demanding")
	var/obj/structure/fluid_intake/dry = new(locate(17, 6, 1))
	pipe_check(!dry.water_turf() && !dry.fluid_supply_holder().total_volume, "an intake away from water supplies nothing")
	for (var/obj/O in list(I, pipe, T, T2, P, dry) + power)
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

// Holding tank (buffer) -> water tap and piped shower (sinks).
/proc/pipe_plumbing_checks()
	var/list/pipes = pipe_line(3, 6, 4)
	var/obj/structure/fluid_tank/T = new(locate(2, 4, 1))
	T.reagents.add_reagent("water", 45)
	T.reagents.add_reagent("cholera", 5)
	var/obj/structure/water_tap/tap = new(locate(4, 5, 1))
	var/obj/structure/shower/piped/shower = new(locate(6, 5, 1))
	pipe_check(!tap.reagents.total_volume && !shower.water_stored, "a new tap and piped shower start dry")
	shower.attack_hand(null)
	pipe_check(!shower.on, "a dry piped shower will not turn on")
	var/obj/structure/fluid_pump/P = new(locate(5, 3, 1))
	var/list/power = pipe_power(P, 5, 2)
	P.on = TRUE
	for (var/i in 1 to 4)
		factory_fluids_step()
	pipe_check(tap.reagents.get_reagent_amount("water") == 45 && tap.reagents.get_reagent_amount("cholera") == 5, "a tap holds what the pipes bring it, sickness included")
	T.reagents.add_reagent("water", 100)
	fluid_mark_dirty() // wake the idle network
	for (var/i in 1 to 6)
		factory_fluids_step()
	pipe_check(shower.water_stored > 0 && !shower.fluid_demand("cholera"), "a piped shower fills with water and refuses anything else")
	pipe_check(tap.reagents.total_volume + shower.water_stored + T.reagents.total_volume == 150, "plumbing moves water without making any")
	P.on = FALSE
	var/obj/item/weapon/reagent_containers/glass/beaker/B = new(locate(4, 6, 1))
	var/before = tap.reagents.total_volume
	tap.reagents.trans_to_obj(B, 10)
	pipe_check(B.reagents.total_volume == 10 && tap.reagents.total_volume == before - 10, "filling a container at a tap empties the tap by as much")
	shower.water_stored = 7
	shower.on = TRUE
	shower.process()
	pipe_check(shower.on && shower.water_stored == 2, "a running piped shower uses its water")
	shower.process()
	pipe_check(!shower.on && shower.water_stored == 2, "a piped shower turns itself off when its water runs out")
	pipe_check(tap.flags & NOREACT, "taps are inert")
	for (var/obj/O in pipes + list(T, tap, shower, P, B) + power)
		if (!QDELETED(O))
			qdel(O)
	fluid_mark_dirty()

// A washing machine receives a cycle's water from a connected pipe network.
/proc/pipe_washing_machine_checks()
	var/obj/machinery/washing_machine/W = new(locate(4, 12, 1))
	pipe_check(!W.reserve_wash_water() && !W.water_stored, "a disconnected washing machine cannot reserve water")
	var/list/pipes = pipe_line(3, 5, 11)
	var/obj/structure/fluid_tank/T = new(locate(2, 11, 1))
	var/obj/structure/fluid_pump/P = new(locate(5, 10, 1))
	var/list/power = pipe_power(P, 5, 9)
	T.reagents.add_reagent("water", 40)
	T.reagents.add_reagent("cholera", 10)
	factory_fluids_step()
	pipe_check(!W.reserve_wash_water() && !W.water_stored, "an unpowered pipe network supplies no wash water")
	P.on = TRUE
	for (var/i in 1 to 6)
		factory_fluids_step()
	pipe_check(W.water_stored == 20 && !W.fluid_demand("cholera"), "a powered network supplies only water up to one wash")
	pipe_check(W.reserve_wash_water() && !W.water_stored && !W.reserve_wash_water(), "a wash consumes one full supply only once")
	W.water_stored = 20
	for (var/obj/O in pipes)
		qdel(O)
	pipe_check(!W.reserve_wash_water() && W.water_stored == 20, "disconnecting the pipe prevents a wash even with stored water")
	for (var/obj/O in list(W, T, P) + power)
		if (!QDELETED(O))
			qdel(O)
	fluid_mark_dirty()

// Water recycler (source) -> electrolyser (sink), as between two habitat modules.
/proc/pipe_habitat_checks()
	var/list/pipes = pipe_line(3, 6, 8)
	var/obj/structure/life_support/water_recycler/R = new(locate(2, 8, 1))
	R.water = 50
	var/obj/structure/life_support/electrolyser/E = new(locate(7, 8, 1))
	E.water = E.water_max - 5
	var/obj/structure/fluid_pump/P = new(locate(5, 9, 1))
	var/list/power = pipe_power(P, 5, 10)
	P.on = TRUE
	factory_fluids_step()
	R.pipe_settle()
	pipe_check(E.water == E.water_max && R.water == 45, "an electrolyser takes only what it has room for from a recycler through pipes")
	E.water = 0
	factory_fluids_step()
	R.pipe_settle()
	pipe_check(E.water == 20 && R.water == 25, "a recycler's water feeds an electrolyser at the pump's rate")
	pipe_check(!E.fluid_demand("cholera") && !R.fluid_supplies("cholera"), "habitat machines pipe only water")
	pipe_check(R.persistence_runtime_var("pipe_out") && R.persistence_runtime_var("pipe_offered") && ("water" in R.get_saved_vars()), "the recycler saves its water, not its pipe holder")
	for (var/obj/O in pipes + list(R, E, P) + power)
		if (!QDELETED(O))
			qdel(O)
	fluid_mark_dirty()

// Wrenched steel barrel (source) -> water tap (sink).
/proc/pipe_barrel_checks()
	var/list/pipes = pipe_line(11, 14, 10)
	var/obj/item/weapon/reagent_containers/glass/barrel/modern/B = new(locate(10, 10, 1))
	B.reagents.add_reagent("water", 100)
	var/obj/structure/water_tap/tap = new(locate(12, 11, 1))
	var/obj/structure/fluid_pump/P = new(locate(13, 9, 1))
	var/list/power = pipe_power(P, 13, 8)
	P.on = TRUE
	factory_fluids_step()
	pipe_check(!(B in fluid_network_of(tap)?.members) && !tap.reagents.total_volume && B.reagents.total_volume == 100, "a steel barrel beside a pipe stays off the network until wrenched")
	var/obj/item/weapon/wrench/W = new(locate(18, 18, 1))
	var/obj/item/weapon/reagent_containers/glass/barrel/modern/far = new(locate(18, 10, 1))
	far.attackby(W, null)
	pipe_check(!far.pipe_connected, "a steel barrel away from pipes cannot be fitted")
	B.attackby(W, null)
	factory_fluids_step()
	var/datum/fluid_network/N = fluid_network_of(tap)
	pipe_check(B.pipe_connected && N && (B in N.members) && !B.fluid_demand_tier(), "a wrenched steel barrel joins the network as a source only")
	pipe_check(tap.reagents.get_reagent_amount("water") == 20 && B.reagents.total_volume == 80, "a fitted barrel feeds a tap at the pump's rate")
	var/obj/structure/fluid_pipe/first = pipes[1]
	pipe_check(WEST in first.joined_dirs(), "the pipe beside a fitted barrel draws a joint toward it")
	pipe_check("pipe_connected" in B.get_saved_vars(), "the fitting is saved")
	B.forceMove(locate(10, 12, 1))
	pipe_check(!B.pipe_connected && fluid_networks_dirty, "moving a fitted barrel detaches it")
	factory_fluids_step()
	pipe_check(!(B in fluid_network_of(tap)?.members) && B.reagents.total_volume == 80, "a detached barrel leaves the network and keeps its water")
	B.forceMove(locate(10, 10, 1))
	B.attackby(W, null)
	B.attackby(W, null)
	pipe_check(!B.pipe_connected, "a wrench detaches a fitted barrel")
	var/obj/item/weapon/reagent_containers/glass/barrel/wood = new(locate(15, 10, 1))
	wood.reagents.add_reagent("water", 50)
	fluid_mark_dirty()
	factory_fluids_step()
	pipe_check(wood.reagents.total_volume == 50 && !(wood in fluid_network_of(tap)?.members), "wood barrels do not join pipes")
	for (var/obj/O in pipes + list(B, far, wood, tap, P, W) + power)
		if (!QDELETED(O))
			qdel(O)
	fluid_mark_dirty()

/proc/pipe_catalog_checks()
	var/list/paths = list("/obj/structure/fluid_pipe", "/obj/structure/fluid_pipe/valve", "/obj/structure/fluid_pump", "/obj/structure/fluid_tank", "/obj/structure/fluid_intake")
	var/gated = 0
	for (var/path in paths)
		if (get_recipe_node_req(path) == "factories")
			gated++
	pipe_check(gated == 5, "pipes, valves, pumps, tanks and intakes unlock with Factories")
	pipe_check(get_recipe_node_req("/obj/structure/water_tap") == "factories" && get_recipe_node_req("/obj/structure/shower/piped") == "factories", "taps and piped showers unlock with Factories")
	var/list/states = icon_states('icons/obj/machines/pipes.dmi')
	pipe_check(("intact" in states) && ("manifold" in states) && ("compressor" in states) && ("inlet" in states) && ("air" in icon_states('icons/obj/barrel.dmi')), "the parts reuse existing sprites")
	var/list/found = list()
	for (var/line in splittext(file2text("config/crafting/material_recipes_global.txt"), "\n"))
		for (var/path in paths)
			if (findtext(line, "RECIPE: ") == 1 && findtext(line, ",[path],"))
				found |= path
	pipe_check(found.len == 5, "all five parts have global recipes")
