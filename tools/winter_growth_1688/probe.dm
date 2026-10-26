// Inactive source fixture. Ordinary production crops and real round-v1 world I/O.
// No gameplay callback override, direct callback call, clock acceleration or native run.
/world
	hub = ""
	hub_password = ""
	visibility = 0
	maxx = 10
	maxy = 8
	maxz = 1
	sleep_offline = FALSE
	turf = /turf/floor/plating
	area = /area/caribbean

/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/client/New()
	del(src)
	return

/area/caribbean/winter_outdoor
	location = AREA_OUTSIDE
	climate = "temperate"
	icon_state = ""
	is_void_area = FALSE
/area/caribbean/winter_cave
	location = AREA_INSIDE
	climate = "temperate"
	icon_state = ""
	is_void_area = FALSE

// Exact type intentionally excludes durable-zone metadata; no season scheduler.
/obj/map_metadata/nomads/winter_tester
	ID = MAP_NOMADS_PANGEA
/obj/map_metadata/nomads/winter_tester/New()
	return
/mob/living/human/winter_tester
	should_save = FALSE
/mob/living/human/winter_tester/New()
	return
/mob/living/human/winter_tester/adaptStat(stat, amount)
	return

var/list/winter_observations = list()
var/list/winter_saved_snapshot
var/winter_origin_tick
var/winter_setup_started_tick
var/winter_save_started_tick
var/winter_save_finished_tick
var/winter_load_started_tick
var/winter_load_finished_tick
var/winter_poll_max_gap = 0

/proc/winter_check(condition, message)
	if (!condition)
		throw EXCEPTION(message)

/proc/winter_setup()
	winter_check(!world.port, "fixture has no open port")
	winter_check(world.tick_lag == 1 && world.fps == 10, "ordinary ten-Hz clock required")
	config = new
	config.webhook_can_fire = FALSE
	config.ToRban = FALSE
	if (!chemical_reagents_list)
		initialize_chemical_reagents()
	GLOB.all_observable_events = list()
	GLOB.moved_event = new /decl/observ/moved
	GLOB.dir_set_event = new /decl/observ/dir_set
	GLOB.name_set_event = new /decl/observ/name_set
	GLOB.stat_set_event = new /decl/observ/stat_set
	ticker = new
	ticker.current_state = GAME_STATE_PREGAME
	map = new /obj/map_metadata/nomads/winter_tester
	map.heat_wave = FALSE
	season = "WINTER"
	var/area/O = new /area/caribbean/winter_outdoor
	var/area/C = new /area/caribbean/winter_cave
	for (var/turf/T in world)
		ChangeArea(T, T.x <= 5 ? O : C)
	winter_check(!map.uses_durable_metadata(), "fixture requires ordinary round-v1 metadata")

/proc/winter_plot(kind, index)
	if (kind == "turnip")
		return locate(index, 2, 1)
	if (kind == "potato")
		return locate(index, 3, 1)
	var/column = 6 + ((index - 1) % 4)
	var/row = 1 + round((index - 1) / 4)
	if (kind == "mushroom")
		row += 4
	return locate(column, row, 1)

/proc/winter_create_plants()
	var/mob/living/human/H = new /mob/living/human/winter_tester(locate(5,8,1))
	// Ordinary non-salty water tiles; no water assignment on any plant.
	for (var/x = 1, x <= 4, x++)
		new /turf/floor/beach/water(locate(x,1,1))
		new /turf/floor/beach/water(locate(x,4,1))
	for (var/kind in list("turnip", "potato", "plump_helmet", "mushroom"))
		var/count = (kind == "turnip" || kind == "potato") ? 4 : 16
		var/obj/item/stack/farming/seeds/S
		if (kind == "turnip" || kind == "plump_helmet")
			var/seed_path = text2path("/obj/item/stack/farming/seeds/[kind]")
			S = new seed_path(locate(kind == "turnip" ? 1 : 2,7,1), count + 1)
		for (var/i = 1, i <= count, i++)
			var/turf/floor/dirt/ploughed/T = new(winter_plot(kind,i))
			if (S)
				var/before = S.amount
				T.attackby(S,H)
				winter_check(S.amount == before - 1, "[kind]:[i] production sowing spends exactly one seed")
			else
				var/plant_path = text2path("/obj/structure/farming/plant/[kind]")
				new plant_path(T)
			var/obj/structure/farming/plant/P = locate(/obj/structure/farming/plant) in T
			winter_check(P && P.type == text2path("/obj/structure/farming/plant/[kind]") && P.stage == 1 && !P.vstatic, "[kind]:[i] ordinary constructor starts active stage one")
	// Excluded helper is never serialized and owns no scheduler or physiology.

/proc/winter_snapshot()
	var/list/plants = list()
	var/census = 0
	for (var/obj/structure/farming/plant/P in world)
		census++
	winter_check(census == 40, "exact forty-plant census")
	for (var/kind in list("turnip", "potato", "plump_helmet", "mushroom"))
		var/count = (kind == "turnip" || kind == "potato") ? 4 : 16
		for (var/i = 1, i <= count, i++)
			var/turf/floor/dirt/T = winter_plot(kind,i)
			var/obj/structure/farming/plant/P = locate(/obj/structure/farming/plant) in T
			winter_check(P && istype(T), "[kind]:[i] remains on its plot")
			plants += list(list("id" = "[kind]:[i]", "type" = "[P.type]", "x" = P.x, "y" = P.y, "z" = P.z, "identity" = "\ref[P]", "stage" = P.stage, "soil" = T.soil_nutrition, "water" = P.water, "plant_nutrition" = P.plant_nutrition, "vstatic" = P.vstatic ? 1 : 0))
	return list("tick" = world.time, "elapsed" = world.time - winter_origin_tick, "plants" = plants, "foods" = winter_food_snapshot(), "seeds" = winter_seed_snapshot())

/proc/winter_store_observation(list/snapshot)
	winter_check(winter_observations.len < 128, "bounded observation record budget")
	winter_observations += list(snapshot)
	world.log << "GROWTH1688_OBSERVATION [json_encode(snapshot)]"

/proc/winter_observe()
	winter_origin_tick = world.time
	var/list/first = winter_snapshot()
	winter_store_observation(first)
	var/previous_tick = world.time
	var/last_stored_tick = world.time
	var/previous_state = json_encode(list(first["plants"], first["foods"], first["seeds"]))
	while (world.time - winter_origin_tick < 1350)
		sleep(1)
		winter_poll_max_gap = max(winter_poll_max_gap, world.time - previous_tick)
		previous_tick = world.time
		var/list/snapshot = winter_snapshot()
		var/state = json_encode(list(snapshot["plants"], snapshot["foods"], snapshot["seeds"]))
		if (state != previous_state || world.time - last_stored_tick >= 100 || world.time - winter_origin_tick >= 1350)
			winter_store_observation(snapshot)
			last_stored_tick = world.time
		previous_state = state

/proc/winter_food_writer()
	winter_setup_started_tick = world.time
	winter_create_plants()
	winter_create_food()
	winter_observe()
	var/list/before = winter_snapshot()
	winter_save_started_tick = world.time
	winter_check(map_storage.Save_World(), "real Save_World transaction succeeds")
	winter_save_finished_tick = world.time
	winter_check(copytext(file2text("map_saves/save_complete.txt"),1,9) == "round-v1", "real complete-generation marker uses round-v1")
	var/list/after = winter_snapshot()
	winter_saved_snapshot = list("before" = before, "after" = after)
	winter_check(text2file(json_encode(winter_saved_snapshot), "winter-growth-writer.json"), "writer scalar record is emitted")

/proc/winter_food_reader()
	winter_saved_snapshot = json_decode(file2text("winter-growth-writer.json"))
	winter_check(islist(winter_saved_snapshot) && winter_saved_snapshot.len == 2, "reader has writer scalar record")
	winter_check(map_storage.validate_world_save(), "real whole-generation validation succeeds")
	winter_load_started_tick = world.time
	winter_check(map_storage.Load_World(), "real Load_World transaction succeeds")
	winter_load_finished_tick = world.time
	// No field reset after load: constructor ordering/debits remain evidence.
	winter_observe()
