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
		var/list/frozen_new = json_decode(file2text("map-schema-v2.json"))
		migration_assert(current.len == 132 && frozen_old.len == 131 && frozen_new.len == 132, "exact schema sizes")
		for(var/key in current)
			migration_assert(current[key] == frozen_new[key], "current frozen schema differs: [key]")
		for(var/key in frozen_old)
			migration_assert(current[key] == frozen_old[key] && key != "faction_renames", "legacy frozen schema differs: [key]")
		var/list/new_state = migration_capture()
		migration_assert(new_state["map_fields_version"] == 2, "new writer declares field schema version")
		var/list/old_state = migration_copy(new_state)
		old_state -= "map_fields_version"
		var/list/old_fields = old_state["fields"]
		old_fields -= "faction_renames"
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
			migration_assert(map_storage.validate_durable_world(state, envelope["generation"]), "old schema validates")
			map_storage.restore_durable_world()
			migration_assert(islist(map.faction_renames) && !map.faction_renames.len && map.faction_renames != first_default, "legacy restores fresh empty mapping")
			first_default = map.faction_renames
			migration_assert(before == json_encode(state), "successful migration must not rewrite input")
		var/list/versioned_old = migration_copy(old_state)
		versioned_old["map_fields_version"] = 1
		migration_assert(map_storage.validate_durable_world(versioned_old, "round-v2:fixture"), "explicit old field version validates")
		map_storage.restore_durable_world()
		migration_assert(!map.faction_renames.len && map.faction_renames != first_default, "explicit old version restores a fresh default")
		var/list/roundtrip = migration_capture()
		migration_assert(roundtrip["map_fields_version"] == 2 && length(roundtrip["fields"]) == 132, "legacy roundtrip writes current inventory")
		text2file(json_encode(roundtrip), "roundtrip.json")
		migration_assert(map_storage.validate_durable_world(json_decode(file2text("roundtrip.json")), "round-v2:fixture"), "current disk metadata roundtrip validates")
		map_storage.restore_durable_world()
		map.faction_renames = list("New faction" = list("Old faction", 7, 1234))
		var/list/with_rename = migration_capture()
		var/list/unversioned_current = migration_copy(with_rename)
		unversioned_current -= "map_fields_version"
		migration_assert(map_storage.validate_durable_world(unversioned_current, "round-v2:fixture"), "unversioned #3560 inventory validates")
		map_storage.restore_durable_world()
		var/list/renamed = map.faction_renames["New faction"]
		migration_assert(renamed && renamed[1] == "Old faction" && renamed[2] == 7, "present rename data is preserved")
		for(var/key in frozen_old)
			var/list/bad = migration_copy(old_state)
			var/list/fields = bad["fields"]
			fields -= key
			migration_reject(bad, "legacy missing required field [key]")
			if(migration_checks % 16 == 0) sleep(0)
		for(var/key in frozen_new)
			var/list/bad = migration_copy(new_state)
			var/list/fields = bad["fields"]
			fields -= key
			migration_reject(bad, "versioned missing required field [key]")
			if(migration_checks % 16 == 0) sleep(0)
		for(var/key in frozen_new)
			var/list/bad = migration_copy(new_state)
			var/list/fields = bad["fields"]
			var/list/nodes = bad["nodes"]
			// A valid graph node of the wrong field kind, not graph corruption.
			nodes[fields[key]] = frozen_new[key] in list("list", "alist") ? list("kind" = "value", "value" = 5) : list("kind" = "list", "keys" = list(), "values" = list())
			migration_reject(bad, "wrong typed field [key]")
			if(migration_checks % 16 == 0) sleep(0)
		for(var/version in list(0, 3, -1, 1.5, "2", null))
			var/list/bad = migration_copy(new_state)
			bad["map_fields_version"] = version
			migration_reject(bad, "unknown or malformed field version")
		for(var/corruption in list("extra", "substitute", "bad-index", "extra-envelope", "future-envelope", "wrong-profile", "v1-with-new-field"))
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
			migration_reject(bad, corruption)
		migration_assert(file2text("original-round.json") == original_bytes && file2text("candidate-round.json") == original_bytes, "original and candidate bytes preserved")
		migration_assert(file2text("original-save_complete.txt") == marker_bytes && file2text("original-restart_intent.json") == intent_bytes, "generation and transaction identity preserved")
		migration_assert(world.port == 0 && !world.OpenPort(0) && world.port == 0, "listener is closed and cannot reopen")
		text2file("PASS: [migration_checks] assertions", "result.txt")
	catch(var/exception/e)
		text2file("FAIL: [e] at [e.file]:[e.line]", "result.txt")
	del(world)
	return
