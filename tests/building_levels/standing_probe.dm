// ISOLATED TEST PROBE. Exercises building_standing_try() and its watch loop
// on a fixture world: the level is added only after the startup import settles.
/world
	maxx = 10
	maxy = 10
	maxz = 1
	turf = /turf/floor/dirt
	area = /area/caribbean
	hub = ""
	hub_password = ""

/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/obj/map_metadata/standing_level_tester
	building_levels = 1
	building_level_standing = TRUE

/obj/map_metadata/standing_level_tester/New()
	return

/obj/map_metadata/standing_level_off
	building_levels = 1

/obj/map_metadata/standing_level_off/New()
	return

/proc/standing_assert(condition, message)
	if (!condition)
		throw EXCEPTION(message)

/world/New()
	OpenPort("none")
	try
		world_z_budget = new /datum/world_z_budget/fixture_admission
		var/base = world.maxz
		map = new /obj/map_metadata/standing_level_off
		ticker = new /datum/controller/gameticker
		ticker.current_state = GAME_STATE_PLAYING
		standing_assert(building_standing_try() && world.maxz == base, "a map without the flag gets no level")
		map = new /obj/map_metadata/standing_level_tester
		ticker = null
		standing_assert(!building_standing_try() && world.maxz == base, "no ticker yet: wait")
		ticker = new /datum/controller/gameticker
		standing_assert(!building_standing_try() && world.maxz == base, "pregame fresh world: wait")
		persistence_startup_recovery_status = "pending"
		ticker.current_state = GAME_STATE_PLAYING
		standing_assert(!building_standing_try() && world.maxz == base, "startup import pending: wait")
		persistence_startup_recovery_status = "unresolved"
		standing_assert(!building_standing_try() && world.maxz == base, "failed import: leave the level count alone")
		persistence_startup_recovery_status = null
		persistence_save_in_progress = TRUE
		standing_assert(!building_standing_try() && world.maxz == base, "save in progress: wait")
		persistence_save_in_progress = FALSE
		ticker.current_state = GAME_STATE_PREGAME
		persistence_startup_recovery_status = "pending"
		building_standing_watch_loop()
		sleep(20)
		standing_assert(world.maxz == base && building_standing_watch, "watch waits through the import")
		persistence_startup_recovery_status = null
		map_storage.round_restored = TRUE
		sleep(70)
		standing_assert(world.maxz == base + 1 && !building_standing_watch, "watch adds the level once the restore settles")
		standing_assert(istype(locate(1, 1, base + 1), /turf/sky/building), "the standing level is open air")
		standing_assert(multiz_top_z() == base, "the surface stays the top ground level under the open air")
		standing_assert(building_standing_try() && world.maxz == base + 1, "a present level is never added twice")
		text2file("PASS: standing building level", "result.txt")
	catch (var/exception/E)
		world.log << "STANDING exception: [E] at [E.file]:[E.line]"
		text2file("FAIL: [E.name]", "result.txt")
	shutdown()
