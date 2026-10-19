// Appended to the existing durable fixture's declarations. Each writer/reader
// is a fresh native process with the same compiled two-level world.
/world/New()
	world.OpenPort(0)
	try
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
