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
var/nomads_event_fixture = FALSE
var/nomads_fail_radiation = FALSE
var/nomads_fail_calendar = FALSE
var/nomads_fail_explosion = FALSE
var/nomads_child_explosion = FALSE
var/datum/durable_nomads_event/nomads_test_event
/obj/map_metadata/nomads/wasteland/durable_nomads_nuke_effect(turf/epicenter, datum/durable_nomads_event/event)
	if(nomads_inject_nuke_failure) throw EXCEPTION("Injected mutating-event failure")
	if(nomads_event_fixture)
		nomads_test_event = event
		return nuke_map(epicenter, 1, 30, FALSE, event)
	return ..()
/turf/floor/nomads_radiation_fault/rad_act(amount)
	if(nomads_fail_radiation) throw EXCEPTION("Injected delayed radiation failure")
	return ..()
/process/explosion/nomads_fixture/explosion(datum/explosiondata/data)
	// Production queue ownership, with bounded blast effects. Deliberately yield
	// so an empty queue or elapsed deadline cannot masquerade as completion.
	if(nomads_child_explosion)
		nomads_child_explosion = FALSE
		call(/proc/explosion)(data.epicenter, 0, 0, 0, 0, FALSE, 0, FALSE, null, FALSE)
	sleep(20)
	if(nomads_fail_explosion) throw EXCEPTION("Injected queued explosion failure")
/process/explosion/nomads_fixture/explosion_rec(turf/epicenter, power, sound)
	sleep(20)
/datum/durable_nomads_event/fast_lava/defer(delay, datum/target, method, list/arguments)
	return ..(max(1, round(delay / 100)), target, method, arguments)
/turf/floor/lava/nomads_failure/lava_dry_phase()
	..()
	throw EXCEPTION("Injected delayed lava drying failure")
/obj/map_metadata/nomads/mountain/durable_nomads_replace(old_type, new_type, epoch, chance = 100)
	. = ..()
	if(nomads_fail_calendar) throw EXCEPTION("Injected partial Mountain transition")
/obj/map_metadata/nomads/ice_age/durable_nomads_replace(old_type, new_type, epoch, chance = 100)
	. = ..()
	if(nomads_fail_calendar) throw EXCEPTION("Injected partial Ice Age phase")
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
	persistence_restart.startup_hold = TRUE
	Q.restore(list("nomads_initial_climate" = 1))
	sleep(3)
	nomads_assert(nomads_climate_calls == 3, "callback fired during startup recovery hold")
	persistence_restart.startup_hold = FALSE
	sleep(3)
	nomads_assert(nomads_climate_calls == 4, "startup-held callback did not resume once")
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

/proc/nomads_assert_event_barrier(message)
	nomads_assert(map.nomads_event_busy, message + " flag")
	var/rejected = FALSE
	try
		nomads_capture()
	catch
		rejected = TRUE
	nomads_assert(rejected, message + " save")
	map_storage.durable_state = null
	rejected = FALSE
	try
		map_storage.require_durable_world_idle()
	catch
		rejected = TRUE
	nomads_assert(rejected, message + " legacy import")
	map_storage.durable_state = list("fixture" = TRUE)
	rejected = FALSE
	try
		map_storage.require_durable_world_idle()
	catch
		rejected = TRUE
	map_storage.durable_state = null
	nomads_assert(rejected, message + " import")

/proc/nomads_event_tests()
	nomads_event_fixture = TRUE
	var/turf/floor/lava/permanent/compat = new(locate(4,4,2), /decl/flooring/grass)
	nomads_assert(compat.flooring == get_flooring_data(/decl/flooring/grass), "lava constructor lost inherited flooring argument")
	compat.ChangeTurf(/turf/floor)
	processes.callproc = new
	processes.explosion = new /process/explosion/nomads_fixture
	processes.explosion.setup()
	persistence_save_in_progress = TRUE
	map = new /obj/map_metadata/nomads/wasteland(locate(1,1,2))
	map.durable_timer_queue().cancel_all()
	map.nomads_nuke_x = 1
	map.nomads_nuke_y = 1
	map.nomads_nuke_z = 1
	new /turf/floor/nomads_radiation_fault(locate(4,4,1))
	for(var/failure in list(FALSE, TRUE))
		nomads_fail_radiation = FALSE
		var/start = world.time
		map.durable_nomads_nuke_fire()
		var/datum/durable_nomads_event/event = nomads_test_event
		nomads_assert(event && event.pending >= 9, "nuke lost delayed or explosion work")
		nomads_assert_event_barrier("nuke returned with pending descendants")
		// Service the real queued handoff; blast adapter yields for 20 ticks.
		sleep(2)
		processes.callproc.fire()
		nomads_assert(processes.explosion.work_queue.len, "nuke explosion was not queued")
		processes.explosion.fire()
		nomads_assert_event_barrier("after explosion before delayed fallout")
		while(world.time < start + 66) sleep(1)
		nomads_assert(event.pending > 0, "recursive radiation tail was not retained")
		nomads_assert_event_barrier("after final direct phase during radiation tail")
		nomads_fail_radiation = failure
		var/deadline = world.time + 400
		while(event.pending && world.time < deadline) sleep(1)
		nomads_assert(!event.pending, "nuke work did not drain")
		nomads_assert(event.failed == failure, "delayed failure result was lost")
		if(failure)
			nomads_assert_event_barrier("delayed failure drained but requires recovery")
		else
			nomads_assert(!map.nomads_event_busy, "successful nuke never released barrier")
			nomads_capture()
			nomads_assert(map_storage.durable_export, "successful nuke could not capture metadata")
	nomads_fail_radiation = FALSE
	del(map)
	map = new /obj/map_metadata/nomads/wasteland(locate(1,1,2))
	map.durable_timer_queue().cancel_all()
	var/datum/durable_nomads_event/queued_event = new(map)
	nomads_child_explosion = TRUE
	call(/proc/explosion)(locate(1,1,1), 0, 0, 0, 0, FALSE, 0, FALSE, null, FALSE, queued_event)
	queued_event.release()
	sleep(2)
	processes.callproc.fire()
	processes.explosion.fire()
	nomads_assert(!processes.explosion.work_queue.len && queued_event.pending == 1, "queued child handoff did not retain explosion ownership")
	nomads_assert_event_barrier("empty explosion queue with child handoff outstanding")
	sleep(2)
	processes.callproc.fire()
	processes.explosion.fire()
	nomads_assert(!queued_event.pending && !map.nomads_event_busy, "child explosion completion did not release barrier")
	queued_event = new(map)
	nomads_fail_explosion = TRUE
	call(/proc/explosion)(locate(1,1,1), 0, 0, 0, 0, FALSE, 0, FALSE, null, FALSE, queued_event)
	queued_event.release()
	sleep(2)
	processes.callproc.fire()
	var/explosion_failed = FALSE
	try
		processes.explosion.fire()
	catch
		explosion_failed = TRUE
	nomads_fail_explosion = FALSE
	nomads_assert(explosion_failed && queued_event.failed && !queued_event.pending && !processes.explosion.work_queue.len && !processes.explosion.nomads_event, "failed explosion lost or duplicated completion")
	processes.explosion.fire()
	nomads_assert_event_barrier("failed explosion requires recovery")
	// Fresh metadata is explicit recovery; the failed original is never cleared.
	del(map)
	map = new /obj/map_metadata/nomads/africa(locate(1,1,2))
	map.durable_timer_queue().cancel_all()
	var/datum/durable_nomads_event/event = new /datum/durable_nomads_event/fast_lava(map)
	var/area/lava_area = new /area/caribbean/nomads/forest/Jungle/lava_east
	for(var/turf/T in block(locate(1,1,1), locate(4,4,1))) ChangeArea(T, lava_area)
	var/turf/wall/rockwall/lavaspawner/source = new(locate(1,1,1))
	map.volcano_eruption(event)
	event.release()
	nomads_assert_event_barrier("eruption returned with lava descendants")
	var/deadline = world.time + 250
	var/spread_seen = FALSE
	while(event.pending && world.time < deadline)
		var/count = 0
		for(var/turf/floor/lava/L in world) count++
		if(count > 4) spread_seen = TRUE
		sleep(1)
	nomads_assert(spread_seen, "production lava descendants did not spread")
	nomads_assert(!event.pending && !event.failed && !map.nomads_event_busy, "lava drying did not complete ownership")
	nomads_assert(istype(locate(4,4,1), /turf/floor/dirt/dry_lava), "lava descendant did not dry")
	nomads_capture()
	nomads_assert(map_storage.durable_export, "completed eruption could not capture")
	nomads_assert(source, "lava source lost unexpectedly")
	event = new /datum/durable_nomads_event/fast_lava(map)
	new /turf/floor/lava/nomads_failure(locate(3,3,1), null, event)
	event.release()
	deadline = world.time + 250
	while(event.pending && world.time < deadline) sleep(1)
	nomads_assert(!event.pending && event.failed, "delayed lava failure was not retained after drain")
	nomads_assert_event_barrier("failed lava drying requires recovery")
	// Reset synthetic terrain before the independent calendar assertions so lava
	// admission cannot account for their save/import rejection.
	for(var/turf/floor/lava/L in world) L.ChangeTurf(/turf/floor/dirt/dry_lava)
	// Actual terrain mutation precedes the injected error in both profiles.
	for(var/profile in list(/obj/map_metadata/nomads/mountain, /obj/map_metadata/nomads/ice_age))
		del(map)
		map = new profile(locate(1,1,2))
		map.durable_timer_queue().cancel_all()
		var/turf/target = locate(3,3,2)
		if(profile == /obj/map_metadata/nomads/mountain)
			map:real_season = "dry"
			target.ChangeTurf(/turf/floor/beach/drywater)
		else
			map:real_season = "WINTER"
			target.ChangeTurf(/turf/floor/beach/water/shallowsaltwater)
		var/failed = FALSE
		nomads_fail_calendar = TRUE
		try
			if(profile == /obj/map_metadata/nomads/mountain)
				map.season_queue += list("nomads_transition", TRUE, TRUE, TRUE)
			else
				map.season_queue += list("durable_nomads_ice_water_phase", map.season_epoch, FALSE, FALSE)
			map.season_run_queue()
		catch
			failed = TRUE
		nomads_fail_calendar = FALSE
		nomads_assert(failed && !map.season_busy && !map.season_queue.len, "worker error did not retire normally")
		nomads_assert(profile == /obj/map_metadata/nomads/mountain ? istype(locate(3,3,2), /turf/floor/beach/water/swamp) : istype(locate(3,3,2), /turf/floor/beach/water/ice/salty), "injected failure did not follow terrain mutation")
		nomads_assert_event_barrier("partial calendar transition")
		nomads_assert(!map.durable_nomads_seasons(TRUE, TRUE, TRUE), "failed transition reentered")
	text2file("PASS: [nomads_checks] assertions; owned nuke/lava descendants and failed calendar recovery barriers", "result.txt")
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
		if(text2num(world.params["events"]))
			nomads_event_tests()
			del(world)
			return
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
