// Prepared synthetic 8x8x2 fixture; native behavior remains unverified.
// Writer/reader modes require fresh processes and copied temporary map_saves.
/obj/item/zone_fixture
	var/area/zone_alias
	var/list/zone_keys

// Only fixed synthetic directories are passed by this fixture. Completion is
// copied last, just as it is published last by the production saver.
/proc/zone_fixture_copy_generation(source, destination)
	durable_world_check(fexists("[source]/save_complete.txt"), "Synthetic source generation is incomplete")
	if(fexists("[destination]/save_complete.txt"))
		durable_world_check(fdel("[destination]/save_complete.txt"), "Cannot invalidate synthetic destination")
	for(var/name in list("map.txt", "round.json", "1.sav", "2.sav", "save_complete.txt"))
		durable_world_check(fcopy("[source]/[name]", "[destination]/[name]"), "Cannot copy synthetic generation file")

/proc/zone_fixture_archive(stage, list/manifest)
	durable_world_check(map_storage.Save_World(), "Successive generation save failed")
	var/list/state = map_storage.read_round_state()
	var/list/stages = manifest["stages"]
	for(var/key in stages) durable_world_check(stages[key] != state["generation"], "Generation identity was reused")
	stages[stage] = state["generation"]
	zone_fixture_copy_generation("map_saves", "zone-fixtures/[stage]")

/proc/zone_fixture_registry_lists()
	return list(latejoin_turfs["target"], newplayer_start, latejoin, paradrop_landmarks, supplydrop_turfs)

/proc/zone_fixture_registry_setup()
	latejoin_turfs = list("target" = list(locate(2,3,1)), "remove-me" = list(locate(7,7,1)))
	newplayer_start = list(locate(3,3,1))
	latejoin = list(locate(4,3,1))
	paradrop_landmarks = list(locate(5,3,1))
	supplydrop_turfs = list(locate(6,3,1))

/proc/zone_fixture_check_registries(stage)
	var/list/registries = zone_fixture_registry_lists()
	for(var/i = 1, i <= registries.len, i++)
		var/list/points = registries[i]
		durable_world_check(islist(points), "One of the five restored registries is absent")
		if(stage == "deleted")
			durable_world_check(!points.len, "Deleted spawn returned in a registry")
		else
			durable_world_check(points.len == (stage == "baseline" ? 1 : 2), "Spawn count differs in a registry")
			durable_world_check(points[1] == locate(i+1,3,stage == "baseline" ? 1 : 2), "Original/moved spawn differs in a registry")
			if(stage == "changed") durable_world_check(points[2] == locate(i+1,6,2), "Created spawn differs in a registry")
	if(stage == "baseline")
		durable_world_check(!("new-group" in latejoin_turfs) && ("remove-me" in latejoin_turfs), "Baseline named inventory differs")
	if(stage == "changed")
		durable_world_check(latejoin_turfs["new-group"][1] == locate(8,8,2), "Created named group lost")
	if(stage == "deleted")
		durable_world_check(("target" in latejoin_turfs) && !("remove-me" in latejoin_turfs) && !("new-group" in latejoin_turfs), "Empty and absent named groups were conflated")

/proc/zone_fixture_sequence(area/base, writing)
	if(writing)
		zone_fixture_registry_setup()
		var/area/existing = new /area/caribbean/nomads/semiarid()
		existing.name = "Previously saved zone"
		existing.contents += locate(2,3,1)
		var/obj/item/zone_fixture/I = new(locate(1,2,1))
		I.zone_alias = existing
		I.zone_keys = list(existing)
		I.zone_keys[existing] = "same identity"
		var/list/manifest = list("existing_id" = existing.persistence_zone_id, "created_id" = null, "stages" = list())
		zone_fixture_check_registries("baseline")
		zone_fixture_archive("baseline", manifest)
		manifest["existing_id"] = existing.persistence_zone_id
		// Move membership of the SAME already-saved instance to the other z.
		base.contents += locate(2,3,1)
		existing.contents += locate(2,3,2)
		var/area/created = new /area/caribbean/nomads/semiarid()
		created.name = "Created generation-two zone"
		created.contents += locate(8,8,2)
		manifest["created_id"] = created.persistence_zone_id
		var/list/registries = zone_fixture_registry_lists()
		for(var/i = 1, i <= registries.len, i++)
			var/list/points = registries[i]
			points[1] = locate(i+1,3,2)
			points += locate(i+1,6,2)
		latejoin_turfs["new-group"] = list(locate(8,8,2))
		zone_fixture_check_registries("changed")
		zone_fixture_archive("changed", manifest)
		manifest["created_id"] = created.persistence_zone_id
		// Retire references before deleting zones proven present in older saves.
		I.zone_alias = null
		I.zone_keys = list()
		base.contents += locate(2,3,2)
		base.contents += locate(8,8,2)
		qdel(existing)
		qdel(created)
		for(var/list/points in zone_fixture_registry_lists()) points.Cut()
		latejoin_turfs -= "remove-me"
		latejoin_turfs -= "new-group"
		zone_fixture_check_registries("deleted")
		zone_fixture_archive("deleted", manifest)
		var/list/final_state = map_storage.read_round_state()
		var/list/final_world = final_state["world_state"]
		var/list/final_topology = final_world["topology"]
		for(var/list/row in final_topology["zones"])
			durable_world_check(row["id"] != manifest["existing_id"] && row["id"] != manifest["created_id"], "Deleted saved zone retained in final inventory")
		text2file(json_encode(manifest), "zone-fixtures/manifest.json")
	else
		var/list/manifest = json_decode(file2text("zone-fixtures/manifest.json"))
		var/list/stages = manifest["stages"]
		var/area/retained
		for(var/stage in list("baseline", "changed", "deleted"))
			zone_fixture_copy_generation("zone-fixtures/[stage]", "map_saves")
			for(var/pass_number = 1, pass_number <= 2, pass_number++)
				durable_world_check(ticker.loadmap(), "Successive generation import failed")
				var/list/state = map_storage.read_round_state()
				durable_world_check(state["generation"] == stages[stage], "Reader imported the wrong generation")
				zone_fixture_check_registries(stage)
				var/obj/item/zone_fixture/I = locate() in locate(1,2,1)
				if(stage == "deleted")
					durable_world_check(!I.zone_alias && !I.zone_keys.len, "Deleted-zone aliases were retained")
					for(var/area/A in area_list)
						durable_world_check(A.persistence_zone_id != manifest["existing_id"] && A.persistence_zone_id != manifest["created_id"], "Deleted saved zone was republished")
				else
					var/area/A = get_area(locate(2,3,stage == "baseline" ? 1 : 2))
					durable_world_check(A.persistence_zone_id == manifest["existing_id"], "Moved saved zone identity changed")
					if(retained) durable_world_check(A == retained, "Successive/repeated import replaced the same durable zone")
					retained = A
					durable_world_check(I.zone_alias == A && I.zone_keys[A] == "same identity", "Successive generation area alias/key differs")
					if(stage == "changed")
						durable_world_check(get_area(locate(2,3,1)) != A, "Old zone membership remained after movement")
						durable_world_check(get_area(locate(8,8,2)).persistence_zone_id == manifest["created_id"], "New generation-two zone identity lost")

/proc/zone_fixture_remove_referenced_zone(list/topology, list/spawn)
	var/id = spawn["zone"]
	var/list/zones = topology["zones"]
	var/removed = 0
	var/membership_cells = 0
	for(var/z = 1, z <= 2, z++)
		var/savefile/F = new("map_saves/[z].sav")
		F.cd = "/zone_capture"
		for(var/ref in F.dir)
			if(F["/zone_capture/[ref]/id"] == id) membership_cells++
	durable_world_check(istext(id) && membership_cells > 0, "Absent-zone control lacks membership evidence")
	for(var/i = zones.len, i >= 1, i--)
		var/list/row = zones[i]
		if(row["id"] == id)
			zones.Cut(i, i+1)
			removed++
	durable_world_check(removed == 1 && spawn["zone"] == id, "Absent-zone control did not remove the referenced identity")
	text2file(json_encode(list("removed_zone" = id, "removed_rows" = removed, "membership_cells_still_referencing" = membership_cells, "spawn_still_references" = TRUE)), "zone-negative-setup.json")

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
	var/mode = world.params["zone_mode"]
	try
		OpenPort(19327)
		durable_world_check(!world.port, "Fixture listener did not close")
		text2file("closed", "probe-port-closed.txt")
		var/deadline = world.time + 100
		while(!fexists("probe-port-closed.ack") && world.time < deadline) sleep(1)
		durable_world_check(fexists("probe-port-closed.ack"), "External listener closure was not acknowledged")
		config = new
		config.webhook_can_fire = FALSE
		config.ToRban = FALSE
		ticker = new
		ticker.current_state = GAME_STATE_PLAYING
		processes.time_of_day = new
		processes.weather = new
		map = new /obj/map_metadata/nomads/gaia(locate(1,1,1))
		map.times_of_day = list("Morning", "Evening")
		times_of_day = map.times_of_day
		season = "SUMMER"
		time_of_day = "Evening"
		global.game_id = "synthetic-zone-generation"
		var/area/base = new /area/caribbean/nomads/semiarid()
		for(var/turf/T in world) base.contents += T
		initialize_persistence_zones()
		latejoin_turfs = list("moved" = list(locate(2,2,1)), "deleted" = list(locate(4,4,1)), "removed-group" = list(locate(5,5,1)))
		newplayer_start = list(locate(1,1,1))
		latejoin = list()
		paradrop_landmarks = list()
		supplydrop_turfs = list()
		if(mode in list("write-sequence", "read-sequence"))
			zone_fixture_sequence(base, mode == "write-sequence")
		else if(mode in list("write", "legacy-write"))
			if(mode == "write")
				var/area/created = new /area/caribbean/nomads/semiarid()
				created.name = "Created same-type zone"
				created.contents += locate(3,3,2)
				var/area/deleted = new /area/caribbean/forest()
				deleted.contents += locate(4,4,1)
				base.contents += locate(4,4,1)
				qdel(deleted)
				latejoin_turfs = list("moved" = list(locate(3,3,2)), "created" = list(locate(8,8,2)), "deleted" = list())
				var/obj/item/zone_fixture/I = new(locate(2,2,1))
				I.zone_alias = created
				I.zone_keys = list(created)
				I.zone_keys[created] = "same identity"
			durable_world_check(map_storage.Save_World(), "Zone writer failed")
			if(mode == "legacy-write")
				var/list/state = json_decode(file2text("map_saves/round.json"))
				var/list/W = state["world_state"]
				W["schema"] = 1
				W -= "topology"
				fdel("map_saves/round.json")
				text2file(json_encode(state), "map_saves/round.json")
		else
			var/list/state = json_decode(file2text("map_saves/round.json"))
			var/list/W = state["world_state"]
			var/list/topology = W["topology"]
			var/negative = !(mode in list("read", "legacy-read"))
			if(negative)
				var/list/spawns = topology["spawns"]
				var/list/groups = spawns["latejoin"]
				var/list/moved = groups["moved"]
				var/list/row = moved[1]
				var/list/zones = topology["zones"]
				var/savefile/F = new("map_saves/1.sav")
				var/turf_ref = F["/map/1/1/1"]
				switch(mode)
					if("duplicate-spawn") moved += list(row.Copy())
					if("stale-zone") row["zone"] = "absent"
					if("wrong-z") row["z"] = 3
					if("fractional") row["x"] = 1.5
					if("duplicate-zone") zones += list(zones[1])
					if("absent-zone") zone_fixture_remove_referenced_zone(topology, row)
					if("incomplete") F["/zone_capture/[turf_ref]/index"] << null
					if("overlong") F["/zone_capture/[turf_ref]/index"] << 129
					else throw EXCEPTION("Unknown zone fixture mode")
				fdel("map_saves/round.json")
				text2file(json_encode(state), "map_saves/round.json")
				F = null
			var/obj/item/zone_fixture/sentinel = new(locate(7,7,1))
			if(negative)
				var/old_registry = latejoin_turfs
				var/list/old_areas = area_list.Copy()
				durable_world_check(!ticker.loadmap(), "Malformed topology was accepted")
				durable_world_check(sentinel.loc == locate(7,7,1) && get_area(sentinel) == base, "Rejection mutated the sentinel")
				durable_world_check(latejoin_turfs == old_registry && area_list.len == old_areas.len, "Rejection changed indexes")
			else
				durable_world_check(ticker.loadmap(), "Zone reader failed")
				if(mode == "legacy-read")
					durable_world_check(!persistence_spawns_authoritative, "Legacy reader invented topology")
				else
					var/obj/item/zone_fixture/I = locate() in locate(2,2,1)
					var/area/A = get_area(locate(3,3,2))
					durable_world_check(A != base && A.name == "Created same-type zone", "Created zone identity or fields lost")
					durable_world_check(I.zone_alias == A && I.zone_keys[A] == "same identity", "Area alias/key changed")
					durable_world_check(latejoin_turfs["moved"][1] == locate(3,3,2), "Moved spawn lost")
					durable_world_check(latejoin_turfs["created"][1] == locate(8,8,2), "Created spawn lost")
					durable_world_check(!latejoin_turfs["deleted"].len, "Deleted spawn returned")
					durable_world_check(!("removed-group" in latejoin_turfs), "Absent group recreated from startup")
					var/id = A.persistence_zone_id
					durable_world_check(ticker.loadmap(), "Repeated load failed")
					durable_world_check(get_area(locate(3,3,2)) == A && A.persistence_zone_id == id, "Repeated load replaced durable area")
					durable_world_check(latejoin_turfs["moved"].len == 1 && !latejoin_turfs["deleted"].len, "Repeated load appended defaults")
		text2file(json_encode(list("mode" = mode, "checks" = durable_probe_checks, "failed" = durable_probe_failed)), "zone-result.json")
	catch(var/exception/E)
		durable_probe_failed = TRUE
		world.log << "FAIL: [E] at [E.file]:[E.line]"
		text2file("[E]", "zone-failure.txt")
	del(world)
	return
