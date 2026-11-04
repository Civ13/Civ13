// Chemistry automation phase 4: the pipe meter.
// Runs the production sources through the shared resource-extraction fixture
// with ordinary game startup disabled; network steps are called directly.
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
/obj/map_metadata/meter_probe/New()
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
		map = new /obj/map_metadata/meter_probe
		map.ordinal_age = 8
		map.age = "1900"
		for (var/x in 1 to 20)
			for (var/y in 1 to 20)
				pipe_floor(x, y)
		pipe_check(!world.port, "fixture has no listening port")
		meter_checks()
		meter_catalog_checks()
	catch(var/exception/e)
		pipe_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = pipe_failures, "runtime_error" = pipe_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/meter_has(list/lines, text)
	for (var/line in lines)
		if (findtext(line, text))
			return TRUE
	return FALSE

/proc/meter_checks()
	var/obj/structure/fluid_meter/loose = new(locate(12, 12, 1))
	pipe_check(meter_has(loose.report(), "not on a pipe network"), "a meter off the pipes says so")
	var/list/pipes = pipe_line(2, 6, 2)
	var/obj/structure/fluid_tank/T = new(locate(2, 3, 1))
	T.reagents.add_reagent("gasoline", 200)
	var/obj/structure/fluid_tank/out = new(locate(5, 3, 1))
	out.filter_reagent = "gasoline"
	var/obj/structure/reagent_dispensers/largebarrel/factory_station/S = new(locate(6, 3, 1))
	S.anchored = TRUE
	S.station_fill = TRUE
	var/obj/structure/fluid_vessel/V = new(locate(3, 3, 1))
	V.set_recipe("enginefuel")
	var/obj/structure/fluid_pump/P = new(locate(4, 1, 1))
	var/obj/structure/fluid_meter/M = new(locate(4, 2, 1))
	factory_fluids_step()
	var/list/lines = M.report()
	pipe_check(meter_has(lines, "5 pipes, 0 of 1 pumps running") && meter_has(lines, "fluid pump: off"), "a meter counts pipes and pumps and shows a stopped pump")
	pipe_check(M.icon_state == "meter", "the dial is dark while nothing moves")
	var/list/power = pipe_power(P, 4, 1)
	P.on = TRUE
	fluid_network_of(P).idle_steps = 0
	factory_fluids_step()
	lines = M.report()
	pipe_check(meter_has(lines, "1 of 1 pumps running") && meter_has(lines, "moved 20 units last step") && meter_has(lines, "fluid pump: running"), "a meter reports running pumps and last step's flow")
	pipe_check(M.icon_state == "meter_on", "the dial lights while liquid moves")
	pipe_check(meter_has(lines, "holding tank: 180/1000 Gasoline") && meter_has(lines, "only Gasoline") && meter_has(lines, "Engine fuel - 9:1 blend, filling, 20/200"), "tank fill, filters and vessel recipe and stage are listed")
	pipe_check(meter_has(lines, "barrel station: taking"), "other machines show their pipe role")
	P.on = FALSE
	for (var/i in 1 to 2)
		factory_fluids_step()
	pipe_check(M.icon_state == "meter" && meter_has(M.report(), "idle"), "the dial goes dark and the network reads idle when flow stops")
	fluid_meters -= M
	M.after_load()
	pipe_check((M in fluid_meters) && !(M in fluid_network_of(P).members), "a reloaded meter rejoins the meter list and is never a network member")
	for (var/obj/O in pipes + list(T, out, S, V, P, M, loose) + power)
		if (!QDELETED(O))
			qdel(O)
	fluid_mark_dirty()

/proc/meter_catalog_checks()
	pipe_check(get_recipe_node_req("/obj/structure/fluid_meter") == "automation", "the pipe meter unlocks with Automation")
	var/list/states = icon_states('icons/obj/machines/pipes.dmi')
	pipe_check(("meter" in states) && ("meter_on" in states), "the meter reuses existing sprites")
	var/found = FALSE
	for (var/line in splittext(file2text("config/crafting/material_recipes_global.txt"), "\n"))
		if (findtext(line, "RECIPE: ") == 1 && findtext(line, ",/obj/structure/fluid_meter,"))
			found = TRUE
	pipe_check(found, "the pipe meter has a global recipe")
