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
// Health of the 75-point straw wall after n seasons under the eaves of its roof.
#define STRAW(n) (75 - 75 * (n) * 0.75 / 64)
/proc/weathering_near(a, b)
	return abs(a - b) < 0.001
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
	weathering_check(weathering_near(straw.health, STRAW(2)) && thatch.health == 100 * 62 / 64 && wood.health == 300 * 254 / 256, "two seasons of wear ([straw.health], [thatch.health], [wood.health])")
	// The roof beside it shelters the straw wall: 62.5 seasons of health at three quarters of the rate.
	weathering_check(straw.seasonal_construction_rate() == 0.75 && wood.seasonal_construction_rate() == 1, "a roofed wall weathers slower ([straw.seasonal_construction_rate()], [wood.seasonal_construction_rate()])")
	weathering_check(straw.seasonal_construction_seasons_left() == 84, "straw has 84 seasons left ([straw.seasonal_construction_seasons_left()])")
	weathering_check(findtext(straw.seasonal_construction_condition(), "84 more seasons (21 years)"), "examine shows remaining time: [straw.seasonal_construction_condition()]")
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
	weathering_check(weathering_near(straw.health, STRAW(2)) && thatch.health == 100 * 62 / 64 && wood.health == 300 * 254 / 256, "wear is carried over ([straw.health], [thatch.health], [wood.health])")
	weathering_check(straw.seasonal_construction_due == 1 && thatch.seasonal_construction_due == 1 && wood.seasonal_construction_due == 1, "unpaid season is carried over ([straw.seasonal_construction_due], [thatch.seasonal_construction_due], [wood.seasonal_construction_due])")
	weathering_check(straw.seasonal_construction_index && thatch.seasonal_construction_index && wood.seasonal_construction_index, "restored buildings keep weathering")
	for(var/obj/O in list(straw, thatch, wood))
		weathering_service(O)
	weathering_check(weathering_near(straw.health, STRAW(3)) && thatch.health == 100 * 61 / 64 && wood.health == 300 * 253 / 256 && !thatch.seasonal_construction_due, "carried-over season is charged once after load ([straw.health], [thatch.health], [wood.health])")
	weathering_season()
	weathering_service(straw)
	weathering_check(weathering_near(straw.health, STRAW(4)), "seasons after the load keep counting ([straw.health])")
	// One season from the warning threshold, then into the last year.
	straw.health = 75 - STRAW(5)
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
	weathering_check(weathering_near(straw.health, STRAW(1)), "repaired wall weathers at its normal rate ([straw.health])")
	// Cracks follow health; a wall on a stone floor under a roof weathers at half the rate.
	wood.health = 140
	weathering_season()
	weathering_service(wood)
	weathering_check(wood.cracked == 1, "a half-worn wall shows the first cracks ([wood.cracked])")
	new /obj/covers/cobblestone(locate(1,4,1))
	var/obj/covers/founded = new /obj/covers/straw_wall(locate(1,4,1))
	weathering_check(founded.seasonal_construction_rate() == 0.5, "a founded wall under a roof weathers at half the rate ([founded.seasonal_construction_rate()])")
	weathering_check(straw.persistence_runtime_var("seasonal_construction_paced_at") && straw.persistence_runtime_var("seasonal_construction_ruin_told") && thatch.persistence_runtime_var("sagging"), "pacing, ruin and sag state is never saved")
	// A backlog of seasons is charged one warning band per season step, never all at once.
	var/obj/covers/late = new /obj/covers/wood_wall(locate(4,4,1))
	for(var/i in 1 to 300)
		weathering_season()
	weathering_service(late)
	weathering_service(late)
	weathering_check(late && !late.gcDestroyed && weathering_near(late.seasonal_construction_reserve(), 4) && late.cracked == 3, "a backlog stops at the last-year warning ([late ? late.health : "gone"])")
	weathering_check(late.seasonal_construction_seasons_left() == 1, "held debt still leaves the season it is in ([late.seasonal_construction_seasons_left()])")
	weathering_season()
	weathering_service(late)
	weathering_service(late)
	weathering_check(late && !late.gcDestroyed && weathering_near(late.seasonal_construction_reserve(), 1), "then at the last-season warning ([late ? late.health : "gone"])")
	weathering_season()
	weathering_service(late)
	weathering_service(late)
	weathering_check(late && !late.gcDestroyed && late.seasonal_construction_ruined(), "then stands as a ruin ([late ? late.health : "gone"])")
	weathering_season()
	weathering_service(late)
	weathering_check(!late || late.gcDestroyed, "and only then crumbles away")
	Master.start_timer_loop() // The sag warning runs on a timer.
	// A wall in its last season becomes a ruin: it stands, holds nothing up and its roofs sag first.
	var/obj/covers/worn = new /obj/covers/straw_wall(locate(6,2,1))
	var/obj/roof/doomed = new /obj/roof/thatch(locate(6,3,1))
	var/obj/roof/saved = new /obj/roof/thatch(locate(6,1,1))
	sleep(60)
	weathering_check(doomed && !doomed.gcDestroyed && saved && !saved.gcDestroyed && doomed.is_supported() && saved.is_supported(), "the worn wall holds two roofs")
	worn.health = (75 - STRAW(1)) / 2
	weathering_season()
	weathering_service(worn)
	weathering_check(worn && !worn.gcDestroyed && worn.health == 0 && worn.seasonal_construction_ruined(), "a worn-out wall stands as a ruin ([worn ? worn.health : "gone"])")
	weathering_check(worn.name == "ruined [initial(worn.name)]" && worn.cracked == 3 && !worn.building_support_tier(), "the ruin is named, cracked and carries nothing ([worn.name], [worn.cracked])")
	weathering_check(findtext(worn.seasonal_construction_condition(), "It is a ruin"), "examine names the ruin: [worn.seasonal_construction_condition()]")
	worn.name = initial(worn.name)
	worn.cracked = 0
	worn.seasonal_construction_stage()
	weathering_check(worn.name == "ruined [initial(worn.name)]" && worn.cracked == 3, "the ruin is derived from health alone, as after a load")
	weathering_check(!doomed.is_supported() && !saved.is_supported(), "a ruin holds no roof up")
	sleep(70)
	weathering_check(doomed && !doomed.gcDestroyed && doomed.sagging && saved && !saved.gcDestroyed && saved.sagging, "roofs over a ruin sag before they fall")
	// Propping one in time saves it; the other comes down after the warning.
	new /obj/covers/wood_wall(locate(5,1,1))
	sleep(ROOF_SAG_TIME + 80)
	weathering_check(saved && !saved.gcDestroyed && !saved.sagging, "a propped roof settles")
	weathering_check(!doomed || doomed.gcDestroyed, "an unpropped roof falls after its warning")
	planks.amount = 50
	worn.do_repair(H, planks, worn.buildstackamount)
	weathering_check(worn.health == 75 && worn.name == initial(worn.name) && !worn.cracked && worn.building_support_tier() == 2, "a repaired ruin is a wall again ([worn.health], [worn.name], [worn.cracked])")
	text2file("PASS: weathering wear and unpaid seasons survive save/load; warnings, repairs, pacing, ruins and sagging roofs work", "weathering_result.txt")
	del(world)
