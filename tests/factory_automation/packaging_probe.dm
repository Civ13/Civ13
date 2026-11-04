// Chemistry automation phase 3: the bottler, the automatic tablet press and
// the faster reaction vessels.
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
/obj/map_metadata/packaging_probe/New()
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
		map = new /obj/map_metadata/packaging_probe
		map.ordinal_age = 8
		map.age = "1900"
		for (var/x in 1 to 20)
			for (var/y in 1 to 20)
				pipe_floor(x, y)
		pipe_check(!world.port, "fixture has no listening port")
		bottler_checks()
		press_checks()
		tier_checks()
		packaging_save_checks()
		packaging_catalog_checks()
	catch(var/exception/e)
		pipe_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = pipe_failures, "runtime_error" = pipe_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/pack_amount(datum/reagents/R, id)
	return round(R.get_reagent_amount(id), 0.01)

// Water tank -> pipes -> bottler holding a beaker.
/proc/bottler_checks()
	var/list/pipes = pipe_line(2, 6, 2)
	var/obj/structure/fluid_tank/T = new(locate(2, 3, 1))
	T.reagents.add_reagent("water", 500)
	var/obj/structure/fluid_pump/P = new(locate(4, 1, 1))
	var/list/power = pipe_power(P, 4, 1)
	P.on = TRUE
	var/obj/structure/fluid_bottler/B = new(locate(6, 3, 1))
	var/obj/item/weapon/reagent_containers/glass/beaker/empty = new(locate(10, 10, 1))
	pipe_check(!B.factory_accepts(empty), "a bottler with no reagent set takes nothing")
	B.filter_reagent = "water"
	var/obj/item/weapon/reagent_containers/glass/beaker/oily = new(locate(10, 10, 1))
	oily.reagents.add_reagent("gasoline", 5)
	var/obj/item/weapon/reagent_containers/glass/beaker/closed = new(locate(10, 10, 1))
	closed.flags &= ~OPENCONTAINER
	var/obj/item/weapon/reagent_containers/pill/pill = new(locate(10, 10, 1))
	pipe_check(B.factory_accepts(empty) && !B.factory_accepts(oily) && !B.factory_accepts(closed) && !B.factory_accepts(pill), "a bottler takes open containers holding only its reagent")
	pipe_check(B.factory_insert(empty) && empty.loc == B && !B.factory_accepts(oily) && !B.factory_offer(), "it holds one container at a time and offers nothing while filling")
	factory_fluids_step()
	pipe_check(pack_amount(empty.reagents, "water") == 20 && pack_amount(T.reagents, "water") == 480, "the bottler fills its container from the pipes")
	var/steps = 0
	while (!B.factory_offer() && steps < 20)
		steps++
		factory_fluids_step()
	pipe_check(B.factory_offer() == empty && !empty.reagents.get_free_space() && pack_amount(T.reagents, "water") == 500 - empty.reagents.maximum_volume, "a full container is offered and nothing more is drawn")
	var/turf/dest = locate(7, 3, 1)
	pipe_check(B.factory_take(empty, dest) && empty.loc == dest && !B.held_container(), "an arm can take the full container")
	B.factory_insert(oily)
	B.filter_reagent = null
	pipe_check(!B.held_container(), "a container with another reagent stays out")
	B.filter_reagent = "water"
	var/obj/item/weapon/reagent_containers/glass/beaker/half = new(locate(10, 10, 1))
	B.factory_insert(half)
	qdel(B)
	pipe_check(half.loc == locate(6, 3, 1), "a removed bottler drops its container")
	for (var/obj/O in pipes + list(T, P, empty, oily, closed, pill, half) + power)
		if (!QDELETED(O))
			qdel(O)
	fluid_mark_dirty()

// Carbonate and aspirin tanks -> pipes -> automatic press.
/proc/press_checks()
	var/list/pipes = pipe_line(2, 6, 12)
	var/obj/structure/fluid_tank/carb = new(locate(2, 13, 1))
	carb.reagents.add_reagent("calcium_carbonate", 100)
	var/obj/structure/fluid_tank/asp = new(locate(3, 13, 1))
	asp.reagents.add_reagent("aspirin", 100)
	var/obj/structure/fluid_pump/P = new(locate(4, 11, 1))
	var/list/power = pipe_power(P, 4, 11)
	P.on = TRUE
	var/obj/structure/fluid_tablet_press/press = new(locate(6, 13, 1))
	pipe_check(press.fluid_demand("calcium_carbonate") == 8 && press.fluid_demand("aspirin") == 32 && !press.fluid_demand("water"), "the press buffers carbonate and aspirin in tablet ratio and nothing else")
	for (var/i in 1 to 4)
		factory_fluids_step()
	pipe_check(pack_amount(press.reagents, "calcium_carbonate") == 8 && pack_amount(press.reagents, "aspirin") == 32, "pipes fill the press buffer")
	var/turf/T = press.loc
	pipe_check(!(locate(/obj/item/weapon/reagent_containers/pill) in T), "an unpowered press presses nothing")
	var/list/ppower = pipe_power(press, 7, 13)
	press.press_step()
	var/obj/item/weapon/reagent_containers/pill/tablet = locate() in T
	pipe_check(tablet && tablet.name == "aspirin tablet" && pack_amount(tablet.reagents, "calcium_carbonate") == 1 && pack_amount(tablet.reagents, "aspirin") == 4 && tablet.reagents.total_volume == 5, "a powered press presses an aspirin tablet of one carbonate and four aspirin")
	pipe_check(pack_amount(press.reagents, "calcium_carbonate") == 7 && pack_amount(press.reagents, "aspirin") == 28, "each tablet is paid from the buffer")
	for (var/i in 1 to 11)
		press.press_step()
	var/count = 0
	for (var/obj/item/weapon/reagent_containers/pill/p in T)
		count++
	press.press_step()
	var/after = 0
	for (var/obj/item/weapon/reagent_containers/pill/p in T)
		after++
	pipe_check(count == 8 && after == 8, "the press stops when its buffer runs out")
	press.reagents.add_reagent("calcium_carbonate", 8)
	press.reagents.add_reagent("aspirin", 32)
	for (var/i in 1 to 6)
		press.press_step()
	var/full = 0
	for (var/obj/item/I in T)
		full++
	pipe_check(full == 12 && pack_amount(press.reagents, "calcium_carbonate") == 4, "the press waits once twelve items lie on its tile")
	map.age = "1800"
	pipe_check(!press.can_press() && !press.fluid_demand("aspirin"), "an era before tablets presses and draws nothing")
	map.age = "1900"
	for (var/obj/item/I in T)
		qdel(I)
	for (var/obj/O in pipes + list(carb, asp, P, press) + power + ppower)
		if (!QDELETED(O))
			qdel(O)
	fluid_mark_dirty()

/proc/tier_checks()
	var/obj/structure/fluid_vessel/base = new(locate(15, 2, 1))
	var/obj/structure/fluid_vessel/fast/fast = new(locate(16, 2, 1))
	var/obj/structure/fluid_vessel/industrial/ind = new(locate(17, 2, 1))
	for (var/obj/structure/fluid_vessel/V in list(base, fast, ind))
		V.set_recipe("enginefuel")
	pipe_check(base.batch_count() == 20 && fast.batch_count() == 40 && ind.batch_count() == 100, "faster vessels hold bigger batches")
	pipe_check(base.react_time == 3 && fast.react_time == 1 && ind.react_time == 1 && fast.reagents.maximum_volume == 400 && ind.reagents.maximum_volume == 1000, "faster vessels react in one powered step")
	var/list/power = pipe_power(fast, 16, 3)
	fast.reagents.add_reagent("gasoline", 360)
	fast.reagents.add_reagent("pethanol", 40)
	fast.vessel_step()
	fast.vessel_step()
	pipe_check(fast.stage == 2 && pack_amount(fast.reagents, "enginefuel") == 400, "a fast vessel reacts its batch on the first powered step")
	for (var/obj/O in list(base, fast, ind) + power)
		qdel(O)
	fluid_mark_dirty()

/proc/packaging_save_checks()
	var/obj/structure/fluid_bottler/B = new(locate(15, 15, 1))
	B.filter_reagent = "water"
	var/obj/structure/fluid_tablet_press/press = new(locate(16, 15, 1))
	press.powered = TRUE
	pipe_check(("filter_reagent" in B.get_saved_vars()) && press.persistence_runtime_var("powered") && !("powered" in press.get_saved_vars()), "the bottler's reagent is saved; press power is not")
	fluid_presses -= press
	press.after_load()
	pipe_check(!press.powered && (press in fluid_presses), "a reloaded press starts unpowered and rejoins the press list")
	pipe_check(press.flags & NOREACT, "the press buffer is inert")
	qdel(B)
	qdel(press)

/proc/packaging_catalog_checks()
	var/list/gates = list("/obj/structure/fluid_bottler" = "automation", "/obj/structure/fluid_vessel/fast" = "automation", "/obj/structure/fluid_vessel/industrial" = "digital_computing", "/obj/structure/fluid_tablet_press" = "pharmacology")
	var/gated = 0
	for (var/path in gates)
		if (get_recipe_node_req(path) == gates[path])
			gated++
	pipe_check(gated == 4, "bottler and fast vessel unlock with Automation, the industrial vessel with Digital Computing and the press with Pharmacology")
	var/list/states = icon_states('icons/obj/chemical.dmi')
	pipe_check(("dispenser" in states) && ("mixer0b" in states), "the machines reuse existing sprites")
	var/list/found = list()
	for (var/line in splittext(file2text("config/crafting/material_recipes_global.txt"), "\n"))
		for (var/path in gates)
			if (findtext(line, "RECIPE: ") == 1 && findtext(line, ",[path],"))
				found |= path
	pipe_check(found.len == 4, "all four machines have global recipes")
