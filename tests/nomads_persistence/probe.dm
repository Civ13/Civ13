// Actual production constructors, graph, field contracts and timer queue.
// All disk IO is synthetic and confined to the runner's disposable directory.
/world
	maxx = 4
	maxy = 4
	maxz = 2
	turf = /turf/floor
	area = /area
	sleep_offline = FALSE
	hub = ""
	hub_password = ""
/world/OpenPort(port)
	return ..("none")
/world/IsBanned(key, address, computer_id, type, real_bans_only)
	return list("reason" = "Isolated Nomads persistence fixture")
/obj/map_metadata/nomads/future_probe
	ID = "UNREVIEWED_NOMADS"
var/nomads_checks = 0
var/nomads_climate_calls = 0
var/nomads_inject_nuke_failure = FALSE
/obj/map_metadata/nomads/wasteland/durable_nomads_nuke_effect(turf/epicenter)
	if(nomads_inject_nuke_failure) throw EXCEPTION("Injected mutating-event failure")
	return ..()
/obj/map_metadata/nomads/desert/durable_nomads_initial_climate()
	nomads_climate_calls++
	return ..()
/obj/structure/nomads_fixture_box
	name = "Nomads nested fixture"
	var/list/ledger
/obj/item/nomads_fixture_token
	name = "Nomads saved token"
/mob/living/human/nomads_fixture_body/New()
	return // Identity-only character; physiology and client IO are outside scope.
/proc/nomads_assert(condition, message)
	nomads_checks++
	if(!condition) throw EXCEPTION(message)
/proc/nomads_copy(list/value)
	return json_decode(json_encode(value))
/proc/nomads_capture()
	map_storage.zone_export_state = list("fixture" = TRUE)
	var/list/state = map_storage.capture_durable_world()
	state["nodes"] = map_storage.durable_export.finish_export()
	var/area/A = get_area(locate(1,1,1))
	state["areas"] = list(list("x" = 1, "y" = 1, "z" = 1, "type" = "[A.type]", "fields" = durable_metadata_snapshot_fields(A, durable_metadata_area_schema())))
	return state
/proc/nomads_reject(list/state, message)
	var/before = json_encode(state)
	var/live = map.default_research
	var/timers = json_encode(map.durable_timer_queue().snapshot())
	var/revision = map.durable_callbacks.revision
	var/rejected = FALSE
	try
		map_storage.validate_durable_world(state, "round-v2:nomads-fixture")
	catch
		rejected = TRUE
	nomads_assert(rejected && map.default_research == live && map.durable_callbacks.revision == revision && !map_storage.durable_state && !map_storage.durable_import, message)
	nomads_assert(before == json_encode(state), "rejection modified supplied metadata")
	// Deadlines may naturally decrease, but rejection never replaces the queue.
	nomads_assert(istext(timers), "callback snapshot unavailable")
/proc/nomads_profile_test(profile, index)
	if(map) del(map)
	season = "SPRING"
	map = new profile(locate(1,1,1))
	nomads_assert(map.uses_durable_metadata(), "unsupported registered profile: [profile]")
	nomads_assert(persistence_bed_return_enabled(), "bed-return gate: [profile]")
	nomads_assert(persistence_restart.supported(), "restart gate: [profile]")
	var/datum/durable_timer_queue/Q = map.durable_timer_queue()
	var/list/initial = Q.snapshot()
	nomads_assert(("wind" in initial) && ("religion" in initial) && ("tips" in initial) && ("season_loop" in initial), "production constructor timers: [profile] [json_encode(initial)]")
	for(var/key in map.durable_nomads_callbacks())
		Q.schedule(key, 60000)
	var/list/extension = map.durable_nomads_schema()
	if(map.durable_nomads_extension())
		for(var/key in extension)
			if(extension[key] == "flag") map.vars[key] = TRUE
			else if(key == "real_season") map.vars[key] = profile == /obj/map_metadata/nomads/ice_age ? "SUMMER" : "wet"
			else map.vars[key] = key == "oiltarget" ? 4321 : (key == "nomads_nuke_threshold" ? 72001 : 1)
	season = profile == /obj/map_metadata/nomads/mountain ? "Wet Season" : "SUMMER"
	map.default_research = 123.5
	map.persistence = TRUE
	map.faction_renames = list("fixture" = "kept")
	civname_a = "Saved fixture nation"
	config.no_respawn_delays = TRUE
	var/list/state = nomads_capture()
	var/path = "profile-[index].json"
	text2file(json_encode(state), path)
	var/original_hash = md5(file(path))
	state = json_decode(file2text(path))
	map.default_research = 998
	map.faction_renames = list()
	if(map.durable_nomads_extension())
		for(var/key in extension) map.vars[key] = extension[key] == "text" ? "stale" : 0
		civname_a = "Stale nation"
		config.no_respawn_delays = FALSE
	nomads_assert(map_storage.validate_durable_world(state, "round-v2:nomads-fixture"), "profile disk preflight: [profile]")
	map_storage.restore_durable_world()
	nomads_assert(map.default_research == 123.5 && map.faction_renames["fixture"] == "kept" && map.persistence, "base metadata restore: [profile]")
	var/list/saved_timers = state["timers"]
	var/list/restored = Q.snapshot()
	for(var/key in saved_timers)
		nomads_assert((key in restored) && restored[key] <= saved_timers[key] && restored[key] >= max(0, saved_timers[key]-2), "restored callback deadline: [profile] [key]")
	if(map.durable_nomads_extension())
		var/list/p = state["nomads_profile"]
		var/list/roots = p["fields"]
		var/list/nodes = state["nodes"]
		for(var/key in extension)
			var/list/node = nodes[roots[key]]
			nomads_assert(map.vars[key] == node["value"], "subtype field restore: [profile] [key]")
		nomads_assert(civname_a == "Saved fixture nation" && config.no_respawn_delays, "global subtype restore: [profile]")
		for(var/key in extension)
			var/list/bad = nomads_copy(state)
			var/list/bad_profile = bad["nomads_profile"]
			var/list/bad_fields = bad_profile["fields"]
			bad_fields -= key
			nomads_reject(bad, "missing subtype field accepted: [profile] [key]")
			bad = nomads_copy(state)
			bad_profile = bad["nomads_profile"]
			bad_fields = bad_profile["fields"]
			var/list/bad_nodes = bad["nodes"]
			bad_nodes[bad_fields[key]] = list("kind" = "value", "value" = extension[key] == "text" ? 5 : "bad")
			nomads_reject(bad, "invalid subtype type accepted: [profile] [key]")
		if(profile in list(/obj/map_metadata/nomads/mountain, /obj/map_metadata/nomads/ice_age))
			var/list/bad = nomads_copy(state)
			var/list/environment = bad["environment"]
			environment["season"] = profile == /obj/map_metadata/nomads/mountain ? "Dry Season" : "WINTER"
			nomads_reject(bad, "mismatched custom calendar accepted: [profile]")
		for(var/corruption in list("missing-profile", "future-version", "extra-field", "bad-root", "names", "respawn", "nuke-target"))
			var/list/bad = nomads_copy(state)
			var/list/bad_profile = bad["nomads_profile"]
			var/list/bad_fields = bad_profile["fields"]
			if(corruption == "missing-profile") bad -= "nomads_profile"
			if(corruption == "future-version") bad_profile["version"] = 2
			if(corruption == "extra-field") bad_fields["unexpected"] = bad_fields["hasnukes"]
			if(corruption == "bad-root") bad_fields["hasnukes"] = 999999
			if(corruption == "names") bad_profile["civilization_names"] = list("incomplete")
			if(corruption == "respawn") bad_profile["no_respawn_delays"] = "yes"
			if(corruption == "nuke-target")
				var/list/bad_nodes = bad["nodes"]
				bad_nodes[bad_fields["nomads_nuke_x"]] = list("kind" = "value", "value" = 100000)
			nomads_reject(bad, "profile corruption accepted: [profile] [corruption]")
	for(var/corruption in list("map", "callback", "environment"))
		var/list/bad = nomads_copy(state)
		if(corruption == "map") bad["map_type"] = "/obj/map_metadata/nomads/future_probe"
		if(corruption == "callback")
			var/list/timers = bad["timers"]
			timers["not_an_allowed_callback"] = 10
		if(corruption == "environment")
			var/list/environment = bad["environment"]
			environment["season"] = "unknown"
		nomads_reject(bad, "mismatched profile state accepted: [profile] [corruption]")
	nomads_assert(md5(file(path)) == original_hash, "source metadata file modified")
	Q.cancel_all()
	text2file("profile [index] [profile] passed", "profiles.log")
/proc/nomads_calendar_and_timer_tests()
	del(map)
	map = new /obj/map_metadata/nomads/desert(locate(1,1,1))
	var/datum/durable_timer_queue/Q = map.durable_timer_queue()
	Q.cancel_all()
	season = "SPRING"
	Q.schedule("nomads_initial_climate", 2)
	Q.restore(list("nomads_initial_climate" = 6))
	persistence_save_in_progress = FALSE
	sleep(3)
	nomads_assert(nomads_climate_calls == 0 && season == "SPRING", "old map callback survived restoration")
	sleep(5)
	nomads_assert(nomads_climate_calls == 1 && season == "Wet Season", "restored climate callback did not fire once")
	Q.restore(list("nomads_initial_climate" = 1))
	Q.restore(list("nomads_initial_climate" = 3))
	sleep(4)
	nomads_assert(nomads_climate_calls == 2, "repeated map restore duplicated callbacks")
	persistence_save_in_progress = TRUE
	Q.restore(list("nomads_initial_climate" = 1))
	sleep(3)
	nomads_assert(nomads_climate_calls == 2, "callback fired during save ownership")
	persistence_save_in_progress = FALSE
	sleep(3)
	nomads_assert(nomads_climate_calls == 3, "deferred map callback was lost")
	Q.schedule("nomads_initial_climate", 1)
	Q.cancel_all()
	sleep(2)
	nomads_assert(nomads_climate_calls == 3, "cancelled map callback fired")
	del(map)
	map = new /obj/map_metadata/nomads/mountain(locate(1,1,1))
	map.durable_timer_queue().cancel_all()
	map.season_loop_scheduled = FALSE
	var/turf/T = locate(2,2,1)
	T = T.ChangeTurf(/turf/floor/beach/water/swamp)
	map.seasons(TRUE, TRUE, TRUE)
	nomads_assert(season == "Dry Season" && map:real_season == "dry" && istype(locate(2,2,1), /turf/floor/beach/drywater), "Mountain dry transition")
	var/list/timers = map.durable_timer_queue().snapshot()
	nomads_assert(timers["season_loop"] == 18000, "Mountain independent cadence")
	map.seasons(FALSE, TRUE, FALSE)
	nomads_assert(season == "Wet Season" && map:real_season == "wet" && istype(locate(2,2,1), /turf/floor/beach/water/swamp), "Mountain wet transition")
	map.durable_timer_queue().cancel_all()
	del(map)
	map = new /obj/map_metadata/nomads/ice_age(locate(1,1,1))
	map.durable_timer_queue().cancel_all()
	map:real_season = "SUMMER"
	T = locate(3,3,1)
	T.ChangeTurf(/turf/floor/beach/water/shallowsaltwater)
	map.seasons(TRUE, TRUE, TRUE)
	timers = map.durable_timer_queue().snapshot()
	nomads_assert(season == "WINTER" && timers["season_loop"] == 27000 && timers["nomads_ice_weather"] == 100 && timers["nomads_ice_water"] == 800, "Ice Age winter deadlines")
	var/old_epoch = map.season_epoch
	map.durable_nomads_ice_water_phase(old_epoch)
	nomads_assert(istype(locate(3,3,1), /turf/floor/beach/water/ice/salty), "Ice Age freeze phase")
	map.seasons(TRUE, TRUE, TRUE)
	timers = map.durable_timer_queue().snapshot()
	nomads_assert(season == "SUMMER" && timers["season_loop"] == 9000 && timers["nomads_ice_weather"] == 150 && timers["nomads_ice_water"] == 1500, "Ice Age summer deadlines")
	map.durable_nomads_ice_water_phase(old_epoch)
	nomads_assert(istype(locate(3,3,1), /turf/floor/beach/water/ice/salty), "obsolete Ice Age phase mutated terrain")
	map.durable_timer_queue().cancel_all()
	persistence_save_in_progress = TRUE
	del(map)
	map = new /obj/map_metadata/nomads/wasteland(locate(1,1,1))
	map.durable_timer_queue().cancel_all()
	map.nomads_nuke_x = 1
	map.nomads_nuke_y = 1
	map.nomads_nuke_z = 1
	nomads_inject_nuke_failure = TRUE
	var/failed = FALSE
	try
		map.durable_nomads_nuke_fire()
	catch
		failed = TRUE
	nomads_assert(failed && map.nomads_event_busy, "mutating event failure cleared save barrier")
	failed = FALSE
	try
		nomads_capture()
	catch
		failed = TRUE
	nomads_assert(failed, "failed mutating event admitted metadata capture")

/proc/nomads_spatial_roundtrip(profile)
	season = "SPRING"
	map = new profile(locate(1,1,1))
	map.durable_timer_queue().cancel_all()
	map.persistence = TRUE
	map.default_research = 91.25
	map.faction_renames = list("spatial" = "kept")
	map.durable_schedule("tips", 60000)
	var/obj/structure/bed/B = new(locate(3,3,2))
	B.persistence_bed_owner_ckey = "fixtureowner"
	B.anchored = TRUE
	var/obj/structure/nomads_fixture_box/box = new(locate(2,2,1))
	new /obj/item/nomads_fixture_token(box)
	var/list/shared = list("kept")
	shared += list(shared)
	box.ledger = list("one" = shared, "two" = shared)
	nomads_assert(map_storage.Save_World(), "full spatial save: [profile] [map_storage.last_error]")
	var/original_marker = file2text("map_saves/save_complete.txt")
	var/original_round = file2text("map_saves/round.json")
	nomads_assert(fcopy("map_saves/round.json", "original-round.json"), "synthetic generation copy failed")
	var/list/round_state = json_decode(original_round)
	nomads_assert(round_state["version"] == 2 && round_state["map"] == map.ID, "full save profile identity")
	var/list/world_state = round_state["world_state"]
	world_state["map_type"] = "/obj/map_metadata/nomads/future_probe"
	fdel("map_saves/round.json")
	text2file(json_encode(round_state), "map_saves/round.json")
	nomads_assert(!map_storage.validate_world_save() && B.loc == locate(3,3,2) && box.loc == locate(2,2,1), "mismatched spatial save mutated world")
	fdel("map_saves/round.json")
	nomads_assert(fcopy("original-round.json", "map_saves/round.json"), "synthetic generation restoration failed")
	var/datum/persistence_world_operation/operation = begin_persistence_operation(map_storage, "load")
	nomads_assert(operation && map_storage.validate_world_save(), "full spatial preflight: [map_storage.last_error]")
	map_storage.suspend_durable_world()
	map_storage.ClearMap()
	nomads_assert(map_storage.run_world_operation("load", operation) && map_storage.load_map_metadata(), "full spatial import: [map_storage.last_error]")
	map_storage.restore_durable_world()
	nomads_assert(operation.finish(TRUE), "full spatial ownership release")
	nomads_assert(map.default_research == 91.25 && map.persistence && map.faction_renames["spatial"] == "kept", "full spatial metadata restore")
	B = locate(/obj/structure/bed) in locate(3,3,2)
	box = locate(/obj/structure/nomads_fixture_box) in locate(2,2,1)
	nomads_assert(B && B.persistence_bed_owner_ckey == "fixtureowner" && box && (locate(/obj/item/nomads_fixture_token) in box), "nested objects and bed ownership restored")
	var/list/one = box.ledger["one"]
	nomads_assert(one == box.ledger["two"] && one[2] == one, "saved alias/cycle changed")
	var/mob/living/human/H = new /mob/living/human/nomads_fixture_body(locate(4,4,1))
	H.persistence_owner_ckey = "fixtureowner"
	var/list/bed_debug = list()
	for(var/obj/structure/bed/candidate in world)
		bed_debug += "[candidate.persistence_bed_owner_ckey]:[candidate.x],[candidate.y],[candidate.z] valid=[candidate.valid_character_bed(H)] gc=[candidate.gc_destroyed],[candidate.gcDestroyed] anchor=[candidate.anchored] lying=[candidate.buckle_lying] density=[candidate.density]"
	nomads_assert(map_storage.character_return_turf(H) == get_turf(B), "owned bed return did not select restored bed [json_encode(bed_debug)]")
	B.anchored = FALSE
	nomads_assert(map_storage.character_return_turf(H) == get_turf(H), "unsafe bed did not use safe fallback")
	nomads_assert(file2text("map_saves/save_complete.txt") == original_marker && file2text("map_saves/round.json") == original_round, "import rewrote generation identity")
	map.durable_timer_queue().cancel_all()
	text2file("PASS: [nomads_checks] assertions; full spatial roundtrip [profile]", "result.txt")
/world/New()
	OpenPort("none")
	try
		config = new
		config.webhook_can_fire = FALSE
		config.ToRban = FALSE
		ticker = new /datum/controller/gameticker
		processes.time_of_day = new
		processes.weather = new
		// Normal startup is disabled; register the real GC so qdel does not
		// retain retired beds in the bootstrap-only delayed_garbage list.
		processes.garbage = new
		processes.garbage.setup()
		time_of_day = "Morning"
		times_of_day = list("Morning")
		game_hour = 9
		global.game_id = "nomads-synthetic-fixture"
		var/spatial = text2num(world.params["spatial"])
		if(spatial)
			var/list/profiles = durable_nomads_profiles()
			nomads_assert(spatial == round(spatial) && spatial >= 1 && spatial <= profiles.len, "invalid spatial fixture selector")
			nomads_spatial_roundtrip(profiles[spatial])
			del(world)
			return
		// No callback can fire while corruption and restoration assertions run.
		persistence_save_in_progress = TRUE
		map = new /obj/map_metadata/nomads(locate(1,1,1))
		nomads_assert(map.uses_durable_metadata(), "unsupported registered profile: /obj/map_metadata/nomads")
		var/index = 0
		for(var/profile in durable_nomads_profiles()) nomads_profile_test(profile, ++index)
		nomads_assert(index == 26, "audited profile count differs")
		nomads_calendar_and_timer_tests()
		del(map)
		map = new /obj/map_metadata/nomads/future_probe(locate(1,1,1))
		nomads_assert(!map.uses_durable_metadata() && !persistence_bed_return_enabled() && !persistence_restart.supported(), "unknown descendant inherited recovery")
		nomads_assert(world.port == 0 && !world.OpenPort(0), "fixture listener reopened")
		text2file("PASS: [nomads_checks] assertions; 26 profile metadata disk roundtrips", "result.txt")
	catch(var/exception/E)
		text2file("FAIL: [E] at [E.file]:[E.line]", "result.txt")
	del(world)
