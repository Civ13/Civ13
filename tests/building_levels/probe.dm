/world
	maxx = 10
	maxy = 10
	maxz = 7
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
		// Support-tier tests use compiled planes; growth policy has its own fixture.
		map_storage.record_compiled_dimensions()
		for (var/turf/T in world)
			if (T.z > 1)
				new /turf/sky/building(T)
		var/turf/site = locate(4,4,1)
		var/site_error = building_roof_error(site)
		building_assert(site_error && findtext(site_error, "Nothing holds a roof up here") && findtext(site_error, "within 6 tiles"), "unsupported refusal says what is missing")
		var/obj/structure/roof_support/P = new(site)
		var/obj/roof/R = building_construct_roof(site, /obj/roof/wood, null)
		building_assert(world.maxz == 7 && R, "roof uses compiled upper level")
		var/obj/covers/C = R.building_floor()
		building_assert(C && C.building_roof() == R, "pair resolves both faces")
		building_assert(istype(locate(10,10,2), /turf/sky/building), "new level is open air")
		building_assert(!building_allocate_level(4), "nonadjacent allocation rejected")
		persistence_save_in_progress = TRUE
		building_assert(!building_allocate_level(8), "save excludes allocation")
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
		building_probe_settle()
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
		building_probe_settle()
		building_assert(wall_roof.loc, "collapse waits during save")
		persistence_save_in_progress = FALSE
		building_probe_settle()
		building_assert(!wall_roof.loc, "removed wall collapses after save")
		var/obj/structure/simple_door/test_door = new(locate(1,8,1), "wood")
		var/obj/roof/door_roof = building_construct_roof(get_turf(test_door), /obj/roof/wood, null)
		building_assert(door_roof, "door supports slab")
		qdel(test_door)
		building_probe_settle()
		building_assert(!door_roof.loc, "removed door collapses slab")
		var/obj/covers/wood_wall/test_cover = new(locate(5,8,1))
		var/obj/roof/cover_roof = building_construct_roof(get_turf(test_cover), /obj/roof/wood, null)
		building_assert(cover_roof, "cover wall supports slab")
		building_probe_settle()
		building_assert(cover_roof.loc, "cover slab survives initial support check")
		qdel(test_cover)
		building_probe_settle()
		building_assert(!cover_roof.loc, "removed cover wall collapses slab")
		// A window frame in a wall line holds a roof like the wall beside it.
		var/obj/structure/window_frame/test_window = new(locate(5,8,1))
		var/obj/roof/window_roof = building_construct_roof(get_turf(test_window), /obj/roof/wood, null)
		building_assert(window_roof, "window frame supports slab")
		building_probe_settle()
		building_assert(window_roof.loc, "window slab survives the standing support check")
		qdel(test_window)
		building_probe_settle()
		building_assert(!window_roof.loc, "removed window collapses slab")
		// Soft ground carries two storeys; a stone floor under the support is a foundation.
		var/turf/soft = new /turf/floor/dirt(locate(9,3,1))
		new /obj/structure/mine_support/stone(soft)
		for (var/level = 1 to 2)
			building_assert(building_construct_roof(locate(9,3,level), /obj/roof/wood, null), "soft ground carries storey [level]")
			new /obj/structure/mine_support/stone(locate(9,3,level + 1))
		var/soft_error = building_roof_error(locate(9,3,3))
		building_assert(soft_error, "soft ground carries two storeys")
		building_assert(findtext(soft_error, "third storey") && findtext(soft_error, "Lay that floor first"), "an unfounded third storey names the foundation rule")
		var/obj/covers/foundation = new /obj/covers/cobblestone(locate(9,3,1))
		building_assert(!building_roof_error(locate(9,3,3)), "a stone floor under the ground support is a foundation")
		// Taking the foundation away again rechecks every storey above it: the
		// third storey falls, the two that soft ground carries stay.
		var/obj/roof/founded_third = building_construct_roof(locate(9,3,3), /obj/roof/wood, null)
		building_assert(founded_third, "founded third storey built")
		building_probe_settle()
		qdel(foundation)
		building_probe_settle()
		building_assert(QDELETED(founded_third) && (locate(/obj/roof) in locate(9,3,1)) && (locate(/obj/roof) in locate(9,3,2)), "removing a foundation rechecks the storeys above it")
		// From the second storey up: no slab on one distant pillar, and supports stand over supports.
		new /obj/structure/roof_support(locate(3,5,1))
		for (var/x = 3 to 5)
			building_assert(building_construct_roof(locate(x,5,1), /obj/roof/wood, null), "ground-floor roof keeps the one-support rule at [x]")
		new /obj/structure/roof_support(locate(3,5,2))
		var/span_error = building_roof_error(locate(5,5,2))
		building_assert(span_error && findtext(span_error, "distant"), "one distant pillar cannot hold an upper storey")
		new /obj/structure/roof_support(locate(5,5,2))
		var/column_error = building_roof_error(locate(5,5,2))
		building_assert(column_error && findtext(column_error, "beneath"), "upper support needs a support beneath it")
		new /obj/structure/roof_support(locate(5,5,1))
		building_assert(building_construct_roof(locate(5,5,2), /obj/roof/wood, null), "designed second storey allowed")
		// A wood floor laid over an upper floor takes over its ceiling link.
		var/obj/roof/plank_roof = locate(/obj/roof) in locate(4,5,1)
		var/obj/covers/plank_upper = plank_roof && plank_roof.building_floor()
		building_assert(plank_upper && plank_upper.is_subfloor(), "upper floor is a subfloor")
		building_assert(tile_subfloor_for(get_turf(plank_upper), /obj/covers/wood) == plank_upper && !tile_build_refusal(get_turf(plank_upper), /obj/covers/wood), "wood floor may go over an upper floor")
		var/obj/covers/wood/plank_floor = new(get_turf(plank_upper))
		building_assert(plank_floor.replace_subfloor(plank_upper), "upper floor replaced")
		building_assert(QDELETED(plank_upper) && !QDELETED(plank_roof) && plank_roof.building_floor() == plank_floor && plank_floor.building_roof() == plank_roof, "ceiling stays linked to the wood floor")
		// Taking up a finished upper floor puts the plain upper floor back and
		// keeps the ceiling; only removing that plain floor opens the hole.
		var/obj/covers/plank_sub = plank_floor.revert_to_subfloor()
		building_assert(plank_sub && QDELETED(plank_floor) && plank_sub.is_subfloor() && !QDELETED(plank_roof) && plank_roof.building_floor() == plank_sub && plank_sub.building_roof() == plank_roof, "taking up a finished upper floor keeps the ceiling")
		building_assert(plank_sub.building_slab_face() && plank_roof.building_slab_face(), "both slab faces know they hold a storey")
		// Beds upstairs: an upper floor holds a sleeper, bare open air does not.
		building_assert(persistence_character_floor_usable(get_turf(plank_sub)), "an upper floor holds a sleeper")
		building_assert(!persistence_character_floor_usable(locate(1,1,2)), "open air holds no sleeper")
		qdel(plank_sub)
		building_assert(QDELETED(plank_roof), "removing the plain upper floor removes the ceiling")
		// Concrete walls cast from cement bricks carry six storeys, like concrete pillars.
		var/obj/covers/cement_wall/cast = new(locate(10,1,1))
		building_assert(cast.building_support_tier() == 6, "concrete wall tier")
		for (var/level = 1 to 6)
			building_assert(building_construct_roof(locate(10,1,level), /obj/roof/concrete, null), "concrete walls carry storey [level]")
			new /obj/covers/cement_wall(locate(10,1,level + 1))
		building_assert(building_roof_error(locate(10,1,7)), "concrete walls stop at six storeys")
		// A finished floor laid over a concrete slab comes back up to a slab
		// floor that does not burn.
		var/obj/roof/cast_roof = locate(/obj/roof) in locate(10,1,1)
		var/obj/covers/cast_upper = cast_roof.building_floor()
		var/obj/covers/wood/cast_wood = new(get_turf(cast_upper))
		building_assert(cast_wood.replace_subfloor(cast_upper), "wood floor over a concrete slab")
		var/obj/covers/cast_back = cast_wood.revert_to_subfloor()
		building_assert(cast_back && !cast_back.flammable && cast_back.material == "Stone" && cast_roof.building_floor() == cast_back, "a stone slab's floor stays stone when a finish comes up")
		// A roof with nothing above it (built before the level could take a
		// floor, or mapped) takes a floor from above instead of refusing.
		new /obj/structure/roof_support(locate(7,3,1))
		var/obj/roof/lone_roof = new /obj/roof/wood(locate(7,3,1))
		var/turf/lone_top = locate(7,3,2)
		building_assert(!building_floor_error(lone_top), "an unpaired supported roof takes a floor above it")
		var/obj/covers/repairedfloor/lone_floor = new(lone_top)
		building_assert(lone_floor.building_finish_floor() && lone_floor.building_roof() == lone_roof && lone_roof.building_floor() == lone_floor, "the floor links the existing roof")
		building_assert(findtext(building_floor_error(lone_top), "already a floor"), "a second floor is refused by name")
		// Fire burns a finished floor upstairs down to the slab, not through it.
		var/obj/covers/wood/lone_wood = new(lone_top)
		building_assert(lone_wood.replace_subfloor(lone_floor), "wood floor over the linked floor")
		for (var/i in 1 to 400)
			if (QDELETED(lone_wood))
				break
			lone_wood.fire_act(1000)
		building_assert(QDELETED(lone_wood) && !QDELETED(lone_roof) && lone_roof.building_floor() && lone_roof.building_floor().is_subfloor(), "a burned finished floor leaves the slab")
		// A ground pillar under a two-storey column holds up both storeys; with
		// a second ground pillar beside it, it holds nothing and may come down.
		var/obj/structure/roof_support/base_pillar = new(locate(1,10,1))
		building_assert(building_construct_roof(locate(1,10,1), /obj/roof/wood, null), "dismantle column storey 1")
		new /obj/structure/roof_support(locate(1,10,2))
		building_assert(building_construct_roof(locate(1,10,2), /obj/roof/wood, null), "dismantle column storey 2")
		building_assert(building_load_held(base_pillar) == 2 && !base_pillar.pillar_dismantle_check(null), "a ground pillar holding two storeys will not come down")
		building_assert(base_pillar.loc == locate(1,10,1), "the load check puts the pillar back")
		new /obj/structure/roof_support(locate(2,10,1))
		building_assert(building_load_held(base_pillar) == 0, "with a second ground pillar it holds nothing")
		text2file("PASS: linked building levels", "result.txt")
	catch (var/exception/E)
		world.log << "BUILDING exception: [E] at [E.file]:[E.line]"
		text2file("FAIL: [E.name]", "result.txt")
	shutdown()

// Collapses wait in the timed queue (building_collapse.dm), which this fixture's
// timer loop does not run: drive the queue by hand until it is empty (at least
// 1 s, at most 8 s).
/proc/building_probe_settle()
	for (var/i in 1 to 80)
		sleep(1)
		building_collapse_pass()
		if (i >= 10 && !building_collapse_pending())
			return
