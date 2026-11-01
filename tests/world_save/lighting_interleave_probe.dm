// Isolated fixture source. The adapter changes only the two lighting loop sites.
/obj/map_metadata/subtile_fixture
	ID = "lighting-interleave-fixture"

/obj/item/lighting_interleave_target
	light_range = 2
	light_power = 1
	var/tmp/fixture_destroyed = FALSE
	var/tmp/fixture_hard_delete_now = FALSE

/obj/item/lighting_interleave_target/Destroy()
	var/hard_delete_now = fixture_hard_delete_now
	..()
	fixture_destroyed = TRUE
	if(hard_delete_now) return QDEL_HINT_HARDDEL_NOW
	return QDEL_HINT_HARDDEL

var/global/lighting_interleave_case
var/global/lighting_interleave_phase
var/global/lighting_interleave_done = FALSE
var/global/lighting_interleave_mutated = FALSE
var/global/lighting_interleave_omit_guard = FALSE
var/global/atom/lighting_interleave_target
var/global/list/lighting_interleave_seen = list()
var/global/list/lighting_interleave_snapshot = list()
var/global/list/lighting_interleave_opacity_seen = list()
var/global/list/lighting_interleave_light_seen = list()
var/global/list/lighting_interleave_events = list()
var/global/lighting_interleave_target_calls = 0
var/global/lighting_interleave_null_calls = 0
var/global/lighting_interleave_hardnull = FALSE
var/global/lighting_interleave_light_started = FALSE
var/global/lighting_interleave_opacity_calls = 0
var/global/lighting_interleave_light_calls = 0

/proc/lighting_interleave_assert(ok, label)
	if(!ok) throw EXCEPTION(label)

/proc/lighting_interleave_record(phase, atom/A)
	if(!A) lighting_interleave_null_calls++
	if(phase == "light")
		lighting_interleave_light_started = TRUE
		lighting_interleave_light_calls++
		lighting_interleave_light_seen |= A
	else
		lighting_interleave_opacity_calls++
		lighting_interleave_opacity_seen |= A
	if(phase == "opacity" && lighting_interleave_light_started) throw EXCEPTION("opacity after light")
	lighting_interleave_seen |= A
	if(A == lighting_interleave_target) lighting_interleave_target_calls++
	lighting_interleave_events += phase

/proc/lighting_interleave_mutate(map_storage/storage, level)
	switch(lighting_interleave_case)
		if("qdel", "omitted_guard")
			lighting_interleave_assert(lighting_interleave_target.light, "target has no initial light")
			qdel(lighting_interleave_target)
			lighting_interleave_assert(lighting_interleave_target && !lighting_interleave_target.light, "qdel did not clear light")
		if("hard_null")
			var/index = storage.all_loaded.Find(lighting_interleave_target)
			var/original_length = storage.all_loaded.len
			lighting_interleave_assert(index && lighting_interleave_target, "hard-delete target missing")
			var/obj/item/lighting_interleave_target/hard_target = lighting_interleave_target
			hard_target.fixture_hard_delete_now = TRUE
			qdel(hard_target)
			lighting_interleave_hardnull = !lighting_interleave_target && storage.all_loaded.len == original_length && isnull(storage.all_loaded[index])
			lighting_interleave_assert(lighting_interleave_hardnull, "pending entry did not become hard null")
		if("atom_legacy", "turf_legacy")
			lighting_interleave_target.gcDestroyed = world.time + 1
		if("atom_new", "turf_new")
			lighting_interleave_target.gc_destroyed = GC_QUEUED_FOR_QUEUING
		if("replace_list")
			storage.all_loaded = list()
		if("change_level")
			storage.loading_z = level + 1
		if("positive")
			// No world mutation.
		else
			throw EXCEPTION("Unknown interleaving case")
	lighting_interleave_events += "mutation"
	lighting_interleave_mutated = TRUE

/proc/lighting_interleave_checkpoint(map_storage/storage, datum/persistence_world_operation/owner, phase, level)
	if(lighting_interleave_done || phase != lighting_interleave_phase) return FALSE
	lighting_interleave_done = TRUE
	lighting_interleave_assert(owner.current(storage, "load"), "checkpoint owner")
	lighting_interleave_snapshot = storage.all_loaded.Copy()
	if(lighting_interleave_case in list("qdel", "hard_null", "omitted_guard", "atom_legacy", "atom_new"))
		for(var/obj/item/lighting_interleave_target/A in storage.all_loaded)
			lighting_interleave_target = A
			break
	else if(lighting_interleave_case in list("turf_legacy", "turf_new"))
		for(var/turf/T in storage.all_loaded)
			if(!(T in lighting_interleave_seen)) lighting_interleave_target = T
	if(lighting_interleave_case in list("qdel", "hard_null", "omitted_guard", "atom_legacy", "atom_new", "turf_legacy", "turf_new"))
		lighting_interleave_assert(lighting_interleave_target && !(lighting_interleave_target in lighting_interleave_seen), "target not pending")
	lighting_interleave_events += "before_sleep"
	spawn(0) lighting_interleave_mutate(storage, level)
	sleep(world.tick_lag)
	lighting_interleave_events += "after_sleep"
	lighting_interleave_assert(lighting_interleave_mutated, "scheduled mutation did not run during sleep")
	return TRUE

/proc/lighting_interleave_reset(case_name)
	lighting_interleave_case = case_name
	if(case_name in list("turf_legacy", "turf_new", "replace_list", "change_level"))
		lighting_interleave_phase = "opacity"
	else
		lighting_interleave_phase = "light"
	lighting_interleave_done = FALSE
	lighting_interleave_mutated = FALSE
	lighting_interleave_omit_guard = case_name == "omitted_guard"
	lighting_interleave_target = null
	lighting_interleave_seen = list()
	lighting_interleave_snapshot = list()
	lighting_interleave_opacity_seen = list()
	lighting_interleave_light_seen = list()
	lighting_interleave_events = list()
	lighting_interleave_target_calls = 0
	lighting_interleave_null_calls = 0
	lighting_interleave_hardnull = FALSE
	lighting_interleave_light_started = FALSE
	lighting_interleave_opacity_calls = 0
	lighting_interleave_light_calls = 0

/proc/lighting_interleave_case_run(case_name)
	map_storage.ClearMap()
	lighting_interleave_reset(case_name)
	var/ok = map_storage.Load_World()
	lighting_interleave_assert(lighting_interleave_done && lighting_interleave_mutated, "missing interleaving")
	lighting_interleave_assert(lighting_interleave_events.Find("before_sleep") < lighting_interleave_events.Find("mutation") && lighting_interleave_events.Find("mutation") < lighting_interleave_events.Find("after_sleep"), "interleaving order")
	if(case_name in list("replace_list", "change_level"))
		lighting_interleave_assert(!ok && persistence_load_recovery_required && persistence_save_in_progress && !persistence_active_operation, "owned failure hold")
		lighting_interleave_assert(findtext(map_storage.last_error, "Load ownership changed during lighting restoration"), "wrong failure")
		lighting_interleave_assert(!map_storage.all_loaded.len, "failure bookkeeping retained")
		// Fixture-only reset between independent cases; never a production recovery.
		persistence_load_recovery_required = FALSE
		persistence_save_in_progress = FALSE
	else
		lighting_interleave_assert(ok && !persistence_load_recovery_required && !persistence_active_operation, "restore failed")
		lighting_interleave_assert(lighting_interleave_opacity_calls && lighting_interleave_light_calls, "lighting pass missing")
		if(case_name == "positive")
			var/obj/item/lighting_interleave_target/live = locate(/obj/item/lighting_interleave_target) in locate(3,3,1)
			lighting_interleave_assert(live && live.light && live.light.source_atom == live, "live light not restored")
			var/expected_opacity = 0
			var/expected_lights = 0
			for(var/turf/T in lighting_interleave_snapshot)
				if(!QDELETED(T) && !T.gcDestroyed)
					expected_opacity++
					lighting_interleave_assert(T in lighting_interleave_opacity_seen, "opacity entry omitted")
			for(var/atom/A in lighting_interleave_snapshot)
				if(!QDELETED(A) && !A.gcDestroyed)
					expected_lights++
					lighting_interleave_assert(A in lighting_interleave_light_seen, "light entry omitted")
			lighting_interleave_assert(lighting_interleave_opacity_calls == expected_opacity && lighting_interleave_light_calls == expected_lights, "duplicate lighting callbacks")
		if(case_name == "qdel" || case_name == "omitted_guard")
			var/obj/item/lighting_interleave_target/A = lighting_interleave_target
			lighting_interleave_assert(A && A.fixture_destroyed && (A.gcDestroyed || A.gc_destroyed), "target not retained retired")
			if(case_name == "qdel")
				lighting_interleave_assert(!lighting_interleave_target_calls && !A.light, "retired light callback")
			else
				lighting_interleave_assert(lighting_interleave_target_calls && A.light, "guard omission not detected")
				A.light.destroy()
				A.light = null
		else if(case_name == "hard_null")
			lighting_interleave_assert(lighting_interleave_hardnull && !lighting_interleave_target && !lighting_interleave_null_calls, "hard-null callback")
		else if(lighting_interleave_target)
			lighting_interleave_assert(!lighting_interleave_target_calls, "retired entry callback")
			lighting_interleave_target.gcDestroyed = 0
			lighting_interleave_target.gc_destroyed = 0
	return TRUE

/world/New()
	OpenPort("none")
	var/list/result = list("phase" = world.params["phase"], "head" = world.params["tested_commit"], "version" = byond_version, "build" = byond_build, "port" = port, "ok" = FALSE, "cases" = list())
	try
		lighting_interleave_assert(!port && byond_version == 516 && byond_build == 1688, "engine or port")
		human_subtile_fixture_initialize()
		global.game_id = "lighting-interleave-round"
		if(world.params["phase"] == "writer")
			new /obj/item/lighting_interleave_target(locate(3,3,1))
			lighting_interleave_assert(map_storage.Save_World(), "writer save")
			result["generation"] = trim(file2text("map_saves/save_complete.txt"))
			lighting_interleave_assert(length(result["generation"]), "writer generation")
		else if(world.params["phase"] == "reader")
			result["generation"] = trim(file2text("map_saves/save_complete.txt"))
			lighting_interleave_assert(length(result["generation"]), "reader generation")
			for(var/case_name in list("positive", "qdel", "hard_null", "atom_legacy", "atom_new", "turf_legacy", "turf_new", "omitted_guard", "replace_list", "change_level"))
				lighting_interleave_case_run(case_name)
				result["cases"] += case_name
		else
			throw EXCEPTION("Unknown fixture phase")
		result["ok"] = TRUE
	catch(var/exception/E)
		result["error"] = "[E]"
		result["case"] = lighting_interleave_case
		result["selected_phase"] = lighting_interleave_phase
		result["checkpoint_done"] = lighting_interleave_done
		result["mutation_done"] = lighting_interleave_mutated
		result["events"] = lighting_interleave_events
	text2file(json_encode(result), "lighting-interleave-result.json")
	del(world)
