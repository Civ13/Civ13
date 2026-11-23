/world
	maxx = 4
	maxy = 4
	maxz = 1
	turf = /turf
	area = /area
	sleep_offline = FALSE
/world/OpenPort(port)
	return ..("none")
/world/IsBanned(key, address, computer_id, type, real_bans_only)
	return list("reason" = "Offline metadata migration fixture")
/obj/map_metadata/nomads/gaia/New()
	map = src

var/migration_checks = 0
/proc/migration_assert(condition, message)
	migration_checks++
	if(!condition) throw EXCEPTION(message)
/proc/migration_copy(list/state)
	return json_decode(json_encode(state))
/proc/migration_capture()
	map_storage.zone_export_state = list("fixture" = TRUE)
	var/list/state = map_storage.capture_durable_world()
	state["nodes"] = map_storage.durable_export.finish_export()
	var/area/A = get_area(locate(1,1,1))
	state["areas"] = list(list("x" = 1, "y" = 1, "z" = 1, "type" = "[A.type]", "fields" = durable_metadata_snapshot_fields(A, durable_metadata_area_schema())))
	return state
/proc/migration_reject(list/state, message)
	var/before = json_encode(state)
	var/list/sentinel = list("live" = "unchanged")
	map.faction_renames = sentinel
	map.default_research = 777
	var/rejected = FALSE
	try
		map_storage.validate_durable_world(state, "round-v2:fixture")
	catch
		rejected = TRUE
	migration_assert(rejected && map.faction_renames == sentinel && map.default_research == 777 && !map_storage.durable_state && !map_storage.durable_import, message)
	migration_assert(before == json_encode(state), "rejection changed input: [message]")

/world/New()
	OpenPort("none")
	try
		config = new
		config.webhook_can_fire = FALSE
		config.ToRban = FALSE
		processes.time_of_day = new
		processes.weather = new
		map = new /obj/map_metadata/nomads/gaia(locate(1,1,1))
		season = "SPRING"
		time_of_day = "Morning"
		game_hour = 9
		times_of_day = list("Morning")
		var/list/current = durable_metadata_map_schema()
		var/list/frozen_old = json_decode(file2text("map-schema-v1.json"))
		var/list/frozen_mid = json_decode(file2text("map-schema-v2.json"))
		var/list/frozen_new = json_decode(file2text("map-schema-v3.json"))
		var/list/frozen_v4 = json_decode(file2text("map-schema-v4.json"))
		var/list/frozen_v5 = json_decode(file2text("map-schema-v5.json"))
		var/list/frozen_v6 = json_decode(file2text("map-schema-v6.json"))
		var/list/frozen_v7 = json_decode(file2text("map-schema-v7.json"))
		migration_assert(current.len == 137 && frozen_old.len == 131 && frozen_mid.len == 132 && frozen_new.len == 133 && frozen_v4.len == 134 && frozen_v5.len == 135 && frozen_v6.len == 136 && frozen_v7.len == 137, "exact schema sizes")
		for(var/key in current)
			migration_assert(current[key] == frozen_v7[key], "current frozen schema differs: [key]")
		for(var/key in frozen_v6)
			migration_assert(current[key] == frozen_v6[key] && key != "era_records_state", "v6 frozen schema differs: [key]")
		for(var/key in frozen_v5)
			migration_assert(current[key] == frozen_v5[key] && key != "language_lineage_state", "v5 frozen schema differs: [key]")
		for(var/key in frozen_v4)
			migration_assert(current[key] == frozen_v4[key] && key != "fishing_grounds_state", "v4 frozen schema differs: [key]")
		for(var/key in frozen_new)
			migration_assert(current[key] == frozen_new[key] && key != "river_flood_state", "v3 frozen schema differs: [key]")
		for(var/key in frozen_old)
			migration_assert(current[key] == frozen_old[key] && key != "faction_renames" && key != "faction_recruitment" && key != "river_flood_state", "legacy frozen schema differs: [key]")
		for(var/key in frozen_mid)
			migration_assert(current[key] == frozen_mid[key] && key != "faction_recruitment" && key != "river_flood_state", "v2 frozen schema differs: [key]")
		var/list/new_state = migration_capture()
		migration_assert(new_state["map_fields_version"] == 7, "new writer declares field schema version")
		// Frozen pre-moving-weather timer names: real validation/restore, no live save.
		var/list/legacy_weather = list("blizzard_start", "blizzard_end", "heat_start", "heat_end", "sandstorm_start", "sandstorm_end")
		var/list/weather_state = migration_copy(new_state)
		var/list/weather_timers = list("wind" = 100000)
		for(var/key in legacy_weather) weather_timers[key] = 100000
		weather_state["timers"] = weather_timers
		var/weather_bytes = json_encode(weather_state)
		migration_assert(map_storage.validate_durable_world(weather_state, "round-v2:fixture"), "legacy weather timers validate")
		map_storage.restore_durable_world()
		var/datum/durable_timer_queue/weather_queue = map.durable_timer_queue()
		var/list/first_row = weather_queue.pending["heat_end"]
		migration_assert(map_storage.validate_durable_world(weather_state, "round-v2:fixture"), "legacy weather repeated load validates")
		map_storage.restore_durable_world()
		migration_assert(first_row != weather_queue.pending["heat_end"], "repeated load invalidates old callback row")
		var/list/weather_snapshot = weather_queue.snapshot()
		migration_assert(weather_snapshot.len == 7, "exact legacy and ordinary timer inventory restored")
		for(var/key in weather_timers)
			migration_assert(weather_snapshot[key] > 99900 && weather_snapshot[key] <= 100000, "saved weather remainder retained: [key]")
		var/list/weather_roundtrip = migration_capture()
		migration_assert(map_storage.validate_durable_world(weather_roundtrip, "round-v2:fixture"), "legacy callbacks can be saved again")
		map_storage.restore_durable_world()
		weather_queue.cancel_all()
		migration_assert(weather_bytes == json_encode(weather_state), "legacy weather input unchanged")
		for(var/key in legacy_weather)
			for(var/bad_delay in list(-1, "600", 1e16))
				var/list/bad_weather = migration_copy(new_state)
				bad_weather["timers"] = list("[key]" = bad_delay)
				migration_reject(bad_weather, "invalid legacy weather delay")
		var/list/unknown_weather = migration_copy(weather_state)
		unknown_weather["timers"]["unknown_weather"] = 600
		migration_reject(unknown_weather, "unknown callback alongside legacy weather remains rejected")
		map.valid_weather_types = list(WEATHER_NONE, WEATHER_EXTREME)
		map.durable_blizzard_start()
		migration_assert(map.blizzard && weather == WEATHER_EXTREME && map.durable_pending("blizzard_end"), "legacy blizzard start retains finite cleanup")
		var/list/blizzard_deadline = weather_queue.snapshot()
		migration_assert(blizzard_deadline["blizzard_end"] >= 2400 && blizzard_deadline["blizzard_end"] <= 3600, "bounded legacy blizzard ending")
		weather_queue.cancel_all()
		map.durable_blizzard_end()
		migration_assert(!map.blizzard && weather == WEATHER_NONE, "legacy blizzard end clears state")
		map.durable_sandstorm_start()
		migration_assert(map.sandstorm && weather == WEATHER_EXTREME && map.durable_pending("sandstorm_end"), "legacy sandstorm start retains finite cleanup")
		var/list/sandstorm_deadline = weather_queue.snapshot()
		migration_assert(sandstorm_deadline["sandstorm_end"] >= 3000 && sandstorm_deadline["sandstorm_end"] <= 3600, "bounded legacy sandstorm ending")
		weather_queue.cancel_all()
		map.durable_sandstorm_end()
		migration_assert(!map.sandstorm && weather == WEATHER_NONE, "legacy sandstorm end clears state")
		var/obj/structure/sink/well/W = new(locate(2,2,1))
		var/obj/structure/sink/puddle/P = new(locate(3,2,1))
		var/obj/structure/sink/S = new(locate(4,2,1))
		S.dry = TRUE
		map.durable_heat_start()
		migration_assert(map.heat_wave && W.dry && P.dry && map.durable_pending("heat_end"), "legacy heat start dries wells/puddles with finite cleanup")
		var/list/heat_deadline = weather_queue.snapshot()
		migration_assert(heat_deadline["heat_end"] >= 3000 && heat_deadline["heat_end"] <= 3600, "bounded legacy heat ending")
		weather_queue.cancel_all()
		map.durable_heat_end()
		migration_assert(!map.heat_wave && !W.dry && !P.dry && S.dry, "legacy heat end clears wells/puddles only")
		var/list/old_state = migration_copy(new_state)
		old_state -= "map_fields_version"
		var/list/old_fields = old_state["fields"]
		old_fields -= "faction_renames"
		old_fields -= "faction_recruitment"
		old_fields -= "river_flood_state"
		old_fields -= "fishing_grounds_state"
		old_fields -= "language_lineage_state"
		old_fields -= "era_records_state"
		migration_assert(old_fields.len == 131, "fixture matches exact old inventory")
		// These are synthetic files, not copies of the production generation.
		var/original = json_encode(list("version" = 2, "generation" = "round-v2:fixture", "world_state" = old_state))
		var/intent = "fixture transaction identity retained"
		text2file(original, "original-round.json")
		text2file("round-v2:fixture", "original-save_complete.txt")
		text2file(intent, "original-restart_intent.json")
		var/original_bytes = file2text("original-round.json")
		var/marker_bytes = file2text("original-save_complete.txt")
		var/intent_bytes = file2text("original-restart_intent.json")
		fcopy("original-round.json", "candidate-round.json")
		var/list/envelope = json_decode(file2text("candidate-round.json"))
		old_state = envelope["world_state"]
		var/list/first_default
		for(var/topology_version in list(1, 2))
			var/list/state = migration_copy(old_state)
			state["schema"] = topology_version
			if(topology_version == 1) state -= "topology"
			var/before = json_encode(state)
			map.faction_renames = list("stale" = "must not survive")
			map.faction_recruitment = list("stale" = "must not survive")
			map.river_flood_state = list(9, 9)
			map.fishing_grounds_state = list("stale")
			map.language_lineage_state = list("stale")
			map.era_records_state = list("stale")
			migration_assert(map_storage.validate_durable_world(state, envelope["generation"]), "old schema validates")
			map_storage.restore_durable_world()
			migration_assert(islist(map.fishing_grounds_state) && !map.fishing_grounds_state.len, "legacy restores empty fishing grounds")
			migration_assert(islist(map.language_lineage_state) && !map.language_lineage_state.len, "legacy restores empty language lineage")
			migration_assert(islist(map.era_records_state) && !map.era_records_state.len, "legacy restores empty era records")
			migration_assert(islist(map.faction_renames) && !map.faction_renames.len && map.faction_renames != first_default, "legacy restores fresh empty mapping")
			migration_assert(islist(map.faction_recruitment) && !map.faction_recruitment.len, "legacy restores empty recruitment state")
			migration_assert(islist(map.river_flood_state) && !map.river_flood_state.len, "legacy restores empty river state")
			first_default = map.faction_renames
			migration_assert(before == json_encode(state), "successful migration must not rewrite input")
		var/list/versioned_old = migration_copy(old_state)
		versioned_old["map_fields_version"] = 1
		migration_assert(map_storage.validate_durable_world(versioned_old, "round-v2:fixture"), "explicit old field version validates")
		map_storage.restore_durable_world()
		migration_assert(!map.faction_renames.len && map.faction_renames != first_default, "explicit old version restores a fresh default")
		var/list/roundtrip = migration_capture()
		migration_assert(roundtrip["map_fields_version"] == 7 && length(roundtrip["fields"]) == 137, "legacy roundtrip writes current inventory")
		text2file(json_encode(roundtrip), "roundtrip.json")
		migration_assert(map_storage.validate_durable_world(json_decode(file2text("roundtrip.json")), "round-v2:fixture"), "current disk metadata roundtrip validates")
		map_storage.restore_durable_world()
		map.faction_renames = list("New faction" = list("Old faction", 7, 1234))
		map.faction_recruitment = list("schema" = 1, "seq" = 4, "policies" = list("New faction" = list("mode" = "manual", "open" = 0, "language" = "", "skills" = list("farming" = 3), "nonmatch" = "review", "revision" = 2)), "applications" = list(), "audit" = list())
		var/list/with_rename = migration_capture()
		var/list/unversioned_current = migration_copy(with_rename)
		unversioned_current -= "map_fields_version"
		var/list/unversioned_fields = unversioned_current["fields"]
		unversioned_fields -= "faction_recruitment"
		unversioned_fields -= "river_flood_state"
		unversioned_fields -= "fishing_grounds_state"
		unversioned_fields -= "language_lineage_state"
		unversioned_fields -= "era_records_state"
		migration_assert(map_storage.validate_durable_world(unversioned_current, "round-v2:fixture"), "unversioned #3560 inventory validates")
		map_storage.restore_durable_world()
		var/list/renamed = map.faction_renames["New faction"]
		migration_assert(renamed && renamed[1] == "Old faction" && renamed[2] == 7, "present rename data is preserved")
		migration_assert(!map.faction_recruitment.len, "v2 inventory restores empty recruitment state")
		var/list/declared_v2 = migration_copy(unversioned_current)
		declared_v2["map_fields_version"] = 2
		migration_assert(map_storage.validate_durable_world(declared_v2, "round-v2:fixture"), "declared v2 inventory validates")
		map_storage.restore_durable_world()
		migration_assert(!map.faction_recruitment.len, "declared v2 restores empty recruitment state")
		var/list/declared_v3 = migration_copy(with_rename)
		declared_v3["map_fields_version"] = 3
		var/list/v3_fields = declared_v3["fields"]
		v3_fields -= "river_flood_state"
		v3_fields -= "fishing_grounds_state"
		v3_fields -= "language_lineage_state"
		v3_fields -= "era_records_state"
		map.river_flood_state = list(9, 9)
		migration_assert(map_storage.validate_durable_world(declared_v3, "round-v2:fixture"), "declared v3 inventory validates")
		map_storage.restore_durable_world()
		migration_assert(islist(map.river_flood_state) && !map.river_flood_state.len, "declared v3 restores empty river state")
		map.river_flood_state = list(2, 1.5, 3, 0, 0.25)
		var/list/with_river = migration_capture()
		text2file(json_encode(with_river), "with-river.json")
		map.river_flood_state = list()
		migration_assert(map_storage.validate_durable_world(json_decode(file2text("with-river.json")), "round-v2:fixture"), "current river state validates from disk")
		map_storage.restore_durable_world()
		migration_assert(map.river_flood_state.len == 5 && map.river_flood_state[1] == 2 && map.river_flood_state[5] == 0.25, "river state survives a disk round trip")
		var/list/declared_v4 = migration_copy(with_river)
		declared_v4["map_fields_version"] = 4
		var/list/v4_fields = declared_v4["fields"]
		v4_fields -= "fishing_grounds_state"
		v4_fields -= "language_lineage_state"
		v4_fields -= "era_records_state"
		map.fishing_grounds_state = list("stale")
		migration_assert(map_storage.validate_durable_world(declared_v4, "round-v2:fixture"), "declared v4 inventory validates")
		map_storage.restore_durable_world()
		migration_assert(islist(map.fishing_grounds_state) && !map.fishing_grounds_state.len, "declared v4 restores empty fishing grounds")
		map.fishing_grounds_state = list("salt", 3, 4, 1, 12, 2.5)
		var/list/with_grounds = migration_capture()
		text2file(json_encode(with_grounds), "with-grounds.json")
		map.fishing_grounds_state = list()
		migration_assert(map_storage.validate_durable_world(json_decode(file2text("with-grounds.json")), "round-v2:fixture"), "current fishing grounds validate from disk")
		map_storage.restore_durable_world()
		migration_assert(map.fishing_grounds_state.len == 6 && map.fishing_grounds_state[1] == "salt" && map.fishing_grounds_state[6] == 2.5, "fishing grounds survive a disk round trip")
		map.fishing_grounds_state = list()
		var/list/declared_v5 = migration_copy(with_grounds)
		declared_v5["map_fields_version"] = 5
		var/list/v5_fields = declared_v5["fields"]
		v5_fields -= "language_lineage_state"
		v5_fields -= "era_records_state"
		map.language_lineage_state = list("stale")
		migration_assert(map_storage.validate_durable_world(declared_v5, "round-v2:fixture"), "declared v5 inventory validates")
		map_storage.restore_durable_world()
		migration_assert(islist(map.language_lineage_state) && !map.language_lineage_state.len, "declared v5 restores empty language lineage")
		map.fishing_grounds_state = list()
		map.language_lineage_state = list("drift" = list("Iron Pact|Latin" = 42.5), "daughters" = list())
		var/list/with_lineage = migration_capture()
		text2file(json_encode(with_lineage), "with-lineage.json")
		map.language_lineage_state = list()
		migration_assert(map_storage.validate_durable_world(json_decode(file2text("with-lineage.json")), "round-v2:fixture"), "current language lineage validates from disk")
		map_storage.restore_durable_world()
		var/list/lineage_drift = map.language_lineage_state["drift"]
		migration_assert(islist(lineage_drift) && lineage_drift["Iron Pact|Latin"] == 42.5, "language lineage survives a disk round trip")
		map.language_lineage_state = list()
		var/list/declared_v6 = migration_copy(with_lineage)
		declared_v6["map_fields_version"] = 6
		var/list/v6_fields = declared_v6["fields"]
		v6_fields -= "era_records_state"
		map.era_records_state = list("stale")
		migration_assert(map_storage.validate_durable_world(declared_v6, "round-v2:fixture"), "declared v6 inventory validates")
		map_storage.restore_durable_world()
		migration_assert(islist(map.era_records_state) && !map.era_records_state.len, "declared v6 restores empty era records")
		map.language_lineage_state = list()
		map.era_records_state = list("missing_since" = "8123456789", "last_step" = "8123400000")
		var/list/with_eras = migration_capture()
		text2file(json_encode(with_eras), "with-eras.json")
		map.era_records_state = list()
		migration_assert(map_storage.validate_durable_world(json_decode(file2text("with-eras.json")), "round-v2:fixture"), "current era records validate from disk")
		map_storage.restore_durable_world()
		migration_assert(map.era_records_state["missing_since"] == "8123456789" && map.era_records_state["last_step"] == "8123400000", "era records survive a disk round trip")
		map.era_records_state = list()
		text2file(json_encode(with_rename), "with-recruitment.json")
		migration_assert(map_storage.validate_durable_world(json_decode(file2text("with-recruitment.json")), "round-v2:fixture"), "current recruitment state validates from disk")
		map_storage.restore_durable_world()
		var/list/policies = map.faction_recruitment["policies"]
		var/list/policy = policies["New faction"]
		migration_assert(map.faction_recruitment["seq"] == 4 && policy && policy["revision"] == 2 && policy["skills"]["farming"] == 3, "recruitment state survives a disk round trip")
		for(var/key in frozen_old)
			var/list/bad = migration_copy(old_state)
			var/list/fields = bad["fields"]
			fields -= key
			migration_reject(bad, "legacy missing required field [key]")
			if(migration_checks % 16 == 0) sleep(0)
		for(var/key in frozen_v7)
			var/list/bad = migration_copy(new_state)
			var/list/fields = bad["fields"]
			fields -= key
			migration_reject(bad, "versioned missing required field [key]")
			if(migration_checks % 16 == 0) sleep(0)
		for(var/key in frozen_v7)
			var/list/bad = migration_copy(new_state)
			var/list/fields = bad["fields"]
			var/list/nodes = bad["nodes"]
			// A valid graph node of the wrong field kind, not graph corruption.
			nodes[fields[key]] = frozen_v7[key] in list("list", "alist") ? list("kind" = "value", "value" = 5) : list("kind" = "list", "keys" = list(), "values" = list())
			migration_reject(bad, "wrong typed field [key]")
			if(migration_checks % 16 == 0) sleep(0)
		for(var/version in list(0, 8, -1, 1.5, "2", null))
			var/list/bad = migration_copy(new_state)
			bad["map_fields_version"] = version
			migration_reject(bad, "unknown or malformed field version")
		for(var/corruption in list("extra", "substitute", "bad-index", "extra-envelope", "future-envelope", "wrong-profile", "v1-with-new-field", "v2-with-new-field", "v3-with-new-field", "v4-with-new-field", "v5-with-new-field", "v6-with-new-field"))
			var/list/bad = migration_copy(new_state)
			var/list/fields = bad["fields"]
			if(corruption == "extra") fields["unexpected"] = fields["age"]
			if(corruption == "substitute")
				fields["unexpected"] = fields["age"]
				fields -= "age"
			if(corruption == "bad-index") fields["faction_renames"] = 999999
			if(corruption == "extra-envelope") bad["unexpected"] = 1
			if(corruption == "future-envelope") bad["schema"] = 3
			if(corruption == "wrong-profile") bad["map_type"] = "/obj/map_metadata/nomads/europe"
			if(corruption == "v1-with-new-field") bad["map_fields_version"] = 1
			if(corruption == "v2-with-new-field") bad["map_fields_version"] = 2
			if(corruption == "v3-with-new-field") bad["map_fields_version"] = 3
			if(corruption == "v4-with-new-field") bad["map_fields_version"] = 4
			if(corruption == "v5-with-new-field") bad["map_fields_version"] = 5
			if(corruption == "v6-with-new-field") bad["map_fields_version"] = 6
			migration_reject(bad, corruption)
		migration_assert(file2text("original-round.json") == original_bytes && file2text("candidate-round.json") == original_bytes, "original and candidate bytes preserved")
		migration_assert(file2text("original-save_complete.txt") == marker_bytes && file2text("original-restart_intent.json") == intent_bytes, "generation and transaction identity preserved")
		migration_assert(world.port == 0 && !world.OpenPort(0) && world.port == 0, "listener is closed and cannot reopen")
		text2file("PASS: [migration_checks] assertions", "result.txt")
	catch(var/exception/e)
		text2file("FAIL: [e] at [e.file]:[e.line]", "result.txt")
	del(world)
	return
