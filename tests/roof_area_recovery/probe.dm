// PREPARED ONLY. Fresh writer and reader processes use synthetic fixture files.
// The normal production roof constructor, saver, validator and loader are used.
/obj/item/roof_area_fixture
	var/area/saved_area
	var/list/area_alias
	var/obj/roof/saved_roof

/obj/roof/area_fixture_disabled
	switch_area = FALSE

/world
	visibility = 0
	sleep_offline = FALSE

/world/OpenPort(port)
	return ..("none")
/client/New()
	del(src)
/world/Topic()
	return null

/world/New()
	OpenPort("none")
	var/mode = world.params["roof_mode"]
	try
		OpenPort(19327) // The fixture override must refuse reopening.
		durable_world_check(!world.port, "Fixture listener did not close")
		text2file("closed", "probe-port-closed.txt")
		var/closure_deadline = world.time + 100
		while(!fexists("probe-port-closed.ack") && world.time < closure_deadline) sleep(1)
		durable_world_check(fexists("probe-port-closed.ack") && findtext(file2text("probe-port-closed.ack"), "closed") == 1, "External listener closure was not acknowledged")
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
		var/area/caribbean/nomads/semiarid/base = locate(/area/caribbean/nomads/semiarid)
		for(var/turf/T in world) ChangeArea(T, base)
		durable_world_check(mode in list("write", "write-roofed", "write-covered", "read", "read-covered", "missing-roof", "wrong-base", "missing-scalar", "disabled-roof", "unrelated-area", "duplicate-area", "duplicate-placement", "empty-instance", "postflight-empty", "old-defect"), "Unknown roof fixture mode")
		if(mode in list("write", "write-roofed", "write-covered"))
			// This item is visited before its referenced roof turf. Nested list
			// keys/values and aliases must resolve to the SAME reconstructed area.
			var/obj/item/roof_area_fixture/item = new(locate(1,1,1))
			if(mode == "write-covered")
				for(var/turf/T in world)
					new /obj/structure/roof_support(T)
					new /obj/roof/wood(T)
			else
				for(var/turf/T in list(locate(3,3,1), locate(4,3,1), locate(3,3,2)))
					new /obj/structure/roof_support(T)
					new /obj/roof/wood(T)
				new /obj/structure/roof_support(locate(5,3,1))
				new /obj/roof/area_fixture_disabled(locate(5,3,1))
			var/obj/roof/wood/roof = locate() in locate(3,3,1)
			durable_world_check(istype(get_area(roof), /area/caribbean/roofed/semiarid), "Actual roof constructor did not create a roofed area")
			var/obj/roof/wood/second_roof = locate() in locate(4,3,1)
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
			map_storage.clear_bookkeeping()
			if(mode != "write-roofed")
				qdel(roof)
				sleep(1)
				durable_world_check(get_area(locate(3,3,1)) == base, "Writer roof destruction did not restore base area")
				durable_world_check(map_storage.validate_world_save(), "Writer could not validate disk topology after roof destruction and cleanup")
			else
				// The omission control must not fail its writer just because its
				// projection is disabled. This world is still physically roofed.
				durable_world_check(map_storage.validate_world_save(), "Already-roofed control writer failed after bookkeeping cleanup")
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
			if(mode in list("read", "read-covered", "postflight-empty"))
				// Force the absent-destination case even if the engine supplied
				// an empty default instance. No mapped area may be removed.
				var/area/startup = map_storage.find_saved_roof_area(/area/caribbean/roofed/semiarid)
				if(startup)
					if(locate(/turf) in startup) throw EXCEPTION("Fixture roof destination already owns startup turfs")
					del(startup)
			if(mode == "empty-instance")
				new /area/caribbean/roofed/semiarid()
				new /area/caribbean/roofed/semiarid()
			if(mode == "postflight-empty") new /area/caribbean/roofed/semiarid()
			if(mode == "missing-roof") F["[turf_path]/content"] << ""
			if(mode == "wrong-base") F["[roof_path]/current_area_type"] << list("kind" = "value", "value" = /area/caribbean/nomads/desert)
			if(mode == "missing-scalar") F["[roof_path]/switch_area"] << list("kind" = "entry", "ref" = roof_ref)
			if(mode == "disabled-roof") F["[roof_path]/switch_area"] << list("kind" = "value", "value" = FALSE)
			if(mode == "duplicate-placement")
				var/other_ref = F["/map/1/3/4"]
				F["[map_storage.entry_path(F, other_ref)]/content"] << F["[turf_path]/content"]
			if(mode in list("unrelated-area", "duplicate-area"))
				var/list/rows = W["areas"]
				if(mode == "duplicate-area") rows += list(rows[rows.len].Copy())
				else
					for(var/list/row in rows)
						if(row["type"] == "/area/caribbean/roofed/semiarid") row["type"] = "/area/caribbean/roofed/desert"
				fdel("map_saves/round.json")
				text2file(json_encode(state), "map_saves/round.json")
			var/accepted = map_storage.validate_world_save()
			if(mode == "old-defect")
				durable_world_check(!accepted && findtext(map_storage.last_error, "Referenced area differs from the current map"), "Old defect did not reproduce the exact area preflight failure")
				durable_world_check(get_area(locate(3,3,1)) == before_area && !locate(/obj/roof), "Old defect control mutated the startup world")
			else if(mode == "postflight-empty")
				durable_world_check(accepted, "Valid preflight failed before postflight instance control")
				var/area/retained = map_storage.validated_roof_instances["/area/caribbean/roofed/semiarid"]
				var/area/extra = new /area/caribbean/roofed/semiarid()
				var/rejected = FALSE
				try
					map_storage.materialize_saved_roof_areas()
				catch(var/exception/e)
					rejected = findtext("[e]", "Ambiguous current roof area identity") > 0
				durable_world_check(rejected && map_storage.validated_roof_instances["/area/caribbean/roofed/semiarid"] == retained && get_area(locate(3,3,1)) == before_area, "Postflight empty area was reselected or mutated world")
				del(extra)
				del(retained)
				var/area/replacement = new /area/caribbean/roofed/semiarid()
				rejected = FALSE
				try
					map_storage.materialize_saved_roof_areas()
				catch(var/exception/e)
					rejected = findtext("[e]", "Validated roof area instance disappeared") > 0
				durable_world_check(rejected && get_area(locate(3,3,1)) == before_area, "Changed retained roof identity was accepted")
				del(replacement)
				durable_world_check(map_storage.validate_world_save() && map_storage.validated_roof_absent["/area/caribbean/roofed/semiarid"], "Absent roof destination was not planned without mutation")
				new /area/caribbean/roofed/semiarid()
				rejected = FALSE
				try
					map_storage.materialize_saved_roof_areas()
				catch(var/exception/e)
					rejected = findtext("[e]", "Planned roof area absence changed") > 0
				durable_world_check(rejected && get_area(locate(3,3,1)) == before_area, "Changed planned roof absence was accepted")
			else if(!(mode in list("read", "read-covered")))
				durable_world_check(!accepted, "Malformed roof generation accepted")
				durable_world_check(get_area(locate(3,3,1)) == before_area && !locate(/obj/roof), "Rejected preflight mutated the startup world")
			else
				durable_world_check(accepted && map_storage.validated_roof_absent["/area/caribbean/roofed/semiarid"] && !map_storage.validated_roof_instances["/area/caribbean/roofed/semiarid"], "Fresh reader rejected absent roof destination: [map_storage.last_error]")
				durable_world_check(get_area(locate(3,3,1)) == before_area && !locate(/obj/roof) && !map_storage.find_saved_roof_area(/area/caribbean/roofed/semiarid), "Accepted preflight mutated the startup world")
				var/datum/persistence_world_operation/op = begin_persistence_operation(map_storage, "load")
				durable_world_check(op, "Synthetic load admission failed")
				if(mode == "read")
					// Execute the production cleanup predicate with a deliberately
					// colliding per-level numeric ref. Only loading_z differs.
					map_storage.materialize_saved_roof_areas()
					var/list/foreign_row = map_storage.validated_roof_areas["3,3,2"]
					var/current_level_type = F["[map_storage.entry_path(F, foreign_row["entry"])]/type"]
					durable_world_check(current_level_type && !ispath(current_level_type, /obj/roof), "Fixture lacks a cross-z numeric ref collision with an unrelated entry")
					var/obj/roof/wood/foreign = new(locate(3,3,2))
					map_storage.existing_references[foreign_row["entry"]] = foreign
					map_storage.loading_z = 1
					durable_world_check(!map_storage.is_loaded_validated_roof(foreign), "Cross-z equal numeric roof ref was retained")
					map_storage.loading_z = 2
					durable_world_check(map_storage.is_loaded_validated_roof(foreign), "Matching-z validated roof was not retained")
					map_storage.clear_bookkeeping()
					map_storage.loading_z = 0
					map_storage.restoring_roof_areas = FALSE
				map_storage.suspend_durable_world()
				map_storage.ClearMap()
				durable_world_check(map_storage.run_world_operation("load", op), "Synthetic roof import failed: [map_storage.last_error]")
				durable_world_check(map_storage.load_map_metadata(), "Synthetic map metadata failed")
				map_storage.restore_durable_world()
				durable_world_check(op.finish(TRUE), "Synthetic load admission not released")
				var/obj/item/roof_area_fixture/item = locate()
				// qdel detaches retired roofs before native GC. Select the loaded
				// graph owner, never an older detached instance of the same type.
				var/obj/roof/wood/roof = item ? item.saved_roof : null
				var/area/A = get_area(locate(3,3,1))
				durable_world_check(item && roof && roof.loc == locate(3,3,1), "Recursive roof owner lost or duplicated")
				durable_world_check(istype(A, /area/caribbean/roofed/semiarid) && map_storage.find_saved_roof_area(A.type) == A && item.saved_area == A && map.faction_research["roof_area"] == A, "Saved area references diverged")
				durable_world_check(item.area_alias[1] == A && item.area_alias[A] == "area-key", "Saved list area key/alias diverged")
				var/list/nested = item.area_alias["nested"]
				durable_world_check(nested[1] == A && item.saved_roof == roof, "Nested area or roof alias lost")
				durable_world_check(A.artillery_integrity == 47 && roof.current_area_type == base.type && roof.switch_area, "Durable area or roof settings lost")
				if(mode == "read")
					var/obj/roof/area_fixture_disabled/disabled = locate() in locate(5,3,1)
					durable_world_check(disabled && !disabled.switch_area && disabled.current_area_type == /area/caribbean && get_area(disabled) == base, "Disabled roof changed topology or lost saved settings")
				else
					durable_world_check(!(locate(/turf) in base), "Fully roofed base area still has turfs")
				// Constructor overlays must be real, and subsequent destruction
				// must restore the recorded base rather than the roofed area.
				durable_world_check(roof.roof_overlay && (roof.roof_overlay in roofs_list), "Real roof constructor overlay was not registered")
				var/roof_count = 0
				for(var/obj/roof/R in world)
					if(get_turf(R) && !R.gc_destroyed && !R.gcDestroyed) roof_count++
				durable_world_check(roof_count == (mode == "read-covered" ? world.maxx * world.maxy * world.maxz : 4), "Roof constructors lost or duplicated owners")
				qdel(roof)
				sleep(1)
				durable_world_check(get_area(locate(3,3,1)) == base, "Roof destruction did not restore original base area")
				var/list/restored_state = map_storage.read_round_state()
				durable_world_check(restored_state["generation"] == generation, "Synthetic saved generation changed")
		text2file(json_encode(list("done" = !durable_probe_failed, "checks" = durable_probe_checks, "mode" = mode)), "roof-result.json")
	catch(var/exception/e)
		text2file(json_encode(list("done" = FALSE, "checks" = durable_probe_checks, "mode" = mode, "error" = "[e]")), "roof-result.json")
	del(world)
