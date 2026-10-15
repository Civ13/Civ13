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

/mob/building_tester/New()
	return

/obj/item/weapon/roofbuilder/building_tester
	var/wait_mode = "complete"

/obj/item/weapon/roofbuilder/building_tester/building_confirm(mob/user, direction)
	return TRUE

/obj/item/weapon/roofbuilder/building_tester/building_wait(mob/user, duration, turf/start)
	switch(wait_mode)
		if ("cancel")
			return FALSE
		if ("drop")
			loc = start
		if ("dispose")
			qdel(src)
		if ("move")
			user.loc = locate(10,1,1)
	return TRUE

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
		sleep(60)
		building_assert(!R2.loc && !C2.loc, "unsupported upper slab collapses")
		var/obj/structure/mine_support/stone/stone = new(locate(8,8,1))
		for (var/level = 1 to 4)
			var/obj/roof/stone_roof = building_construct_roof(locate(8,8,level), /obj/roof/wood, null)
			building_assert(stone_roof, "stone supports storey [level]")
			if (level < 4)
				new /obj/structure/mine_support/stone(locate(8,8,level + 1))
		var/obj/structure/mine_support/stone/concrete/high = new(locate(8,8,5))
		building_assert(!building_supported_height(get_turf(high)), "strong upper pillar cannot bypass weaker foundation")
		building_assert(stone.building_support_tier() == 4 && high.building_support_tier() == 6, "stone and concrete tiers")
		for (var/level = 1 to 4)
			new /obj/structure/mine_support/stone/concrete(locate(8,8,level))
		for (var/level = 5 to 6)
			var/obj/roof/concrete_supported = building_construct_roof(locate(8,8,level), /obj/roof/concrete, null)
			building_assert(concrete_supported, "concrete supports storey [level]")
			new /obj/structure/mine_support/stone/concrete(locate(8,8,level + 1))
		building_assert(!building_supported_height(locate(8,8,7)), "concrete height limit")
		var/obj/structure/roof_support/reverse_support = new(locate(2,8,1))
		var/turf/reverse_turf = locate(2,8,2)
		building_assert(!building_floor_error(reverse_turf), "supported floor preflight")
		var/obj/covers/wood/reverse_floor = new(reverse_turf)
		building_assert(reverse_floor.building_finish_floor() && reverse_floor.building_roof(), "floor creates roof below")
		var/obj/item/weapon/covers/item = new(reverse_turf)
		building_assert(item.z == 2, "floor supports items")
		qdel(reverse_floor)
		building_assert(item.z == 1, "removed floor lets items fall")
		qdel(reverse_support)
		var/turf/build_site = locate(2,2,1)
		new /obj/structure/roof_support(build_site)
		var/mob/building_tester/U = new(locate(2,1,1))
		U.dir = NORTH
		for (var/mode in list("cancel", "drop", "dispose", "move"))
			U.loc = locate(2,1,1)
			var/obj/item/weapon/roofbuilder/building_tester/builder = new(U)
			builder.wait_mode = mode
			builder.attack_self(U)
			building_assert(!(locate(/obj/roof) in build_site), "interruption [mode] produces no slab")
			qdel(builder)
		U.loc = locate(2,1,1)
		var/obj/item/weapon/roofbuilder/building_tester/builder = new(U)
		builder.attack_self(U)
		building_assert((locate(/obj/roof) in build_site) && !builder.loc, "roof builder consumes item after successful slab")
		var/turf/wall/test_wall = new /turf/wall(locate(8,1,1), "stone")
		var/obj/roof/wall_roof = building_construct_roof(test_wall, /obj/roof/wood, null)
		building_assert(wall_roof, "turf wall supports slab")
		new /turf/floor/dirt(test_wall)
		persistence_save_in_progress = TRUE
		sleep(60)
		building_assert(wall_roof.loc, "collapse waits during save")
		persistence_save_in_progress = FALSE
		sleep(60)
		building_assert(!wall_roof.loc, "removed wall collapses after save")
		var/obj/structure/simple_door/test_door = new(locate(1,8,1), "wood")
		var/obj/roof/door_roof = building_construct_roof(get_turf(test_door), /obj/roof/wood, null)
		building_assert(door_roof, "door supports slab")
		qdel(test_door)
		sleep(60)
		building_assert(!door_roof.loc, "removed door collapses slab")
		text2file("PASS: linked building levels", "result.txt")
	catch (var/exception/E)
		world.log << "BUILDING exception: [E] at [E.file]:[E.line]"
		text2file("FAIL: [E.name]", "result.txt")
	shutdown()

