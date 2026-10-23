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

/proc/tree_fixture()
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
	var/turf/floor/dirt/ploughed/T = new(locate(2,2,1))
	T.soil_nutrition = 150
	var/area/A = get_area(T)
	A.location = AREA_OUTSIDE
	A.climate = "temperate"
	new /turf/floor/beach/water(locate(3,2,1))
	var/mob/living/human/H = new /mob/living/human/tree_tester(locate(1,2,1))
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
	del(blocker)
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
	del(P)
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
	del(dry)
	A.location = AREA_INSIDE
	var/before = S.amount
	T.attackby(S, H)
	tree_check(S.amount == before && !(locate(/obj/structure/farming/plant/tree) in T), "indoor planting rejected before seed debit")
	text2file("PASS: tree planting production paths and disk round trip", "result.txt")

/world/New()
	try
		tree_fixture()
	catch(var/exception/tree_error)
		text2file("FAIL: [tree_error]", "result.txt")
	del(world)
	sleep(1)

/world/Error(exception/e, datum/e_src)
	text2file("FAIL: runtime [e]", "result.txt")
	del(world)
	sleep(1)
