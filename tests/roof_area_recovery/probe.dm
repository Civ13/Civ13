// PREPARED ONLY. Fresh writer and reader processes use synthetic fixture files.
// The normal production roof constructor, saver, validator and loader are used.
/obj/item/roof_area_fixture
	var/area/saved_area
	var/list/area_alias
	var/obj/roof/saved_roof

/world
	visibility = 0

/world/OpenPort(port)
	return ..("none")
/client/New()
	del(src)

/world/New()
	OpenPort("none")
	try
		config = new
		config.webhook_can_fire = FALSE
		config.ToRban = FALSE
		ticker = new
		processes.time_of_day = new
		processes.weather = new
		map = new /obj/map_metadata/nomads/gaia(locate(1,1,1))
		map.times_of_day = list("Morning", "Evening")
		times_of_day = map.times_of_day
		season = "SUMMER"
		time_of_day = "Evening"
		global.game_id = "synthetic-roof-area-generation"
		var/area/caribbean/nomads/semiarid/base = new
		for(var/turf/T in world) ChangeArea(T, base)
		var/mode = world.params["roof_mode"]
		durable_world_check(mode in list("write", "read", "missing-roof", "wrong-base", "missing-scalar", "disabled-roof", "unrelated-area", "duplicate-area"), "Unknown roof fixture mode")
		if(mode == "write")
			// This item is visited before its referenced roof turf. Nested list
			// keys/values and aliases must resolve to the SAME reconstructed area.
			var/obj/item/roof_area_fixture/item = new(locate(1,1,1))
			new /obj/structure/roof_support(locate(3,3,1))
			var/obj/roof/wood/roof = new(locate(3,3,1))
			durable_world_check(istype(get_area(roof), /area/caribbean/roofed/semiarid), "Actual roof constructor did not create a roofed area")
			var/obj/roof/wood/second_roof = new(locate(4,3,1))
			durable_world_check(get_area(second_roof) == get_area(roof), "Actual roofs do not share the canonical climate area")
			item.saved_area = get_area(roof)
			item.area_alias = list(item.saved_area, "nested" = list(item.saved_area))
			item.area_alias[item.saved_area] = "area-key"
			item.saved_roof = roof
			var/area/roof_area = get_area(roof)
			roof_area.artillery_integrity = 47
			map.faction_research = list("roof_area" = get_area(roof))
			var/datum/persistence_world_operation/op = begin_persistence_operation(map_storage, "save")
			durable_world_check(op && map_storage.run_world_operation("save", op), "Synthetic roof export failed")
			durable_world_check(op.finish(TRUE), "Synthetic save admission not released")
			durable_world_check(map_storage.validate_world_save(), "Saved roof writer validation failed: [map_storage.last_error]")
		else
			var/area/before_area = get_area(locate(3,3,1))
			var/list/state = map_storage.read_round_state()
			var/generation = state["generation"]
			var/list/W = state["world_state"]
			var/savefile/F = new("map_saves/1.sav")
			var/turf_ref = F["/map/1/3/3"]
			var/turf_path = map_storage.entry_path(F, turf_ref)
			var/list/contents = params2list(F["[turf_path]/content"])
			var/roof_ref
			for(var/ref in contents)
				if(ispath(F["[map_storage.entry_path(F, ref)]/type"], /obj/roof)) roof_ref = ref
			durable_world_check(roof_ref, "Synthetic saved roof absent")
			var/roof_path = map_storage.entry_path(F, roof_ref)
			if(mode == "missing-roof") F["[turf_path]/content"] << ""
			if(mode == "wrong-base") F["[roof_path]/current_area_type"] << list("kind" = "value", "value" = /area/caribbean/nomads/desert)
			if(mode == "missing-scalar") F["[roof_path]/switch_area"] << list("kind" = "entry", "ref" = roof_ref)
			if(mode == "disabled-roof") F["[roof_path]/switch_area"] << list("kind" = "value", "value" = FALSE)
			if(mode in list("unrelated-area", "duplicate-area"))
				var/list/rows = W["areas"]
				if(mode == "duplicate-area") rows += list(rows[rows.len].Copy())
				else
					for(var/list/row in rows)
						if(row["type"] == "/area/caribbean/roofed/semiarid") row["type"] = "/area/caribbean/roofed/desert"
				fdel("map_saves/round.json")
				text2file(json_encode(state), "map_saves/round.json")
			var/accepted = map_storage.validate_world_save()
			if(mode != "read")
				durable_world_check(!accepted, "Malformed roof generation accepted")
				durable_world_check(get_area(locate(3,3,1)) == before_area && !locate(/obj/roof), "Rejected preflight mutated the startup world")
			else
				durable_world_check(accepted, "Fresh reader rejected roof area: [map_storage.last_error]")
				durable_world_check(get_area(locate(3,3,1)) == before_area && !locate(/obj/roof), "Accepted preflight mutated the startup world")
				var/datum/persistence_world_operation/op = begin_persistence_operation(map_storage, "load")
				durable_world_check(op, "Synthetic load admission failed")
				map_storage.suspend_durable_world()
				map_storage.ClearMap()
				durable_world_check(map_storage.run_world_operation("load", op), "Synthetic roof import failed: [map_storage.last_error]")
				durable_world_check(map_storage.load_map_metadata(), "Synthetic map metadata failed")
				map_storage.restore_durable_world()
				durable_world_check(op.finish(TRUE), "Synthetic load admission not released")
				var/obj/item/roof_area_fixture/item = locate()
				var/obj/roof/wood/roof = locate()
				var/area/A = get_area(locate(3,3,1))
				durable_world_check(item && roof && roof.loc == locate(3,3,1), "Recursive roof owner lost or duplicated")
				durable_world_check(istype(A, /area/caribbean/roofed/semiarid) && item.saved_area == A && map.faction_research["roof_area"] == A, "Saved area references diverged")
				durable_world_check(item.area_alias[1] == A && item.area_alias[A] == "area-key", "Saved list area key/alias diverged")
				var/list/nested = item.area_alias["nested"]
				durable_world_check(nested[1] == A && item.saved_roof == roof, "Nested area or roof alias lost")
				durable_world_check(A.artillery_integrity == 47 && roof.current_area_type == base.type && roof.switch_area, "Durable area or roof settings lost")
				var/list/restored_state = map_storage.read_round_state()
				durable_world_check(restored_state["generation"] == generation, "Synthetic saved generation changed")
		text2file(json_encode(list("done" = !durable_probe_failed, "checks" = durable_probe_checks, "mode" = mode)), "roof-result.json")
	catch(var/exception/e)
		text2file(json_encode(list("done" = FALSE, "checks" = durable_probe_checks, "error" = "[e]")), "roof-result.json")
	del(world)
