/world
	maxx = 10
	maxy = 10
	maxz = 1
	turf = /turf/floor/plating
	area = /area/caribbean
	hub = ""
	hub_password = ""

/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE

/obj/map_metadata/building_tester/New()
	return

/proc/building_assert(condition, message)
	if (!condition)
		throw EXCEPTION(message)
	world.log << "BUILDING PASS: [message]"

/world/New()
	OpenPort("none")
	sleep(1)
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		GLOB.stat_set_event = new
		GLOB.name_set_event = new
		map = new /obj/map_metadata/building_tester
		var/turf/site = locate(4,4,1)
		building_assert(building_roof_error(site), "unsupported construction rejected")
		var/obj/structure/roof_support/P = new(site)
		var/obj/roof/R = building_construct_roof(site, /obj/roof/wood, null)
		building_assert(world.maxz == 2 && R, "roof allocates upper level")
		var/obj/covers/C = R.building_floor()
		building_assert(C && C.building_roof() == R, "pair resolves both faces")
		building_assert(istype(locate(10,10,2), /turf/sky/building), "new level is open air")
		building_assert(!building_allocate_level(4), "nonadjacent allocation rejected")
		persistence_save_in_progress = TRUE
		building_assert(!building_allocate_level(3), "save excludes allocation")
		persistence_save_in_progress = FALSE
		var/obj/structure/roof_support/upper = new(get_turf(C))
		var/obj/roof/R2 = building_construct_roof(get_turf(C), /obj/roof/wood, null)
		building_assert(R2, "wood second storey allowed")
		var/obj/covers/C2 = R2.building_floor()
		var/obj/structure/roof_support/top = new(get_turf(C2))
		building_assert(!building_supported_height(get_turf(C2)), "wood height limit")
		var/savefile/F = new("slab.sav")
		F["/format_version"] << 2
		map_storage.clear_bookkeeping()
		map_storage.saving_z = 1
		var/roof_id = map_storage.BuildVarDirectory(F, R, 1)
		F.Flush()
		F = new("floor.sav")
		F["/format_version"] << 2
		map_storage.clear_bookkeeping()
		map_storage.saving_z = 2
		var/floor_id = map_storage.BuildVarDirectory(F, C, 1)
		F.Flush()
		F = null
		qdel(R)
		building_assert(!C.loc, "roof removal removes floor")
		F = new("slab.sav")
		map_storage.clear_bookkeeping()
		R = map_storage.Load_Entry(F, roof_id, starting_loc = site)
		F = new("floor.sav")
		map_storage.clear_bookkeeping()
		C = map_storage.Load_Entry(F, floor_id, starting_loc = locate(4,4,2))
		building_assert(R && C && R.building_floor() == C && C.building_roof() == R, "disk restored slab links")
		building_assert(R.persistence_runtime_var("roof_overlay"), "runtime image excluded")
		qdel(top)
		qdel(upper)
		qdel(C)
		building_assert(!R.loc && !C.loc, "floor removal removes roof")
		qdel(P)
		text2file("PASS: linked building levels", "result.txt")
	catch (var/exception/E)
		world.log << "BUILDING exception: [E] at [E.file]:[E.line]"
		text2file("FAIL: [E.name]", "result.txt")
	shutdown()

