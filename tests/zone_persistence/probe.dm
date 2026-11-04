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
						var/area/created_zone = get_area(locate(8,8,2))
						durable_world_check(created_zone.persistence_zone_id == manifest["created_id"], "New generation-two zone identity lost")

/proc/zone_fixture_remove_referenced_zone(list/topology, list/spawn_row)
	var/id = spawn_row["zone"]
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
	durable_world_check(removed == 1 && spawn_row["zone"] == id, "Absent-zone control did not remove the referenced identity")
	text2file(json_encode(list("removed_zone" = id, "removed_rows" = removed, "membership_cells_still_referencing" = membership_cells, "spawn_still_references" = TRUE)), "zone-negative-setup.json")

// ---------------------------------------------------------------------------
// #3311 native acceptance modes. Same synthetic 8x8x2 world, production saver,
// validator, ticker.loadmap and constructors. Writers record identities in
// zone-fixtures/, which the runner copies to the fresh reader with map_saves.

/obj/roof/zone_fixture_disabled
	switch_area = FALSE

var/global/zone_fixture_surprise_armed = FALSE
var/global/area/zone_fixture_intruder
/area/caribbean/zone_fixture_surprise
	name = "Surprise constructor zone"
	climate = "semiarid"
// Production materialization constructs this saved zone; once armed its
// constructor creates an extra, unrequested area during staging.
/area/caribbean/zone_fixture_surprise/New()
	..()
	if(zone_fixture_surprise_armed)
		zone_fixture_surprise_armed = FALSE
		new /area/caribbean/zone_fixture_intruder()
/area/caribbean/zone_fixture_intruder
	name = "Unrequested staged zone"
/area/caribbean/zone_fixture_intruder/New()
	zone_fixture_intruder = src
	..()
// A stale startup zone whose retirement is refused by its own Destroy hint.
/area/caribbean/zone_fixture_stubborn
	name = "Unretirable startup zone"
/area/caribbean/zone_fixture_stubborn/Destroy()
	return QDEL_HINT_LETMELIVE

/proc/zone_fixture_extended_modes()
	return list("roof-write", "roof-read", "roof-omitted-settings", "roof-absent-base", "ambiguous-base-write", "ambiguous-base-read", "weather-write", "weather-read", "surprise-write", "surprise-read", "retire-read", "admission", "latejoin-read")

/proc/zone_fixture_save_hashes()
	var/list/result = list()
	for(var/name in list("map.txt", "round.json", "1.sav", "2.sav", "save_complete.txt"))
		result[name] = fexists("map_saves/[name]") ? md5(file("map_saves/[name]")) : null
	return result

/proc/zone_fixture_manifest(list/data)
	if(data)
		text2file(json_encode(data), "zone-fixtures/manifest-[world.params["zone_mode"]].json")
		return data
	return null

/proc/zone_fixture_read_manifest(writer)
	durable_world_check(fexists("zone-fixtures/manifest-[writer].json"), "Writer manifest [writer] is absent")
	return json_decode(file2text("zone-fixtures/manifest-[writer].json"))

/proc/zone_fixture_rewrite_state(list/state)
	fdel("map_saves/round.json")
	text2file(json_encode(state), "map_saves/round.json")

/proc/zone_fixture_saved_topology()
	var/list/state = map_storage.read_round_state()
	var/list/W = state["world_state"]
	return W["topology"]

// Preflight rejection: exact reason, unchanged world/indexes/files, no hold.
/proc/zone_fixture_expect_rejection(area/base, expected)
	// BYOND flushes a released savefile's setup edits at the next tick boundary.
	// Hash after that flush so only the rejected preflight is measured.
	sleep(1)
	var/obj/item/zone_fixture/sentinel = new(locate(7,7,1))
	var/old_registry = latejoin_turfs
	var/list/old_areas = area_list
	var/list/hashes = zone_fixture_save_hashes()
	durable_world_check(!ticker.loadmap(), "Malformed topology was accepted")
	durable_world_check(findtext("[map_storage.last_error]", expected), "Rejection reason differs: [map_storage.last_error]")
	durable_world_check(sentinel.loc == locate(7,7,1) && get_area(sentinel) == base, "Rejection mutated the sentinel")
	durable_world_check(latejoin_turfs == old_registry && area_list == old_areas, "Rejection changed indexes")
	durable_world_check(!persistence_load_recovery_required && !persistence_area_registry_blocked(), "Preflight rejection raised a recovery hold")
	var/list/after = zone_fixture_save_hashes()
	for(var/name in hashes)
		durable_world_check(after[name] == hashes[name], "Rejected preflight changed saved file [name]")

// Post-ClearMap failure: retained hold, unpublished registries, intact files.
/proc/zone_fixture_expect_held_failure(expected, list/hashes, old_registry, list/old_areas, obj/sentinel)
	durable_world_check(!ticker.loadmap(), "Failed staged topology was published")
	durable_world_check(findtext("[map_storage.last_error]", expected), "Held failure reason differs: [map_storage.last_error]")
	durable_world_check(persistence_load_recovery_required, "Failure after ClearMap did not retain a recovery hold")
	durable_world_check(!sentinel || sentinel.gc_destroyed || sentinel.gcDestroyed || !sentinel.loc, "No-rollback contract changed: ClearMap result was not retained")
	durable_world_check(area_list == old_areas && latejoin_turfs == old_registry && !persistence_spawns_authoritative, "Failed staging published registries")
	durable_world_check(persistence_area_registry_blocked(), "Area registry readers were admitted during the recovery hold")
	var/rejected = FALSE
	try
		return_areas()
	catch(var/exception/blocked)
		rejected = findtext("[blocked]", "Area registry unavailable") > 0
	durable_world_check(rejected, "Registry reader did not refuse the recovery hold")
	durable_world_check(change_weather(WEATHER_WET, TRUE) == FALSE, "Weather sweep ran during the recovery hold")
	durable_world_check(!begin_persistence_operation(map_storage, "save") && !map_storage.Save_World(), "Save admitted during the recovery hold")
	durable_world_check(!ticker.loadmap(), "Load retried automatically during the recovery hold")
	var/list/after = zone_fixture_save_hashes()
	for(var/name in hashes)
		durable_world_check(after[name] == hashes[name], "Held failure changed saved file [name]")

/proc/zone_fixture_place_roofs()
	for(var/turf/T in list(locate(3,3,1), locate(4,3,1), locate(3,3,2)))
		new /obj/structure/roof_support(T)
		new /obj/roof/wood(T)
	new /obj/structure/roof_support(locate(5,3,1))
	new /obj/roof/zone_fixture_disabled(locate(5,3,1))

/proc/zone_fixture_roof_entry(savefile/F)
	var/version = F["/format_version"]
	if(version == 4) version = map_storage.level_content_version(F)
	var/turf_ref = F["/map/1/3/3"]
	var/list/contents = map_storage.saved_content_refs(map_storage.level_entry_value(F, turf_ref, "content"), version)
	for(var/ref in contents)
		if(ispath(map_storage.level_entry_value(F, ref, "type"), /obj/roof)) return map_storage.entry_path(map_storage.level_entry_file(F, ref), ref)
	throw EXCEPTION("Synthetic saved roof absent")

/proc/zone_fixture_extended(mode, area/base)
	switch(mode)
		if("roof-write", "ambiguous-base-write")
			zone_fixture_place_roofs()
			var/obj/roof/wood/roof = locate() in locate(3,3,1)
			var/area/R = get_area(roof)
			durable_world_check(istype(R, /area/caribbean/roofed/semiarid) && get_area(locate(4,3,1)) == R && get_area(locate(3,3,2)) == R, "Actual roof constructors did not share one roofed zone")
			durable_world_check(get_area(locate(5,3,1)) == base, "Disabled roof changed its turf's zone")
			var/obj/item/zone_fixture/I = new(locate(1,2,1))
			I.zone_alias = R
			I.zone_keys = list(R)
			I.zone_keys[R] = "roof identity"
			durable_world_check(map_storage.Save_World(), "Switched-roof writer failed: [map_storage.last_error]")
			var/list/topology = zone_fixture_saved_topology()
			durable_world_check(topology["schema"] == 2 && R.persistence_zone_id && base.persistence_zone_id, "Writer did not save schema-2 roof topology")
			var/list/state = map_storage.read_round_state()
			zone_fixture_manifest(list("roof" = R.persistence_zone_id, "base" = base.persistence_zone_id, "generation" = state["generation"]))
			if(mode == "ambiguous-base-write")
				// A second explicit instance of the switched roof's base type makes
				// the restore unresolvable. The save must refuse before publishing.
				var/area/twin = new /area/caribbean/nomads/semiarid()
				twin.name = "Ambiguous same-type base"
				twin.contents += locate(7,2,1)
				var/refusal
				try
					if(map_storage.Save_World()) refusal = "saved"
				catch(var/exception/save_error)
					refusal = "[save_error]"
				durable_world_check(refusal != "saved", "Ambiguous same-type roof base was saved")
				durable_world_check(findtext(refusal, "Ambiguous saved roof base zone"), "Ambiguous save failed for another reason: [refusal]")
				durable_world_check(!fexists("map_saves/save_complete.txt") && trim(file2text("map_backups/save_complete.txt")) == state["generation"], "Refused ambiguous save did not keep the previous complete generation as its backup")
				// Remove the ambiguity: the next save succeeds again.
				base.contents += locate(7,2,1)
				qdel(twin)
				durable_world_check(map_storage.Save_World(), "Save after removing the ambiguity failed: [map_storage.last_error]")
		if("roof-read")
			var/list/manifest = zone_fixture_read_manifest("roof-write")
			var/area/retained
			for(var/pass_number = 1, pass_number <= 2, pass_number++)
				durable_world_check(ticker.loadmap(), "Switched-roof import failed: [map_storage.last_error]")
				var/area/R = get_area(locate(3,3,1))
				durable_world_check(istype(R, /area/caribbean/roofed/semiarid) && R.persistence_zone_id == manifest["roof"], "Schema-2 roof plan omitted a switched roof")
				durable_world_check(get_area(locate(4,3,1)) == R && get_area(locate(3,3,2)) == R, "Restored roofs do not share their saved zone")
				if(retained) durable_world_check(R == retained, "Repeated load replaced the restored roof zone")
				retained = R
				var/area/B = get_area(locate(5,3,1))
				durable_world_check(B.persistence_zone_id == manifest["base"] && B.type == /area/caribbean/nomads/semiarid, "Base zone identity changed")
				var/obj/roof/wood/roof = locate() in locate(3,3,1)
				durable_world_check(roof && roof.switch_area && roof.current_area_type == /area/caribbean/nomads/semiarid, "Switched roof settings lost")
				var/obj/roof/zone_fixture_disabled/disabled = locate() in locate(5,3,1)
				durable_world_check(disabled && !disabled.switch_area && disabled.current_area_type == /area/caribbean, "Disabled roof settings changed")
				var/obj/item/zone_fixture/I = locate() in locate(1,2,1)
				durable_world_check(I && I.zone_alias == R && I.zone_keys[R] == "roof identity", "Roof zone alias/key differs")
				durable_world_check(roof.roof_overlay && (roof.roof_overlay in roofs_list), "Roof constructor overlay was not registered")
				var/roof_count = 0
				for(var/obj/roof/counted in world)
					if(get_turf(counted) && !counted.gc_destroyed && !counted.gcDestroyed) roof_count++
				durable_world_check(roof_count == 4, "Roof constructors lost or duplicated owners")
				durable_world_check(persistence_spawns_authoritative && !persistence_area_registry_blocked(), "Roof import did not publish")
			var/obj/roof/wood/destroyed = locate() in locate(3,3,1)
			qdel(destroyed)
			sleep(1)
			var/area/after = get_area(locate(3,3,1))
			durable_world_check(after.type == /area/caribbean/nomads/semiarid && get_area(locate(4,3,1)) == retained, "Roof destruction after import did not restore its base type")
		if("roof-omitted-settings", "roof-absent-base")
			var/savefile/F = new("map_saves/1.sav")
			var/path = zone_fixture_roof_entry(F)
			if(mode == "roof-omitted-settings")
				F.cd = path
				F.dir -= "switch_area"
				durable_world_check(!("switch_area" in F.dir), "Omission setup failed")
			else
				F["[path]/current_area_type"] << list("kind" = "value", "value" = /area/caribbean/forest)
			F = null
			zone_fixture_expect_rejection(base, mode == "roof-omitted-settings" ? "Missing saved roof settings" : "Absent saved roof base zone")
		if("ambiguous-base-read")
			var/list/state = map_storage.read_round_state()
			var/list/W = state["world_state"]
			var/list/topology = W["topology"]
			var/list/zones = topology["zones"]
			var/list/manifest = zone_fixture_read_manifest("roof-write")
			for(var/list/row in zones.Copy())
				if(row["id"] != manifest["base"]) continue
				var/list/twin = row.Copy()
				twin["id"] = "map:/area/caribbean/nomads/semiarid:999"
				zones += list(twin)
			durable_world_check(zones.len >= 3, "Ambiguity setup did not add a same-type base")
			zone_fixture_rewrite_state(state)
			zone_fixture_expect_rejection(base, "Ambiguous saved roof base zone")
		if("weather-write")
			base.weather = WEATHER_WET
			base.weather_intensity = 2
			base.icon_state = "rain2"
			var/area/caribbean/nomads/desert/D = new()
			D.name = "Sandstorm zone"
			for(var/turf/T in list(locate(5,5,1), locate(6,5,1), locate(5,5,2))) D.contents += T
			D.weather = WEATHER_EXTREME
			D.weather_intensity = 3
			D.icon_state = "sandstorm"
			var/area/caribbean/forest/N = new()
			N.name = "Unlit indoor zone"
			N.dynamic_lighting = FALSE
			N.location = AREA_INSIDE
			N.weather = WEATHER_NONE
			N.weather_intensity = 1
			for(var/turf/T in list(locate(2,6,1), locate(3,6,1))) N.contents += T
			// Global weather cannot reproduce these local values.
			weather = WEATHER_NONE
			weather_intensity = 1
			durable_world_check(map_storage.Save_World(), "Weather writer failed: [map_storage.last_error]")
			var/list/rows = list()
			for(var/list/spec in list(list(base, 1, 1, 1), list(D, 5, 5, 1), list(N, 2, 6, 1)))
				var/area/A = spec[1]
				rows += list(list("id" = A.persistence_zone_id, "x" = spec[2], "y" = spec[3], "z" = spec[4], "weather" = A.weather, "intensity" = A.weather_intensity, "icon_state" = A.icon_state, "dynamic" = A.dynamic_lighting, "location" = A.location))
			zone_fixture_manifest(list("zones" = rows))
		if("weather-read")
			var/list/manifest = zone_fixture_read_manifest("weather-write")
			// A lit startup map: import must clear overlays the saved policy forbids.
			for(var/turf/T in world) T.lighting_build_overlay()
			var/turf/startup_unlit = locate(2,6,1)
			durable_world_check(startup_unlit.lighting_overlay, "Startup lighting overlays were not built")
			for(var/pass_number = 1, pass_number <= 2, pass_number++)
				durable_world_check(ticker.loadmap(), "Weather import failed: [map_storage.last_error]")
				for(var/list/row in manifest["zones"])
					var/area/A = get_area(locate(row["x"], row["y"], row["z"]))
					durable_world_check(A.persistence_zone_id == row["id"], "Weather zone identity changed")
					durable_world_check(A.weather == row["weather"] && A.weather_intensity == row["intensity"], "Saved local weather or intensity was not restored")
					durable_world_check(A.icon_state == row["icon_state"], "Saved local icon state was not reconciled")
					durable_world_check(A.dynamic_lighting == row["dynamic"] && A.location == row["location"] && A.luminosity == !A.dynamic_lighting, "Saved lighting policy differs")
					for(var/turf/T in A)
						durable_world_check(A.dynamic_lighting ? !!T.lighting_overlay : !T.lighting_overlay, "Imported turf lighting overlay differs from its zone policy")
			// Ordinary gameplay transitions after publication use the same policy.
			var/list/unlit_row = manifest["zones"][3]
			var/area/unlit = get_area(locate(2,6,1))
			var/area/lit = get_area(locate(1,1,1))
			durable_world_check(unlit.persistence_zone_id == unlit_row["id"], "Unlit zone lookup changed")
			var/turf/moved = locate(2,6,1)
			ChangeArea(moved, lit)
			durable_world_check(moved.lighting_overlay, "Moving a turf into a lit zone did not build its overlay")
			ChangeArea(moved, unlit)
			durable_world_check(!moved.lighting_overlay, "Moving a turf into an unlit zone did not clear its overlay")
			// The next global weather sweep is admitted and replaces local values.
			var/area/sandstorm = get_area(locate(5,5,1))
			apply_area_weather(sandstorm)
			durable_world_check(sandstorm.weather == weather && sandstorm.icon_state == "", "Post-load weather sweep was not admitted")
		if("surprise-write")
			var/area/caribbean/zone_fixture_surprise/S = new()
			S.contents += locate(6,6,1)
			durable_world_check(map_storage.Save_World(), "Surprise writer failed: [map_storage.last_error]")
			durable_world_check(S.persistence_zone_id, "Surprise zone was not captured")
		if("surprise-read", "retire-read")
			var/obj/item/zone_fixture/sentinel = new(locate(7,7,1))
			var/old_registry = latejoin_turfs
			var/list/hashes = zone_fixture_save_hashes()
			if(mode == "surprise-read")
				zone_fixture_surprise_armed = TRUE
			else
				new /area/caribbean/zone_fixture_stubborn()
			var/list/old_areas = area_list
			zone_fixture_expect_held_failure(mode == "surprise-read" ? "Unexpected staged area constructor" : "Stale zone retirement failed", hashes, old_registry, old_areas, sentinel)
			if(mode == "surprise-read")
				durable_world_check(zone_fixture_intruder && !(zone_fixture_intruder in area_list) && !zone_fixture_intruder.persistence_zone_id, "Unrequested staged constructor entered the registry")
		if("admission")
			// A startup roof is destroyed by ClearMap. Its Destroy constructs a
			// transient base area while staging quarantines old-world areas.
			new /obj/structure/roof_support(locate(6,6,1))
			new /obj/roof/wood(locate(6,6,1))
			var/area/startup_roofed = get_area(locate(6,6,1))
			durable_world_check(istype(startup_roofed, /area/caribbean/roofed), "Startup roof constructor did not create its zone")
			var/datum/persistence_area_registry_epoch/old_epoch = persistence_area_epoch
			var/list/topology = zone_fixture_saved_topology()
			var/list/saved_ids = list()
			for(var/list/row in topology["zones"]) saved_ids[row["id"]] = TRUE
			var/list/allocator = topology["allocator"]
			durable_world_check(ticker.loadmap(), "Admission import failed: [map_storage.last_error]")
			durable_world_check(old_epoch != persistence_area_epoch, "Area registry epoch was not renewed")
			var/expired = FALSE
			try
				require_persistence_area_snapshot(old_epoch)
			catch(var/exception/stale)
				expired = findtext("[stale]", "snapshot expired") > 0
			durable_world_check(expired, "Pre-load registry snapshot was still accepted")
			var/published = 0
			for(var/area/A in area_list)
				durable_world_check(saved_ids[A.persistence_zone_id], "Published registry contains an unsaved zone")
				published++
			durable_world_check(published == saved_ids.len, "Published registry lacks a saved zone")
			durable_world_check(!(startup_roofed in area_list) && !(locate(/turf) in startup_roofed), "Startup-only roofed zone survived import")
			// Native areas may outlive retirement, but never with turf membership.
			for(var/area/A in world)
				durable_world_check((A in area_list) || !(locate(/turf) in A), "An unpublished area still owns turfs")
			durable_world_check(return_areas().len == published, "Registry reader differs from publication")
			var/area/caribbean/forest/late = new()
			durable_world_check(late in area_list, "Post-commit constructor was not admitted")
			late.contents += locate(8,1,1)
			durable_world_check(map_storage.Save_World(), "Save after import failed: [map_storage.last_error]")
			var/prefix = "zone:[allocator["namespace"]]:"
			durable_world_check(findtext(late.persistence_zone_id, prefix) == 1, "Post-load zone did not use the restored namespace")
			var/counter = copytext(late.persistence_zone_id, length(prefix) + 1)
			durable_world_check(counter == allocator["next"] || zone_counter_after(counter, allocator["next"]), "Post-load zone reused an issued counter")
			durable_world_check(!saved_ids[late.persistence_zone_id], "Post-load zone reused a saved identity")
		if("latejoin-read")
			durable_world_check(ticker.loadmap(), "Late-join import failed: [map_storage.last_error]")
			durable_world_check(persistence_spawns_authoritative, "Saved spawn registries were not authoritative")
			var/mob/living/human/durable_probe_leader/H = new(locate(1,4,1))
			for(var/group in list("deleted", "removed-group"))
				H.job_spawn_location = group
				durable_world_check(job_master.relocate(H) == FALSE && H.loc == locate(1,4,1), "Spawn group [group] invented a fallback destination")
			durable_world_check(!("removed-group" in latejoin_turfs) && islist(latejoin_turfs["deleted"]) && !latejoin_turfs["deleted"].len, "Empty and removed groups were changed by late-join")
			H.job_spawn_location = "moved"
			job_master.relocate(H)
			durable_world_check(H.loc == locate(3,3,2), "Saved spawn group did not admit late-join")
			// The documented remedy: an administrator places a new spawn point.
			new /obj/effect/landmark{name = "deleted"}(locate(5,5,1))
			durable_world_check(latejoin_turfs["deleted"].len == 1, "Administrator spawn point was refused after publication")
			H.job_spawn_location = "deleted"
			job_master.relocate(H)
			durable_world_check(H.loc == locate(5,5,1), "Administrator spawn point was not used")

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
		// Full startup normally supplies the job controller that round restore uses.
		job_master = new /datum/controller/occupations()
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
		if(mode in zone_fixture_extended_modes())
			zone_fixture_extended(mode, base)
		else if(mode in list("write-sequence", "read-sequence"))
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
					if("unsupported-schema") W["schema"] = 3
					if("unsupported-topology") topology["schema"] = 3
					else throw EXCEPTION("Unknown zone fixture mode")
				fdel("map_saves/round.json")
				text2file(json_encode(state), "map_saves/round.json")
				F = null
			if(negative)
				var/list/reasons = list("duplicate-spawn" = "Duplicate or stale spawn zone", "stale-zone" = "Duplicate or stale spawn zone", "wrong-z" = "Spawn outside saved world", "fractional" = "Spawn outside saved world", "duplicate-zone" = "Invalid or duplicate zone identity", "absent-zone" = "Captured zone membership differs", "incomplete" = "Captured zone membership differs", "overlong" = "Captured zone membership differs", "unsupported-schema" = "Unsupported zone metadata revision", "unsupported-topology" = "Invalid zone topology")
				zone_fixture_expect_rejection(base, reasons[mode])
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
