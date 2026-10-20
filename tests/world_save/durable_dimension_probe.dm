// Synthetic custody effects only; startup, import, dimensions and disk IO are production.
var/custody_reserve_calls = 0
var/custody_release_calls = 0
var/custody_failure_mutated = FALSE
/datum/persistence_restore_policy/durable_dimension
	begin_attempt(map_storage/storage)
		var/datum/persistence_restore_attempt/durable_dimension/A = new
		A.storage = storage
		A.policy = src
		return A
/datum/persistence_restore_attempt/durable_dimension
	before_mutation()
		custody_reserve_calls++
		durable_world_check(world.maxz == 2 && !persistence_restart.import_started, "startup custody reserved before growth")
		durable_world_check(persistence_active_operation && persistence_active_operation.storage == storage, "startup custody owns admitted storage")
		return world.params["dimension_mode"] != "custody-denied"
	fail(phase, original, mutation_started)
		custody_failure_mutated = mutation_started
		var/datum/persistence_restore_failure/F = new
		F.attempt = src
		F.recovery_retained = TRUE
		return F
	release_transients()
		custody_release_calls++
		return world.params["dimension_mode"] != "custody-release"

// Appended to the existing durable fixture's declarations. Each writer/reader
// is a fresh native process with the same compiled two-level world.
/world/New()
	world.OpenPort("none")
	try
		if(world.params["dimension_mode"] != "unmeasured")
			world_z_budget = new /datum/world_z_budget/fixture_admission
		map_storage.record_compiled_dimensions()
		config = new
		config.webhook_can_fire = FALSE
		config.ToRban = FALSE
		ticker = new
		global.game_id = "dimension-bootstrap-fixture"
		processes.time_of_day = new
		processes.weather = new
		var/map_type = world.params["profile"] == "europe" ? /obj/map_metadata/nomads/europe : /obj/map_metadata/nomads/gaia
		map = new map_type(locate(1,1,1))
		map.times_of_day = list("Morning", "Evening")
		times_of_day = map.times_of_day
		season = "SUMMER"
		time_of_day = "Evening"
		game_hour = 129
		if(world.params["dimension_mode"] == "unmeasured")
			var/unmeasured_header = file2text("map_saves/round.json")
			var/unmeasured_marker = file2text("map_saves/save_complete.txt")
			var/list/unmeasured_round = json_decode(unmeasured_header)
			var/list/unmeasured_identity = list("version" = 1, "generation" = unmeasured_round["generation"], "metadata" = md5(file2text("map_saves/map.txt")), "round" = md5(unmeasured_header))
			text2file(json_encode(unmeasured_identity), persistence_restart.intent_path)
			var/unmeasured_intent = file2text(persistence_restart.intent_path)
			persistence_restart.startup_hold = TRUE
			persistence_save_in_progress = TRUE
			durable_world_check(!persistence_restart.resume_startup(), "unmeasured restart admission accepted")
			durable_world_check(world.maxz == 2 && !building_allocating_z && !world_z_budget.active, "unmeasured restart allocated grid")
			durable_world_check(map_storage.dimension_budget_hold && !map_storage.dimension_recovery_required && persistence_restart.startup_hold && persistence_save_in_progress, "unmeasured restart lost preallocation hold")
			durable_world_check(!persistence_restart.import_started && !persistence_restart.import_complete, "unmeasured restart began import")
			durable_world_check(findtext(map_storage.last_error, "UNMEASURED:") > 0, "unmeasured restart diagnostic missing")
			durable_world_check(file2text(persistence_restart.intent_path) == unmeasured_intent && file2text("map_saves/round.json") == unmeasured_header && file2text("map_saves/save_complete.txt") == unmeasured_marker, "unmeasured restart changed intent or generation")
			durable_world_check(!map_storage.Save_World(), "unmeasured restart allowed save overwrite")
			text2file(json_encode(list("done" = !durable_probe_failed, "checks" = durable_probe_checks)), "metadata-result.json")
			del(world)
			return
		if(findtext(world.params["dimension_mode"], "custody-") == 1)
			var/custody_header = file2text("map_saves/round.json")
			var/custody_marker = file2text("map_saves/save_complete.txt")
			var/list/custody_round = json_decode(custody_header)
			var/list/custody_identity = list("version" = 1, "generation" = custody_round["generation"], "metadata" = md5(file2text("map_saves/map.txt")), "round" = md5(custody_header))
			text2file(json_encode(custody_identity), persistence_restart.intent_path)
			var/custody_intent = file2text(persistence_restart.intent_path)
			map_storage.restore_policy = new /datum/persistence_restore_policy/durable_dimension
			durable_world_check(persistence_restart.detect_startup(), "custody restart discovered intent")
			var/restored = persistence_restart.resume_startup()
			var/denied = world.params["dimension_mode"] == "custody-denied"
			var/success = world.params["dimension_mode"] == "custody-success"
			durable_world_check(restored == success, "combined startup custody result")
			durable_world_check(custody_reserve_calls == 1 && custody_release_calls == 1, "combined custody callback counts")
			durable_world_check(world.maxz == (denied ? 2 : 3), "combined startup dimension boundary")
			durable_world_check(persistence_restart.import_started == !denied, "combined startup mutation latch")
			durable_world_check(!persistence_active_operation, "combined startup released operation identity")
			durable_world_check(file2text("map_saves/round.json") == custody_header && file2text("map_saves/save_complete.txt") == custody_marker, "combined startup preserved generation")
			if(success)
				durable_world_check(persistence_restart.import_complete && !persistence_restart.exists() && !persistence_save_in_progress, "combined success consumed matching intent")
				var/mob/living/human/durable_probe_leader/restored_leader = locate(/mob/living/human/durable_probe_leader)
				durable_world_check(restored_leader && restored_leader.z == 3 && map.faction1_squad_leaders[7] == restored_leader, "combined import preserves upper durable alias")
			else
				durable_world_check(file2text(persistence_restart.intent_path) == custody_intent && persistence_restart.startup_hold && persistence_save_in_progress, "combined failure retains recovery intent")
				durable_world_check(persistence_load_recovery_required == !denied && custody_failure_mutated == !denied, "combined failure custody mutation boundary")
				if(!denied) durable_world_check(!persistence_restart.resume_startup() && custody_reserve_calls == 1, "mutating startup failure cannot retry")
			text2file(json_encode(list("done" = !durable_probe_failed, "checks" = durable_probe_checks)), "metadata-result.json")
			del(world)
			return
		var/operation_kind = world.params["dimension_mode"] == "write" ? "save" : "load"
		var/datum/persistence_world_operation/operation = begin_persistence_operation(map_storage, operation_kind)
		durable_world_check(operation && operation.current(map_storage, operation_kind), "expanded durable admission failed")
		if(world.params["dimension_mode"] == "write")
			durable_world_check(building_allocate_level(3, TRUE), "upper level writer allocation failed")
			var/turf/upper = locate(8,8,3)
			upper.name = "durable upper corner"
			new /obj/covers(locate(2,2,3)) // A real saved floor keeps the leader above open sky.
			var/mob/living/human/durable_probe_leader/leader = new(locate(2,2,3))
			leader.persistence_owner_ckey = "metadatafixture"
			map.faction1_squads[7] = list(leader)
			map.faction1_squad_leaders[7] = leader
			map.faction_research = list("upper" = upper, "area" = upper.loc)
			map.faction_research_director = list("first" = leader)
			durable_world_check(!map_storage.Save_World() && operation.current(map_storage, "save"), "nested expanded save admitted")
			durable_world_check(map_storage.run_world_operation("save", operation), "expanded durable export failed")
			durable_world_check(map_storage.validate_world_save(), "expanded writer validation failed: [map_storage.last_error]")
		else
			durable_world_check(world.maxz == 2 && map_storage.compiled_maxz == 2, "reader did not start with compiled dimensions")
			var/header = file2text("map_saves/round.json")
			var/list/state = json_decode(header)
			var/list/W = state["world_state"]
			var/list/nodes = W["nodes"]
			var/list/upper_node
			var/list/leader_node
			for(var/list/node in nodes)
				if(node["kind"] == "turf" && node["z"] == 3) upper_node = node
				if(node["kind"] == "entry" && node["z"] == 3) leader_node = node
			durable_world_check(upper_node && leader_node, "upper durable graph roots absent")
			upper_node["z"] = 4
			fdel("map_saves/round.json")
			text2file(json_encode(state), "map_saves/round.json")
			durable_world_check(!map_storage.prepare_saved_dimensions() && world.maxz == 2 && !map_storage.dimension_recovery_required, "malformed prospective turf allocated world")
			upper_node["z"] = 3
			leader_node["z"] = 4
			fdel("map_saves/round.json")
			text2file(json_encode(state), "map_saves/round.json")
			durable_world_check(!map_storage.prepare_saved_dimensions() && world.maxz == 2 && !map_storage.dimension_recovery_required, "malformed prospective entry allocated world")
			fdel("map_saves/round.json")
			text2file(header, "map_saves/round.json")
			durable_world_check(map_storage.prepare_saved_dimensions(), "expanded durable bootstrap rejected: [map_storage.last_error]")
			durable_world_check(world.maxz == 3 && istype(locate(8,8,3), /turf/sky/building), "shared durable allocator failed")
			durable_world_check(map_storage.validate_world_save(), "expanded exact durable validation failed")
			map_storage.suspend_durable_world()
			map_storage.ClearMap()
			durable_world_check(!map_storage.Load_World() && operation.current(map_storage, "load"), "nested expanded import admitted")
			durable_world_check(map_storage.run_world_operation("load", operation) && map_storage.load_map_metadata(), "expanded durable import failed")
			map_storage.restore_durable_world()
			var/mob/living/human/durable_probe_leader/leader = locate(/mob/living/human/durable_probe_leader)
			durable_world_check(leader && leader.z == 3 && leader.persistence_owner_ckey == "metadatafixture", "upper durable entry identity lost")
			durable_world_check(map.faction_research_director["first"] == leader && map.faction1_squad_leaders[7] == leader, "upper metadata entry alias lost")
			var/turf/upper = locate(8,8,3)
			durable_world_check(map.faction_research["upper"] == upper && map.faction_research["area"] == upper.loc && upper.name == "durable upper corner", "upper metadata location references lost")
			durable_world_check(season == "SUMMER" && game_hour == 129 && time_of_day == "Evening", "expanded environment state lost")
		durable_world_check(operation.finish(TRUE) && !persistence_active_operation && !persistence_save_in_progress, "expanded durable admission not released")
		text2file(json_encode(list("done" = !durable_probe_failed, "checks" = durable_probe_checks)), "metadata-result.json")
	catch(var/exception/e)
		text2file(json_encode(list("done" = FALSE, "checks" = durable_probe_checks, "error" = "[e]")), "metadata-result.json")
	del(world)
