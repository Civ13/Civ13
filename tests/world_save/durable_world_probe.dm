// Full production saver/loader and metadata code, with normal startup disabled.
// Map initialization is isolated so only explicit probe state is under test.
/world
	maxx = 8
	maxy = 8
	maxz = 2
	fps = 10
	turf = /turf
	area = /area
	hub = ""
	hub_password = ""

/obj/map_metadata/nomads/gaia/New()
	map = src
/obj/map_metadata/nomads/europe/New()
	map = src
/obj/durable_probe_leader
	name = "saved metadata leader"
var/durable_probe_checks = 0
var/durable_probe_failed = FALSE
var/durable_probe_tips = 0
/obj/map_metadata/nomads/gaia/show_tip(list/tips)
	durable_probe_tips++
/obj/map_metadata/nomads/europe/show_tip(list/tips)
	durable_probe_tips++

/proc/durable_world_check(condition, message)
	durable_probe_checks++
	if(!condition) throw EXCEPTION(message)
/world/Error(exception/E)
	durable_probe_failed = TRUE
	world.log << "Unexpected runtime error: [E] at [E.file]:[E.line]"

/world/New()
	text2file("world-New entered", "probe-progress.log")
	world.OpenPort(0)
	text2file("port closed", "probe-progress.log")
	try
		text2file("construct config", "probe-progress.log")
		config = new
		config.webhook_can_fire = FALSE
		config.ToRban = FALSE
		ticker = new
		ticker.current_state = GAME_STATE_PREGAME
		processes.time_of_day = new
		processes.weather = new
		var/map_type = world.params["profile"] == "europe" ? /obj/map_metadata/nomads/europe : /obj/map_metadata/nomads/gaia
		text2file("construct map", "probe-progress.log")
		map = new map_type(locate(1,1,1))
		game_id = "metadata-disk-round"
		var/obj/durable_probe_leader/leader = new(locate(2,2,2))
		var/list/shared = list("points" = 123.5)
		shared["self"] = shared
		map.faction_research = list("first" = shared, "second" = shared)
		map.faction_research_director = list("first" = leader)
		map.default_research = 88.75
		map.research_active = TRUE
		map.resourceresearch = TRUE
		map.persistence = TRUE
		map.perschadplus = TRUE
		map.chad_mode_plus = TRUE
		map.age = "1713"
		map.ordinal_age = 3
		map.age1_done = TRUE
		map.age2_done = TRUE
		map.age3_done = TRUE
		map.age4_timer = map.research_time() + 30000
		map.artillery_last = world.time - 50
		map.next_win = world.time + 700
		map.lastcheck = world.realtime + 4096
		map.times_of_day = list("Morning", "Evening")
		times_of_day = map.times_of_day
		season = "SUMMER"
		time_of_day = "Evening"
		game_hour = 129
		processes.time_of_day.TOD_ticks = 337
		TOD_may_automatically_change = TRUE
		weather = WEATHER_WET
		weather_intensity = 0.75
		global_pollution = 29
		global_radiation = 0.4
		abandonment_season_changes = 17
		processes.weather.next_can_change_weather = world.realtime + 8192
		var/area/A = get_area(locate(3,3,1))
		A.climate = "tundra"
		A.weather = WEATHER_EXTREME
		A.weather_intensity = 0.4
		A.artillery_integrity = 37
		map.faction_symbol_grid = list("first" = faction_symbol_new_grid())
		map.faction_symbol_icon["first"] = icon('icons/obj/banners.dmi', "b_star")
		var/icon/before_icon = map.faction_symbol_icon["first"]
		before_icon.DrawBox("#123456", 4, 7, 4, 7)
		map.durable_schedule("tips", 1000)
		persistence_save_in_progress = TRUE
		text2file("save begins", "probe-progress.log")
		durable_world_check(map_storage.Save_World(), "metadata disk export failed")
		text2file("save completed", "probe-progress.log")
		var/header = file2text("map_saves/round.json")
		var/list/state = map_storage.read_round_state()
		durable_world_check(state["version"] == 2, "metadata envelope absent")
		var/list/W = state["world_state"]
		var/list/E = W["environment"]
		var/research_clock = E["research_clock"]
		var/list/fields = W["fields"]
		var/saved_age = fields["age"]
		fields -= "age"
		fdel("map_saves/round.json")
		text2file(json_encode(state), "map_saves/round.json")
		durable_world_check(!map_storage.validate_world_save() && locate(/obj/durable_probe_leader) == leader && season == "SUMMER", "omitted metadata mutated world")
		fields["age"] = saved_age
		var/list/nodes = W["nodes"]
		var/list/entry
		for(var/list/node in nodes)
			if(node["kind"] == "entry") entry = node
		durable_world_check(entry, "leader entry binding absent")
		var/savefile/F = new("map_saves/2.sav")
		var/ref = entry["ref"]
		var/path = map_storage.entry_path(F, ref)
		F["[path]/type"] << /obj/durable_probe_leader
		var/turf_ref = F["/map/2/2/2"]
		var/content_path = "[map_storage.entry_path(F, turf_ref)]/content"
		var/old_content = F[content_path]
		F[content_path] << ""
		fdel("map_saves/round.json")
		text2file(header, "map_saves/round.json")
		durable_world_check(!map_storage.validate_world_save() && locate(/obj/durable_probe_leader) == leader, "orphan metadata reference accepted")
		F[content_path] << old_content
		durable_world_check(map_storage.validate_world_save(), "valid metadata generation rejected")
		// Advance the native runtime before import: old absolute deadlines cannot
		// satisfy the portable-clock checks, and no callback may fire while locked.
		sleep(5)
		season = "SPRING"
		time_of_day = "Morning"
		map.faction_research = list()
		map.faction_research_director = list()
		map.default_research = 1
		map.age = "5000 B.C."
		map.resourceresearch = FALSE
		map.research_active = FALSE
		A.climate = "desert"
		A.artillery_integrity = 100
		map_storage.suspend_durable_world()
		map_storage.ClearMap()
		durable_world_check(map_storage.Load_World(), "metadata world import failed")
		durable_world_check(map_storage.load_map_metadata(), "legacy metadata load failed")
		map_storage.restore_durable_world()
		persistence_save_in_progress = FALSE
		durable_world_check(season == "SUMMER" && time_of_day == "Evening" && game_hour == 129, "environment phase reset")
		durable_world_check(processes.time_of_day.TOD_ticks == 337 && TOD_may_automatically_change, "TOD progress reset")
		durable_world_check(map.age == "1713" && map.age3_done && map.default_research == 88.75 && map.resourceresearch && map.research_active, "research or mode flags reset")
		durable_world_check(abs(map.research_time() - research_clock) <= 1 && map.age4_timer > map.research_time(), "research clock did not rebase")
		durable_world_check(map.next_win > world.time && map.artillery_last < world.time, "map deadlines did not rebase")
		var/list/first = map.faction_research["first"]
		durable_world_check(first == map.faction_research["second"] && first["self"] == first && first["points"] == 123.5, "metadata aliases changed")
		var/obj/durable_probe_leader/restored_leader = map.faction_research_director["first"]
		durable_world_check(istype(restored_leader) && restored_leader != leader && get_turf(restored_leader) == locate(2,2,2), "leader was duplicated or not rebound")
		durable_world_check(A.climate == "tundra" && A.artillery_integrity == 37 && A.weather_intensity == 0.4, "area state reset")
		durable_world_check(weather == WEATHER_WET && weather_intensity == 0.75 && global_pollution == 29 && abandonment_season_changes == 17, "global weather or season age reset")
		var/icon/after_icon = map.faction_symbol_icon["first"]
		durable_world_check(after_icon.GetPixel(4,7) == "#123456" && map.faction_symbol_grid["first"][1] == "#FFFFFF", "active symbol confused with draft")
		var/datum/durable_timer_queue/Q = map.durable_timer_queue()
		Q.cancel_all()
		Q.schedule("tips", 3)
		var/list/timers = Q.snapshot()
		Q.restore(timers)
		Q.restore(timers)
		sleep(8)
		durable_world_check(durable_probe_tips == 1, "restored callback duplicated")
		durable_world_check(!map_storage.durable_import && !map_storage.durable_state && !map_storage.durable_export, "metadata retained graph pins")
		if(durable_probe_failed) throw EXCEPTION("native runtime error occurred")
		text2file(json_encode(list("done" = TRUE, "checks" = durable_probe_checks, "profile" = world.params["profile"])), "metadata-result.json")
	catch(var/exception/E)
		world.log << "FAIL: [E] at [E.file]:[E.line]"
		text2file(json_encode(list("done" = FALSE, "checks" = durable_probe_checks, "error" = "[E]")), "metadata-result.json")
	del(world)
