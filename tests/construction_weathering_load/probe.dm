// Production seasonal weathering, warnings, repair and whole-world save/load
// on a synthetic 6x4x1 world. Wear and unpaid season debt must survive a load.
/obj/map_metadata/weathering_fixture/New()
	return
/proc/weathering_check(condition, message)
	if(!condition)
		text2file("FAIL: [message]", "weathering_result.txt")
		del(world)
		sleep(1)
/world
	hub = ""
	hub_password = ""
	maxx = 6
	maxy = 4
	maxz = 1
	fps = 20
	turf = /turf
/world/Topic(T, addr, master, key)
	return "Weathering fixture has no remote operations."
/world/Error(exception/e, datum/e_src)
	world.log << "Runtime error: [e] on [e.file]:[e.line]"
	text2file("FAIL: runtime [e] on [e.file]:[e.line]", "weathering_result.txt")
	del(world)
	sleep(1)
/proc/weathering_season()
	var/list/cycle = list("SPRING", "SUMMER", "FALL", "WINTER")
	season = cycle[(cycle.Find(season) % 4) + 1]
	map.record_construction_season_change(TRUE)
/proc/weathering_service(obj/O)
	O.check_seasonal_construction()
	return O
/world/New()
	generate_gameid()
	if(config)
		config.webhook_can_fire = FALSE
		config.ToRban = FALSE
	GLOB.all_observable_events = list()
	GLOB.moved_event = new /decl/observ/moved
	GLOB.dir_set_event = new /decl/observ/dir_set
	GLOB.name_set_event = new /decl/observ/name_set
	GLOB.stat_set_event = new /decl/observ/stat_set
	map = new /obj/map_metadata/weathering_fixture
	map.ID = MAP_NOMADS_CONTINENTAL
	map.persistence = TRUE
	season = "SUMMER"
	var/area/caribbean/nomads/semiarid/base = locate(/area/caribbean/nomads/semiarid)
	if(!base) base = new /area/caribbean/nomads/semiarid
	for(var/turf/T in world)
		ChangeArea(T, base)
		T.ChangeTurf(/turf/floor/dirt, FALSE, FALSE)
	var/obj/covers/straw = new /obj/covers/straw_wall(locate(2,2,1))
	var/obj/roof/thatch = new /obj/roof/thatch(locate(2,3,1))
	var/obj/covers/wood = new /obj/covers/wood_wall(locate(4,2,1))
	sleep(60)
	weathering_check(thatch && !thatch.gcDestroyed && thatch.seasonal_construction_index, "thatch roof stands next to its straw wall")
	weathering_check(straw.seasonal_construction_lifetime() == 64 && wood.seasonal_construction_lifetime() == 256, "lifetimes count years ([straw.seasonal_construction_lifetime()], [wood.seasonal_construction_lifetime()])")
	weathering_season()
	weathering_season()
	for(var/obj/O in list(straw, thatch, wood))
		weathering_service(O)
	weathering_check(straw.health == 75 * 62 / 64 && thatch.health == 100 * 62 / 64 && wood.health == 300 * 254 / 256, "two seasons of wear ([straw.health], [thatch.health], [wood.health])")
	weathering_check(straw.seasonal_construction_seasons_left() == 62, "straw has 62 seasons left ([straw.seasonal_construction_seasons_left()])")
	weathering_check(findtext(straw.seasonal_construction_condition(), "62 more seasons (15.5 years)"), "examine shows remaining time: [straw.seasonal_construction_condition()]")
	// A third season is left unserviced, so it is saved as debt.
	weathering_season()
	weathering_check(map_storage.Save_World(), "production whole-world export succeeds")
	weathering_check(map_storage.validate_world_save(), "production preflight accepts the save: [map_storage.last_error]")
	map_storage.ClearMap()
	weathering_check(map_storage.Load_World(), "production whole-world import succeeds: [map_storage.last_error]")
	straw = locate(/obj/covers/straw_wall) in locate(2,2,1)
	thatch = locate(/obj/roof/thatch) in locate(2,3,1)
	wood = locate(/obj/covers/wood_wall) in locate(4,2,1)
	weathering_check(straw && thatch && wood, "weathering buildings are restored")
	weathering_check(straw.health == 75 * 62 / 64 && thatch.health == 100 * 62 / 64 && wood.health == 300 * 254 / 256, "wear is carried over ([straw.health], [thatch.health], [wood.health])")
	weathering_check(straw.seasonal_construction_due == 1 && thatch.seasonal_construction_due == 1 && wood.seasonal_construction_due == 1, "unpaid season is carried over ([straw.seasonal_construction_due], [thatch.seasonal_construction_due], [wood.seasonal_construction_due])")
	weathering_check(straw.seasonal_construction_index && thatch.seasonal_construction_index && wood.seasonal_construction_index, "restored buildings keep weathering")
	for(var/obj/O in list(straw, thatch, wood))
		weathering_service(O)
	weathering_check(straw.health == 75 * 61 / 64 && thatch.health == 100 * 61 / 64 && wood.health == 300 * 253 / 256 && !thatch.seasonal_construction_due, "carried-over season is charged once after load ([straw.health], [thatch.health], [wood.health])")
	weathering_season()
	weathering_service(straw)
	weathering_check(straw.health == 75 * 60 / 64, "seasons after the load keep counting ([straw.health])")
	// One season from the warning threshold, then into the last year.
	straw.health = 75 * 5 / 64
	weathering_check(findtext(straw.seasonal_construction_condition(), "Weathering:"), "five seasons left is not yet a warning: [straw.seasonal_construction_condition()]")
	weathering_season()
	weathering_service(straw)
	weathering_check(straw.seasonal_construction_seasons_left() == 4, "four seasons left ([straw.seasonal_construction_seasons_left()])")
	weathering_check(findtext(straw.seasonal_construction_condition(), "badly weathered and will fall apart within 4 seasons"), "last-year warning: [straw.seasonal_construction_condition()]")
	weathering_check(findtext(straw.seasonal_construction_condition(), "Repair it with"), "warning names the repair material: [straw.seasonal_construction_condition()]")
	// Repairs restore full health; the weathering rate is unchanged afterwards.
	makeDatumRefLists()
	var/mob/living/human/H = new(locate(2,1,1))
	var/obj/item/stack/material/wood/planks = new(H)
	planks.amount = 50
	straw.do_repair(H, planks, max(1, ceil((straw.maxhealth - straw.health) / straw.maxhealth * straw.buildstackamount)))
	weathering_check(straw.health == 75, "straw wall is repaired ([straw.health])")
	weathering_check(planks.amount == 42, "repair costs the missing share of the stack ([planks.amount])")
	var/obj/item/weapon/roofbuilder/leaves/roofing = new(H)
	weathering_check(thatch.repair_with(roofing, H) && thatch.health == 100, "thatch roof is repaired with thatch roofing ([thatch.health])")
	weathering_check(!roofing || roofing.gcDestroyed || roofing.loc != H, "roofing is used up")
	weathering_season()
	weathering_service(straw)
	weathering_check(straw.health == 75 * 63 / 64, "repaired wall weathers at its normal rate ([straw.health])")
	text2file("PASS: weathering wear and unpaid seasons survive save/load; warnings and repairs work", "weathering_result.txt")
	del(world)
