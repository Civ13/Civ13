// Chemistry automation phase 2: the reaction vessel on a pipe network.
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
/obj/map_metadata/vessel_probe/New()
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
		map = new /obj/map_metadata/vessel_probe
		map.ordinal_age = 8
		for (var/x in 1 to 20)
			for (var/y in 1 to 20)
				pipe_floor(x, y)
		pipe_check(!world.port, "fixture has no listening port")
		vessel_network_checks()
		vessel_catalyst_checks()
		vessel_site_checks()
		vessel_save_checks()
		vessel_catalog_checks()
	catch(var/exception/e)
		pipe_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = pipe_failures, "runtime_error" = pipe_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/vessel_amount(obj/O, id)
	return round(O.reagents.get_reagent_amount(id), 0.01)

/proc/vessel_tank(x, y, id, amount)
	var/obj/structure/fluid_tank/T = new(locate(x, y, 1))
	T.filter_reagent = id
	if (amount)
		T.reagents.add_reagent(id, amount)
	return T

// Gasoline and ethanol tanks -> vessel (engine fuel) -> engine fuel tank.
/proc/vessel_network_checks()
	var/list/pipes = pipe_line(2, 8, 2)
	var/obj/structure/fluid_tank/gas = vessel_tank(2, 3, "gasoline", 500)
	var/obj/structure/fluid_tank/eth = vessel_tank(3, 3, "pethanol", 100)
	var/obj/structure/fluid_tank/out = vessel_tank(4, 3, "enginefuel", 0)
	var/obj/structure/fluid_pump/P = new(locate(6, 1, 1))
	var/list/power = pipe_power(P, 6, 1)
	P.on = TRUE
	var/obj/structure/fluid_vessel/V = new(locate(8, 3, 1))
	factory_fluids_step()
	var/datum/fluid_network/N = fluid_network_of(V)
	pipe_check(N && (gas in N.members) && (V in N.members), "an idle reaction vessel joins its pipe network")
	pipe_check(!V.reagents.total_volume, "a vessel without a recipe takes nothing")
	V.set_recipe("enginefuel")
	pipe_check(V.batch_count() == 20 && V.batch_want("gasoline") == 180 && V.batch_want("pethanol") == 20 && !V.batch_want("water"), "a vessel wants whole batches of its recipe's inputs and nothing else")
	var/steps = 0
	while (V.stage == 0 && steps < 30)
		steps++
		factory_fluids_step()
	pipe_check(vessel_amount(V, "gasoline") == 180 && vessel_amount(V, "pethanol") == 20 && vessel_amount(gas, "gasoline") == 320 && vessel_amount(eth, "pethanol") == 80, "the vessel draws a full batch in ratio from the tanks")
	pipe_check(steps == 11 && V.stage == 1 && !vessel_amount(V, "enginefuel"), "the full batch waits inert, unreacted, without power")
	factory_fluids_step()
	factory_fluids_step()
	pipe_check(V.stage == 1 && !V.powered && !vessel_amount(V, "enginefuel") && vessel_amount(gas, "gasoline") == 320, "an unpowered vessel holds its batch and takes no more")
	var/list/vpower = pipe_power(V, 9, 3)
	factory_fluids_step()
	factory_fluids_step()
	var/obj/structure/cable/C = vpower[1]
	pipe_check(V.powered && C.power_consumers[V] == V.powerneeded && !vessel_amount(V, "enginefuel"), "a cabled vessel draws power while it reacts")
	factory_fluids_step()
	pipe_check(V.stage == 2 && vessel_amount(V, "enginefuel") + vessel_amount(out, "enginefuel") == 200 && !vessel_amount(V, "gasoline") && (V in C.power_consumers), "after three powered steps the batch reacts at once and keeps its power for that step")
	factory_fluids_step()
	pipe_check(!V.powered && !(V in C.power_consumers), "the vessel releases its power on the next step")
	steps = 0
	while (V.stage == 2 && steps < 30)
		steps++
		factory_fluids_step()
	pipe_check(vessel_amount(out, "enginefuel") == 200 && !vessel_amount(V, "enginefuel") && V.stage == 0, "the product leaves through the pipes and the vessel starts the next batch")
	pipe_check(vessel_amount(V, "gasoline") + vessel_amount(V, "pethanol") == 20 && vessel_amount(out, "enginefuel") == 200, "the next batch starts filling as soon as the product is out")
	for (var/obj/O in pipes + list(gas, eth, out, P, V) + power + vpower)
		if (!QDELETED(O))
			qdel(O)
	fluid_mark_dirty()

// Catalysts stay in the vessel between batches; a recipe change flushes them.
/proc/vessel_catalyst_checks()
	var/obj/structure/fluid_vessel/V = new(locate(12, 12, 1))
	var/list/power = pipe_power(V, 13, 12)
	V.set_recipe("polyethylene")
	pipe_check(V.batch_count() == 7 && V.batch_want("ethylene") == 14 && V.batch_want("titaniumchloride") == 10, "batches leave room for the recipe's catalysts")
	V.reagents.add_reagent("titaniumchloride", 10)
	V.reagents.add_reagent("borontrifluoride", 5)
	V.reagents.add_reagent("aluminumchloride", 5)
	V.reagents.add_reagent("ethylene", 13)
	V.vessel_step()
	pipe_check(V.stage == 0 && !vessel_amount(V, "polyethylene"), "a batch one unit short never reacts")
	V.reagents.add_reagent("ethylene", 1)
	for (var/i in 1 to 4)
		V.vessel_step()
	pipe_check(V.stage == 2 && vessel_amount(V, "polyethylene") == 175 && vessel_amount(V, "titaniumchloride") == 10, "the batch reacts and keeps its catalysts")
	pipe_check(V.fluid_supplies("polyethylene") && !V.fluid_supplies("titaniumchloride") && V.fluid_supply_tier() && !V.fluid_demand_tier(), "an emptying vessel offers its product but not its catalysts")
	V.reagents.del_reagent("polyethylene")
	V.vessel_step()
	pipe_check(V.stage == 0 && vessel_amount(V, "aluminumchloride") == 5 && !V.batch_want("titaniumchloride") && V.batch_want("ethylene") == 14, "once the product is out the vessel refills inputs only")
	V.set_recipe("enginefuel")
	pipe_check(V.stage == 2 && V.flushing && V.fluid_supplies("titaniumchloride"), "a new recipe flushes the old catalysts")
	V.reagents.clear_reagents()
	V.vessel_step()
	pipe_check(V.stage == 0 && !V.flushing && V.fluid_demand_tier(), "an emptied vessel starts filling for its new recipe")
	pipe_check(V.flags & NOREACT, "the vessel holds its contents inert")
	for (var/obj/O in list(V) + power)
		qdel(O)
	fluid_mark_dirty()

// Heated recipes need a heated bench or a powered vessel; nothing else.
/proc/vessel_site_checks()
	var/datum/chemical_reaction/R = controlled_reaction("polypropylene")
	var/obj/structure/fluid_vessel/V = new(locate(15, 12, 1))
	V.reagents.add_reagent("propylene", 2)
	V.reagents.add_reagent("titaniumchloride", 10)
	V.reagents.add_reagent("borontrifluoride", 5)
	V.reagents.add_reagent("aluminumchloride", 5)
	V.powered = FALSE
	var/cold = R.can_happen(V.reagents)
	V.powered = TRUE
	pipe_check(!cold && R.can_happen(V.reagents), "a heated recipe runs only in a powered vessel")
	V.powered = FALSE
	var/obj/structure/reaction_bench/bench = new(locate(16, 12, 1))
	var/obj/item/weapon/reagent_containers/glass/beaker/large/B = new(locate(16, 12, 1))
	bench.install_beaker(B)
	B.reagents.add_reagent("propylene", 2)
	B.reagents.add_reagent("titaniumchloride", 10)
	B.reagents.add_reagent("borontrifluoride", 5)
	B.reagents.add_reagent("aluminumchloride", 5)
	var/unheated = R.can_happen(B.reagents)
	bench.heated_until = world.time + 600
	pipe_check(!unheated && R.can_happen(B.reagents), "the reaction bench still needs its burner for heated recipes")
	var/obj/item/weapon/reagent_containers/glass/beaker/large/loose = new(locate(17, 12, 1))
	loose.reagents.add_reagent("gelatin", 5)
	pipe_check(!controlled_reaction("gelatin_foam").can_happen(loose.reagents), "bench-only recipes still do not run in a loose beaker")
	pipe_check(bench.reaction_paths.len == controlled_reaction_paths().len && controlled_reaction("enginefuel") && controlled_reaction("gelatin_foam"), "the bench and the vessel share one recipe list")
	for (var/obj/O in list(V, bench, loose))
		qdel(O)

/proc/vessel_save_checks()
	var/obj/structure/fluid_vessel/V = new(locate(15, 15, 1))
	V.set_recipe("enginefuel")
	V.stage = 1
	V.react_steps = 2
	V.powered = TRUE
	var/list/saved = V.get_saved_vars()
	pipe_check(("recipe_id" in saved) && ("stage" in saved) && V.persistence_runtime_var("powered") && V.persistence_runtime_var("react_steps") && !("react_steps" in saved), "recipe and stage are saved; power and reaction time are not")
	fluid_vessels -= V
	fluid_networks_dirty = FALSE
	V.after_load()
	pipe_check(!V.powered && !V.react_steps && (V in fluid_vessels) && fluid_networks_dirty, "a reloaded vessel restarts its reaction time unpowered and rejoins the networks")
	qdel(V)

/proc/vessel_catalog_checks()
	pipe_check(get_recipe_node_req("/obj/structure/fluid_vessel") == "factories", "the reaction vessel unlocks with Factories")
	var/list/states = icon_states('icons/obj/chemical.dmi')
	pipe_check(("distill" in states) && ("distill_empty" in states) && ("distill_active" in states), "the vessel reuses existing sprites")
	var/found = FALSE
	for (var/line in splittext(file2text("config/crafting/material_recipes_global.txt"), "\n"))
		if (findtext(line, "RECIPE: ") == 1 && findtext(line, ",/obj/structure/fluid_vessel,"))
			found = TRUE
	pipe_check(found, "the reaction vessel has a global recipe")
