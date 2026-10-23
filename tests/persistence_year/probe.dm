// Uses the existing durable-world startup adapters and complete production game.
// This child is intentionally outside the production durable-profile allowlist,
// exercising the genuine version-1 writer without overriding that admission.
/obj/map_metadata/nomads/gaia/persistence_year_legacy

/world
	visibility = 0
/world/OpenPort(port)
	return ..("none")
/world/Topic(T, addr, master, key)
	return null
/client/New()
	del(src)

var/persistence_year_imports = 0

/proc/persistence_year_research()
	return json_encode(list(map.default_research, map.custom_civs, map.faction_research, map.faction_baseline_era))

/proc/persistence_year_snapshot()
	var/list/state = list(map.age, map.ordinal_age, persistence_year_research())
	for(var/i = 1, i <= 8, i++) state += map.vars["age[i]_done"]
	return json_encode(state)

/proc/persistence_year_reset(date, tier, persistent = TRUE)
	map.age = date
	map.ordinal_age = tier
	map.persistence = persistent
	for(var/i = 1, i <= 8, i++) map.vars["age[i]_done"] = i <= tier
	map.default_research = 181.25
	map.custom_civs = list("A" = list(40, 50, 60))
	var/list/shared = list("points" = 123.5, "completed" = list("bronze", "iron"))
	map.faction_research = list("A" = shared, "B" = shared)
	map.faction_baseline_era = list("A" = 1, "B" = 3)
	// Activation must not start an unrelated sleeper in this isolated fixture.
	map.autoresearch = TRUE

/proc/persistence_year_direct()
	for(var/date in list("5000 B.C.", "313 B.C.", "1013", "1713", "1873", "1903", "1942"))
		persistence_year_reset(date, 0)
		var/research = persistence_year_research()
		map.apply_persistence_age_floor()
		durable_world_check(map.age == "1943", "earlier date not raised")
		durable_world_check(map.ordinal_age == 6, "earlier tier not raised")
		for(var/i = 1, i <= 6, i++) durable_world_check(map.vars["age[i]_done"], "skipped epoch not completed")
		durable_world_check(persistence_year_research() == research, "helper changed research progress")
		var/after = persistence_year_snapshot()
		map.apply_persistence_age_floor()
		durable_world_check(persistence_year_snapshot() == after, "repeated floor changed state")
	for(var/date in list("1943", "1944", "1969", "2013", "2023", "unknown epoch"))
		persistence_year_reset(date, 3)
		var/before = persistence_year_snapshot()
		map.apply_persistence_age_floor()
		durable_world_check(persistence_year_snapshot() == before, "equal or later date changed")
	persistence_year_reset("1903", 8)
	map.apply_persistence_age_floor()
	durable_world_check(map.age == "1943" && map.ordinal_age == 8 && map.age8_done, "advanced tier reset")
	persistence_year_reset("1903", 3, FALSE)
	var/unrelated = persistence_year_snapshot()
	map.apply_persistence_age_floor()
	durable_world_check(persistence_year_snapshot() == unrelated, "unrelated mode changed")

/proc/persistence_year_activation()
	var/datum/admins/operator = new("Temporary Admin", 1, "persistenceyearfixture")
	for(var/date in list("1903", "1943", "2023"))
		persistence_year_reset(date, 8, FALSE)
		var/research = persistence_year_research()
		var/expected = date == "1903" ? "1943" : date
		operator.persistent()
		durable_world_check(map.persistence && map.age == expected, "admin activation date wrong")
		durable_world_check(persistence_year_research() == research && map.ordinal_age == 8, "admin activation reset research")
		operator.persistent()
		durable_world_check(!map.persistence && map.age == expected, "admin disable changed date")
		operator.persistent()
		durable_world_check(map.persistence && map.age == expected, "admin reenable date wrong")
		persistence_year_reset(date, 8, FALSE)
		config.allowedgamemodes = "PERSISTENCE"
		persistence_year_startup()
		durable_world_check(map.persistence && map.age == expected, "configured activation date wrong")
		durable_world_check(persistence_year_research() == research && map.ordinal_age == 8, "configured activation reset research")
		var/after = persistence_year_snapshot()
		persistence_year_startup()
		durable_world_check(persistence_year_snapshot() == after, "repeated configured activation changed state")
	persistence_year_reset("1903", 3, FALSE)
	config.allowedgamemodes = "ALL"
	var/unrelated = persistence_year_snapshot()
	persistence_year_startup()
	durable_world_check(!map.persistence && persistence_year_snapshot() == unrelated, "unrelated startup mode changed")

/proc/persistence_year_disk(version)
	for(var/persistent in list(TRUE, FALSE))
		for(var/date in list("1903", "1943", "2023"))
			persistence_year_reset(date, 8, persistent)
			map.autoresearch = FALSE
			var/research = persistence_year_research()
			durable_world_check(map_storage.Save_World(), "date disk save failed")
			var/header = file2text("map_saves/round.json")
			var/list/state = json_decode(header)
			durable_world_check(state["version"] == version, "wrong native save version")
			var/metadata = file2text("map_saves/map.txt")
			var/marker = file2text("map_saves/save_complete.txt")
			var/expected = persistent && date == "1903" ? "1943" : date
			for(var/pass = 1, pass <= 2, pass++)
				// Fresh startup's floor cannot override the imported saved state.
				map.persistence = TRUE
				map.age = "5000 B.C."
				map.ordinal_age = 0
				map.apply_persistence_age_floor()
				map.default_research = 1
				if(version == 2)
					map.faction_research = list()
					map.custom_civs = list()
					map.faction_baseline_era = list()
				durable_world_check(ticker.loadmap(), "date disk import failed")
				persistence_year_imports++
				durable_world_check(map.age == expected, "saved date floor lost")
				durable_world_check(map.persistence == persistent, "saved mode flag lost")
				durable_world_check(map.ordinal_age == 8 && map.age8_done, "saved higher tier lost")
				durable_world_check(persistence_year_research() == research, "saved research progress lost")
				if(version == 2)
					durable_world_check(map.faction_research["A"] == map.faction_research["B"], "saved research alias lost")
				durable_world_check(file2text("map_saves/round.json") == header && file2text("map_saves/map.txt") == metadata && file2text("map_saves/save_complete.txt") == marker, "load rewrote saved generation")
				durable_world_check(!persistence_save_in_progress && !persistence_active_operation && !map_storage.durable_import && !map_storage.durable_state, "date import retained operation or graph")

/world/New()
	world.OpenPort("none")
	try
		durable_world_check(world.port == 0, "fixture port open")
		world.OpenPort(0)
		durable_world_check(world.port == 0, "fixture port reopened")
		// Reuse the existing native runner's real OS socket census handshake.
		text2file(json_encode(list("port" = world.port)), "lighting-port-ready.json")
		var/deadline = world.realtime + 300
		while(!fexists("listener-census.json") && world.realtime < deadline) sleep(1)
		durable_world_check(fexists("listener-census.json"), "listener census missing")
		config = new
		config.webhook_can_fire = FALSE
		config.ToRban = FALSE
		ticker = new
		ticker.current_state = GAME_STATE_PREGAME
		global.game_id = "persistence-year-native-fixture"
		processes.time_of_day = new
		processes.weather = new
		map_storage.record_compiled_dimensions()
		map = new /obj/map_metadata/nomads/gaia(locate(1,1,1))
		map.times_of_day = list("Morning", "Evening")
		times_of_day = map.times_of_day
		season = "SPRING"
		time_of_day = "Morning"
		persistence_year_direct()
		persistence_year_activation()
		persistence_year_disk(2)
		map = new /obj/map_metadata/nomads/gaia/persistence_year_legacy(locate(1,1,1))
		durable_world_check(!map.uses_durable_metadata(), "legacy fixture unexpectedly durable")
		persistence_year_disk(1)
		durable_world_check(!durable_probe_failed && world.port == 0, "native diagnostics or port state invalid")
		text2file(json_encode(list("done" = TRUE, "checks" = durable_probe_checks, "imports" = persistence_year_imports)), "metadata-result.json")
	catch(var/exception/E)
		world.log << "FAIL: [E] at [E.file]:[E.line]"
		text2file(json_encode(list("done" = FALSE, "checks" = durable_probe_checks, "imports" = persistence_year_imports, "error" = "[E]")), "metadata-result.json")
	del(world)
	return
