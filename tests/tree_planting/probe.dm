// Full production sources with normal startup disabled by run.py.
/world
	hub = ""
	hub_password = ""
	visibility = 0
	maxx = 8
	maxy = 4
	maxz = 1
	turf = /turf/floor/plating

/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE

/client/New()
	del(src)
	return

/obj/map_metadata/tree_tester/New()
	return

/mob/living/human/tree_tester/New()
	return

/mob/living/human/tree_tester/adaptStat(stat, amount)
	return

/proc/tree_check(condition, message)
	if (!condition)
		throw EXCEPTION(message)
	world.log << "TREE PASS: [message]"

/proc/tree_pulse(obj/structure/farming/plant/tree/P)
	P.last_growth_tick = world.time - 20
	return P.process_interval(2)

/proc/tree_fixture_setup()
	world.OpenPort("none")
	tree_check(!world.port, "fixture has no open port")
	if (config)
		config.webhook_can_fire = FALSE
	GLOB.all_observable_events = list()
	GLOB.moved_event = new /decl/observ/moved
	GLOB.dir_set_event = new /decl/observ/dir_set
	GLOB.name_set_event = new /decl/observ/name_set
	GLOB.stat_set_event = new /decl/observ/stat_set
	map = new /obj/map_metadata/tree_tester
	season = "SUMMER"
	var/area/A = get_area(locate(2,2,1))
	A.location = AREA_OUTSIDE
	A.climate = "temperate"
	// Production object dispatch, with the rest of normal startup disabled.
	processes.obj = new
	processes.obj.setup()

/proc/tree_dispatch()
	processes.obj.reset_current_list()
	processes.obj.run_time_tick_usage = world.tick_usage
	processes.obj.run_time_tick_usage_allowance = 100
	processes.obj.fire()
	tree_check(!length(processes.obj.current_list) && !length(processes.obj.exceptions), "production object dispatch finishes without exceptions")

/proc/tree_uproot_fixture(mob/living/human/H)
	var/turf/floor/dirt/ploughed/T = new(locate(6,3,1))
	var/list/rejected_tools = list(/obj/item/weapon/material/hatchet, /obj/item/weapon/attachment/bayonet, /obj/item/weapon/material/kitchen/utensil/knife, /obj/item/weapon/material/scythe, /obj/item/weapon/foldable_shovel, /obj/item/weapon/foldable_shovel/trench/etool, /obj/item/weapon/material/pickaxe, /obj/item/weapon/material/kitchen/utensil/spoon, /obj/item/weapon/material/part/shovel, /obj/item/weapon/clay/mold/shovel)
	for (var/test_stage in list(1, 11))
		for (var/tool_path in rejected_tools)
			var/obj/structure/farming/plant/tree/P = new(T)
			P.stage = test_stage
			P.water = 42
			P.growth_time_left = 277
			var/obj/item/weapon/W = new tool_path(H)
			P.attackby(W, H)
			tree_check(P && P.loc == T && !P.gc_destroyed && P.stage == test_stage && P.water == 42 && P.growth_time_left == 277 && (P in processing_objects), "nonshovel tool preserves seedling state")
			qdel(P)
			qdel(W)
		for (var/shovel_path in typesof(/obj/item/weapon/material/shovel))
			var/obj/structure/farming/plant/tree/seedling = new(T)
			seedling.stage = test_stage
			var/obj/item/weapon/shovel = new shovel_path(H)
			seedling.attackby(shovel, H)
			tree_check((!seedling || (seedling.gc_destroyed && !seedling.loc)) && !(seedling in processing_objects) && !(locate(/obj/structure/farming/plant/tree) in T), "shovel uprooting retires tree processing")
			tree_check(!(locate(/obj/item/stack/material/wood) in T) && !(locate(/obj/item/stack/material/wood) in H) && !(locate(/obj/item/stack/farming/seeds) in T) && !(locate(/obj/item/stack/farming/seeds) in H) && !(locate(/obj/structure/wild/tree/live_tree) in T), "uprooting returns no wood or seeds")
			qdel(shovel)

/proc/tree_fixture()
	tree_fixture_setup()
	var/turf/floor/dirt/ploughed/T = new(locate(2,2,1))
	T.soil_nutrition = 150
	var/area/A = get_area(T)
	A.location = AREA_OUTSIDE
	A.climate = "temperate"
	new /turf/floor/beach/water(locate(3,2,1))
	var/mob/living/human/H = new /mob/living/human/tree_tester(locate(1,2,1))
	tree_uproot_fixture(H)
	var/obj/item/stack/farming/seeds/tree/S = new(H, 3)
	T.attackby(S, H)
	var/obj/structure/farming/plant/tree/P = locate() in T
	tree_check(P && S.amount == 2, "planting creates seedling and spends exactly one seed")
	T.attackby(S, H)
	tree_check(S.amount == 2, "occupied plot does not spend a seed")
	tree_check(P.water == 80 && P.growth_time_left == 600, "constructor initializes full water and one stage")
	P.stage = 3
	P.water = 42
	P.plant_nutrition = 87
	P.growth_time_left = 277
	var/obj/structure/plant_pot/blocker = new(T)
	tree_pulse(P)
	tree_check(P.stage == 3 && P.growth_time_left == 277, "late dense obstruction pauses growth")
	qdel(blocker)
	A.location = AREA_INSIDE
	tree_pulse(P)
	tree_check(P.growth_time_left == 277, "indoor plot pauses growth")
	A.location = AREA_OUTSIDE
	var/savefile/F = new("tree.sav")
	F["/format_version"] << 2
	map_storage.clear_bookkeeping()
	map_storage.saving_z = 1
	var/id = map_storage.BuildVarDirectory(F, P, 1)
	tree_check(id, "production serializer builds tree entry")
	F.cd = map_storage.entry_path(F, id)
	tree_check(!("last_growth_tick" in F.dir), "runtime clock is absent on disk")
	F.Flush()
	F = null
	qdel(P)
	F = new("tree.sav")
	map_storage.clear_bookkeeping()
	P = map_storage.Load_Entry(F, id, starting_loc = T)
	P.after_load()
	P.after_load()
	tree_check(P.stage == 3 && P.water == 42 && P.plant_nutrition == 87 && P.growth_time_left == 277, "disk round trip preserves scalar growth state")
	var/membership = 0
	for (var/obj/O in processing_objects)
		if (O == P)
			membership++
	tree_check(membership == 1, "constructor and repeated after_load register once")
	P.process_interval(2)
	tree_check(P.growth_time_left == 277, "reload receives no old process time")
	tree_pulse(P)
	tree_check(P.growth_time_left == 257, "partial stage resumes from saved duration")
	P.growth_time_left = 1
	season = "WINTER"
	tree_pulse(P)
	tree_check(P.stage == 3 && P.water == 80, "temperate winter pauses stages while existing irrigation waters tree")
	season = "SUMMER"
	P.stage = 6
	P.growth_time_left = 1
	tree_check(tree_pulse(P) == PROCESS_KILL, "last stage retires processing")
	var/obj/structure/wild/tree/live_tree/mature = locate() in T
	tree_check(mature && !(P in processing_objects), "maturation makes existing tree and removes seedling registration")
	mature.health = 0
	mature.try_destroy()
	var/obj/item/stack/material/wood/logs = locate() in T
	tree_check(logs && logs.amount == 7, "mature tree uses existing seven-log destruction")
	var/turf/floor/dirt/ploughed/D = new(locate(7,2,1))
	D.soil_nutrition = 150
	var/obj/structure/farming/plant/tree/dry = new(D)
	dry.stage = 6
	dry.water = 1
	dry.growth_time_left = 1
	tree_check(tree_pulse(dry) == PROCESS_KILL && dry.stage == 11, "drought kills seedling before maturation")
	qdel(dry)
	A.location = AREA_INSIDE
	var/before = S.amount
	T.attackby(S, H)
	tree_check(S.amount == before && !(locate(/obj/structure/farming/plant/tree) in T), "indoor planting rejected before seed debit")
	text2file("PASS: tree planting production paths and disk round trip", "result.txt")

/proc/tree_restart_writer()
	tree_fixture_setup()
	var/turf/floor/dirt/ploughed/T = new(locate(2,2,1))
	var/obj/structure/farming/plant/tree/P = new(T)
	P.stage = 4
	P.water = 42
	P.plant_nutrition = 87
	P.growth_time_left = 277
	P.last_growth_tick = 123456
	map_storage.clear_bookkeeping()
	map_storage.saving_z = 1
	var/savefile/F = new("tree-restart.sav")
	F["/format_version"] << 2
	var/id = map_storage.BuildVarDirectory(F, P, 1)
	tree_check(id, "fresh-process writer exports tree")
	F.cd = map_storage.entry_path(F, id)
	tree_check(!("last_growth_tick" in F.dir), "fresh-process writer omits runtime clock")
	// Reproduce a historical runtime field without changing the durable payload.
	F["last_growth_tick"] << list("kind" = "value", "value" = 123456)
	F.Flush()
	text2file("[id]", "tree-restart-entry.txt")
	text2file("PASS: tree restart writer", "result.txt")

/proc/tree_restart_reader()
	tree_fixture_setup()
	var/turf/floor/dirt/ploughed/T = new(locate(2,2,1))
	T.soil_nutrition = 150
	new /turf/floor/beach/water(locate(3,2,1))
	var/savefile/F = new("tree-restart.sav")
	var/id = trim(file2text("tree-restart-entry.txt"))
	map_storage.clear_bookkeeping()
	var/obj/structure/farming/plant/tree/P = map_storage.Load_Entry(F, id, starting_loc = T)
	tree_check(P && P.stage == 4 && P.water == 42 && P.plant_nutrition == 87 && P.growth_time_left == 277, "fresh process restores scalar tree growth")
	P.after_load()
	P.after_load()
	tree_check(P.last_growth_tick == world.time && P.last_growth_tick != 123456, "legacy process clock ignored and reanchored")
	var/membership = 0
	for (var/obj/O in processing_objects)
		if (O == P)
			membership++
	tree_check(membership == 1, "fresh process has one tree registration")
	tree_dispatch()
	tree_check(P.stage == 4 && P.growth_time_left == 277 && P.water == 42, "first object service does not reset or charge growth")
	sleep(2)
	var/elapsed = world.time - P.last_growth_tick
	tree_dispatch()
	tree_check(P.growth_time_left == 277 - min(20, elapsed) && P.stage == 4, "production dispatch resumes saved partial duration")
	var/time_left = P.growth_time_left
	tree_dispatch()
	tree_check(P.growth_time_left == time_left, "same-tick dispatch cannot double-charge tree")
	var/datum/persistence_world_operation/operation = new
	operation.kind = "load"
	persistence_active_operation = operation
	P.growth_time_left = 1
	P.last_growth_tick = world.time - 20
	tree_dispatch()
	tree_check(P.stage == 4 && P.growth_time_left == 1 && P.water == 42, "active load blocks native tree service")
	operation.kind = "save"
	tree_dispatch()
	tree_check(P.stage == 4 && P.growth_time_left == 1, "active save blocks native tree service")
	persistence_active_operation = null
	qdel(operation)
	// Accelerate only fixture-owned stage durations; production code is verbatim.
	for (var/expected_stage = 5, expected_stage <= 6, expected_stage++)
		P.growth_time_left = 1
		P.last_growth_tick = world.time - 20
		tree_dispatch()
		tree_check(P.stage == expected_stage && P.growth_time_left == 600, "restored seedling advances one native stage")
	P.growth_time_left = 1
	P.last_growth_tick = world.time - 20
	tree_dispatch()
	var/obj/structure/wild/tree/live_tree/mature = locate() in T
	tree_check(mature && !(P in processing_objects) && !(locate(/obj/structure/farming/plant/tree) in T), "fresh-process restored tree matures once through production dispatch")
	var/tree_count = 0
	for (var/obj/structure/wild/tree/live_tree/tree in T)
		tree_count++
	tree_check(tree_count == 1, "one mature tree after restart")
	tree_dispatch()
	tree_check((locate(/obj/structure/wild/tree/live_tree) in T) == mature, "later object pass preserves mature tree identity")
	text2file("PASS: tree restart reader and production object dispatch", "result.txt")

/world/New()
	try
		switch (world.params["tree_phase"])
			if ("writer")
				tree_restart_writer()
			if ("reader")
				tree_restart_reader()
			else
				tree_fixture()
	catch(var/exception/tree_error)
		text2file("FAIL: [tree_error]", "result.txt")
	del(world)
	sleep(1)

/world/Error(exception/e, datum/e_src)
	text2file("FAIL: runtime [e]", "result.txt")
	del(world)
	sleep(1)
