// Only roof transformations backed by direct saved turf contents are projected.
// No save bytes or world areas change during this preflight.
/map_storage
	var/list/validated_roof_areas = list()
	var/list/validated_roof_entries = list()
	var/list/validated_roof_types = list()
	var/list/validated_roof_instances = list()
	var/list/validated_roof_absent = list()
	var/restoring_roof_areas = FALSE

/map_storage/proc/clear_saved_roof_areas()
	validated_roof_areas = list()
	validated_roof_entries = list()
	validated_roof_types = list()
	validated_roof_instances = list()
	validated_roof_absent = list()
	restoring_roof_areas = FALSE

/map_storage/proc/saved_roof_area_type(climate)
	if(!(climate in list("tundra", "taiga", "temperate", "sea", "semiarid", "desert", "savanna", "jungle"))) return null
	return text2path("/area/caribbean/roofed/[climate]")

/map_storage/proc/find_saved_roof_area(type)
	var/area/found
	// New() registers empty explicit areas too; world enumeration alone need
	// not contain a destination which currently owns no turfs.
	var/list/candidates = area_list.Copy()
	for(var/area/A in world) candidates |= A
	for(var/area/A in candidates)
		// Empty explicit instances are ambiguous too. A later locate(type)
		// must never silently select a different instance from preflight.
		if(A.type != type) continue
		if(found) throw EXCEPTION("Ambiguous current roof area identity")
		found = A
	return found

/map_storage/proc/unique_saved_roof_area(type, recheck = FALSE)
	var/area/cached = validated_roof_instances["[type]"]
	if(cached && !recheck) return cached
	var/area/found = find_saved_roof_area(type)
	if(!found || (cached && cached != found)) throw EXCEPTION("Validated roof area instance changed")
	validated_roof_instances["[type]"] = found
	return found

/map_storage/proc/prepare_saved_roof_areas(generation)
	var/roof_root = text2path("/obj/roof")
	if(!ispath(roof_root)) return // Serializer-only fixtures can omit roofs.
	for(var/z = 1, z <= save_validation_maxz(), z++)
		if(!fexists("map_saves/[z].sav")) throw EXCEPTION("Missing saved roof level [z]")
		var/savefile/F = new("map_saves/[z].sav")
		var/version = F["/format_version"]
		if(version != 2 && version != 3) continue
		if((generation && F["/generation"] != generation) || F["/maxx"] != world.maxx || F["/maxy"] != world.maxy || F["/maxz"] != save_validation_maxz())
			throw EXCEPTION("Saved roof generation or dimensions differ")
		for(var/y = 1, y <= world.maxy, y++)
			for(var/x = 1, x <= world.maxx, x++)
				var/ref = F["/map/[z]/[y]/[x]"]
				if(!isnum(ref) || ref < 1 || ref != round(ref)) throw EXCEPTION("Missing roof-validation turf")
				var/turf_path = entry_path(F, ref)
				if(!ispath(F["[turf_path]/type"], /turf)) throw EXCEPTION("Invalid roof-validation turf")
				var/list/contents = saved_content_refs(F["[turf_path]/content"], version)
				for(var/child in contents)
					var/path = entry_path(F, child)
					var/type = F["[path]/type"]
					if(!ispath(type, roof_root)) continue
					var/key = "[x],[y],[z]"
					if(validated_roof_areas[key] || validated_roof_entries["[z]:[child]"])
						throw EXCEPTION("Ambiguous or multiply placed saved roof")
					if(validated_zone_state)
						prepare_zone_roof(F, x, y, z, child, type)
						continue
					// These fields are explicitly emitted by /obj/roof/get_saved_vars.
					// Do not guess missing legacy settings or decode an object graph here.
					var/list/switch_value = F["[path]/switch_area"]
					var/list/base_value = F["[path]/current_area_type"]
					if(!islist(switch_value) || switch_value["kind"] != "value" || !isnum(switch_value["value"]) || !(switch_value["value"] in list(TRUE, FALSE)) || !islist(base_value) || base_value["kind"] != "value" || !ispath(base_value["value"], /area))
						throw EXCEPTION("Saved roof lacks scalar area metadata")
					var/base_type = base_value["value"]
					var/turf/T = z <= world.maxz ? locate(x, y, z) : null
					var/current_type = T ? T.loc.type : world.area
					var/target_type
					var/underlying_type = current_type
					if(switch_value["value"])
						var/area/base = unique_saved_roof_area(base_type)
						target_type = saved_roof_area_type(base.vars["climate"])
						if(!ispath(target_type, /area)) throw EXCEPTION("Unsupported saved roof climate")
						if(current_type != base_type && current_type != target_type)
							throw EXCEPTION("Saved roof base area differs from the current map")
						underlying_type = base_type
					else
						// Disabled roofs never used current_area_type to choose their
						// turf's area. Preserve that saved field without treating it
						// as evidence for a transformation which did not occur.
						unique_saved_roof_area(current_type)
					var/list/row = list("x" = x, "y" = y, "z" = z, "entry" = "[child]", "type" = type, "base" = base_type, "unroofed" = underlying_type, "area" = target_type, "switch" = switch_value["value"])
					validated_roof_areas[key] = row
					validated_roof_entries["[z]:[child]"] = row
					if(target_type) validated_roof_types["[target_type]"] = target_type
				TICK_CHECK
	for(var/key in validated_roof_types)
		var/type = validated_roof_types[key]
		var/area/A = find_saved_roof_area(type)
		if(A || (key in validated_roof_instances))
			unique_saved_roof_area(type, TRUE)
		else
			// Only the destination derived from a proven saved roof may be
			// prospective. Base areas above remain required exact instances.
			validated_roof_absent[key] = type

/map_storage/proc/materialize_saved_roof_areas()
	if(validated_zone_state)
		restore_zone_topology()
		restoring_roof_areas = !!validated_roof_areas.len
		return
	// Recheck every retained identity, including empty base/roof instances,
	// before the first membership assignment. Never create or reselect by type.
	for(var/key in validated_roof_instances)
		var/area/A = validated_roof_instances[key]
		if(!A) throw EXCEPTION("Validated roof area instance disappeared")
		unique_saved_roof_area(A.type, TRUE)
	// Check every planned absence before creating anything or moving a turf.
	for(var/key in validated_roof_absent)
		var/type = validated_roof_absent[key]
		if(!ispath(type, /area/caribbean/roofed) || validated_roof_types[key] != type || (key in validated_roof_instances) || find_saved_roof_area(type))
			throw EXCEPTION("Planned roof area absence changed")
	for(var/key in validated_roof_absent)
		var/type = validated_roof_absent[key]
		if(find_saved_roof_area(type)) throw EXCEPTION("Planned roof area absence changed")
		var/area/A = new type()
		if(!A || A.type != type) throw EXCEPTION("Could not create validated roof destination")
		validated_roof_instances[key] = A
		unique_saved_roof_area(type, TRUE)
	validated_roof_absent = list()
	for(var/key in validated_roof_areas)
		var/list/row = validated_roof_areas[key]
		if(!row["area"]) continue
		var/turf/T = locate(row["x"], row["y"], row["z"])
		var/area/A = validated_roof_instances["[row["area"]]"]
		if(!T || !A) throw EXCEPTION("Validated roof area destination disappeared")
		A.contents += T
		TICK_CHECK
	restoring_roof_areas = !!validated_roof_areas.len

/map_storage/proc/restore_validated_roof(atom/roof)
	if(!restoring_roof_areas) return FALSE
	var/list/row = validated_roof_areas["[roof.x],[roof.y],[roof.z]"]
	if(!row || roof.type != row["type"]) throw EXCEPTION("Unvalidated roof constructor during import")
	if(validated_zone_state)
		if(roof.loc != locate(row["x"], row["y"], row["z"]) || roof.loc.loc != restored_zones[row["zone"]]) throw EXCEPTION("Restored roof zone changed")
		roof.vars["current_area_type"] = row["base"]
		roof.vars["switch_area"] = row["switch"]
		return TRUE
	var/turf/T = get_turf(roof)
	var/expected = row["area"] ? row["area"] : row["unroofed"]
	if(!T || T.loc != validated_roof_instances["[expected]"]) throw EXCEPTION("Validated roof topology changed during import")
	roof.vars["current_area_type"] = row["base"]
	roof.vars["switch_area"] = row["switch"]
	return TRUE

/map_storage/proc/is_loaded_validated_roof(atom/roof)
	if(!restoring_roof_areas || roof.z != loading_z) return FALSE
	var/list/row = validated_roof_areas["[roof.x],[roof.y],[roof.z]"]
	return row && row["z"] == loading_z && roof.type == row["type"] && validated_roof_entries["[loading_z]:[row["entry"]]"] == row && existing_references[row["entry"]] == roof

/map_storage/proc/verify_restored_roof_areas()
	for(var/key in validated_roof_areas)
		var/list/row = validated_roof_areas[key]
		var/turf/T = locate(row["x"], row["y"], row["z"])
		var/expected = row["area"] ? row["area"] : row["unroofed"]
		var/area/expected_area = validated_zone_state ? restored_zones[row["zone"]] : validated_roof_instances["[expected]"]
		if(!T || T.loc != expected_area) throw EXCEPTION("Restored roof area differs from validated topology")
		var/count = 0
		for(var/atom/roof in T.contents)
			if(roof.type != row["type"]) continue
			count++
			if(roof.vars["current_area_type"] != row["base"] || roof.vars["switch_area"] != row["switch"])
				throw EXCEPTION("Restored roof settings differ from validated payload")
		if(count != 1) throw EXCEPTION("Restored roof owner missing or duplicated")
		TICK_CHECK

/map_storage/proc/Load_Entry(savefile/savefile, var/ind, var/turf/old_turf, var/atom/starting_loc, var/atom/replacement, var/nocontents = 0, var/lag_fix = 0)
	try
		TICK_CHECK
		var/nextContents
		if(nocontents)
			nextContents = 2
		if(existing_references["[ind]"])
			if(starting_loc)
				var/atom/movable/A = existing_references["[ind]"]
				A.loc = starting_loc
			return existing_references["[ind]"]
		savefile.cd = entry_path(savefile, ind)
		var/type = savefile["type"]
		var/format_version = savefile["/format_version"]
		savefile.cd = entry_path(savefile, ind)
		if(!ispath(type, /datum))
			throw EXCEPTION("Invalid saved type at entry [ind]: [type]")
		// Older completed saves can contain client HUD graphs. Never construct
		// their screen/datum objects without the live client owner they require.
		if(ispath(type, /obj/screen) || ispath(type, /datum/hud) || ispath(type, /datum/action) || ispath(type, /obj/item/weapon/grab))
			return null
		// Historical saves can retain derived lighting graphs through item vars.
		// Their constructors require live owners/turfs; never import those graphs.
		if(ispath(type, /datum/light_source) || ispath(type, /datum/lighting_corner) || ispath(type, /atom/movable/lighting_overlay) || ispath(type, /atom/movable/lighting_fullbright))
			return null
		if(ispath(type, /obj/map_metadata))
			existing_references["[ind]"] = map
			return map
		var/datum/object
		if(ispath(type, /turf) && !old_turf)
			old_turf = saved_turfs["[ind]"]
			if(!old_turf)
				throw EXCEPTION("Missing coordinate for turf entry [ind]")
		// Map reservation policy is never restored from a save. Even same-type
		// and legacy entries activate their destination before payload construction.
		if (old_turf)
			old_turf.activate_reserved_lighting()
		if(lag_fix)
			so_far++
			if(so_far > per_pause)
				sleep(10)
				so_far = 0
		if(old_turf)
			var/xa = old_turf.x
			var/ya = old_turf.y
			var/za = old_turf.z
			old_turf.ChangeTurf(type, FALSE, FALSE)
			object = locate(xa,ya,za)
			var/turf/restored_turf = object
			restored_turf.activate_reserved_lighting()
			if (istype(restored_turf, /turf/floor))
				var/turf/floor/restored_floor = restored_turf
				restored_floor.irrigation_prepare_load()
			// Missing fields in legacy/clear-ground saves mean no generated snow.
			restored_turf.weather_snow = 0
			restored_turf.snowfall_ground_icon()
		else if(replacement)
			object = replacement
		else if(ispath(type, /atom))
			// A recursive field can reach a roof before its containing turf.
			// Only the already validated direct-content location is authoritative.
			var/list/roof = validated_roof_entries["[loading_z]:[ind]"]
			if(roof)
				var/turf/roof_turf = locate(roof["x"], roof["y"], roof["z"])
				if(starting_loc && starting_loc != roof_turf)
					throw EXCEPTION("Saved roof location changed during import")
				starting_loc = roof_turf
			object = new type(starting_loc)
		else if(ispath(type, /datum/wound/lost_limb))
			// The lost limb is not a constructor input during graph recovery.
			// Register an explicit shell before decoding cyclic organ references.
			object = new type(null, null, null, TRUE)
		else
			// Non-atom datums have no location argument. In particular, matrix
			// construction must use its no-argument identity initializer.
			object = new type()
		if(!object)
			throw EXCEPTION("Could not create saved entry [ind] ([type])")
		// Mark before field decoding can yield to the constructor's spawn callback.
		// This applies to unowned legacy humans as well as reclaimable players.
		if(ishuman(object))
			var/mob/living/human/restored_human = object
			restored_human.persistence_restored = TRUE
			savefile.cd = entry_path(savefile, ind)
			restored_human.human_subtile_prepare_import(savefile)
		if (istype(object, /mob/living/simple_animal))
			var/mob/living/simple_animal/restored_npc = object
			savefile.cd = entry_path(savefile, ind)
			restored_npc.npc_subtile_prepare_import(savefile)
		all_loaded += object
		existing_references["[ind]"] = object
		if(durable_import) durable_import.accept_entry(loading_z, ind, object)
		if(loading_level_link_targets["[loading_z]:[ind]"])
			loading_level_link_targets["[loading_z]:[ind]"] = object
		for(var/v in savefile.dir)
			savefile.cd = entry_path(savefile, ind)
			if(object.persistence_runtime_var(v))
#ifdef CIV13_VARIABLE_OBSERVABILITY
				variable_observability_skipped(null, TRUE)
#endif
				continue
			if(v == "type")
				continue
			else if(v in list("loc", "locs", "pixloc", "contents", "vars", "parent_type", "x", "y", "z", "vis_locs", "client", "key", "ckey"))
				continue
			else if(v == "content")
				if(nocontents != 2)
					var/list/refs = saved_content_refs(savefile[v], format_version)
					var/atom/container = object
					if(container)
						for(var/obj/ob in container.contents.Copy())
							if(istype(ob, /obj/map_metadata) || istype(ob, /atom/movable/lighting_overlay) || istype(ob, /atom/movable/lighting_fullbright))
								continue
							// A recursive field may have already imported this roof.
							// Do not delete the validated owner before reusing its ref.
							if(is_loaded_validated_roof(ob))
								continue
							if(ob.loc == container)
								qdel(ob)
					for(var/x in refs)
						Load_Entry(savefile, x, null, object, nocontents = nextContents, lag_fix = lag_fix)
			else if((format_version == 2 || format_version == 3) && is_level_link_value(savefile[v]))
				// The target may be on a later level; assign after all levels load.
				loading_level_link_fields += list(list(object, v, level_link_row(savefile[v])))
			else if(format_version == 2 || format_version == 3)
				object.vars[v] = decode_saved_value(savefile, savefile[v])
			else if(istext(savefile[v]) && findtext(savefile[v], "**list") == 1)
				var/x = savefile[v]
				var/list/fixed = string_explode(x, "list")
				x = fixed[2]
				var/list/lis = params2list(x)
				var/list/final_list = list()
				if(lis.len)
					for(var/xa in lis)
						if(findtext(xa, "**entry"))
							var/list/fixed2 = string_explode(xa, "entry")
							var/y = fixed2[2]
							var/atom/movable/A = Load_Entry(savefile, y, lag_fix = lag_fix)
							final_list += A
						else
							final_list += "**unique**"
							final_list[final_list.len] = Numeric(xa)
				object.vars[v] = final_list
			else if(istext(savefile[v]) && findtext(savefile[v], "**entry") == 1)
				var/x = savefile[v]
				var/list/fixed = string_explode(x, "entry")
				x = fixed[2]
				var/atom/movable/A = Load_Entry(savefile, x, nocontents = nextContents, lag_fix = lag_fix)
				object.vars[v] = A
			else if(savefile[v] == "**null")
				object.vars[v] = null
			else if(v == "req_access_txt")
				object.vars[v] = savefile[v]
			else if(savefile[v] == "**emptylist")
				object.vars[v] = list()
			else
				savefile.cd = entry_path(savefile, ind)
				object.vars[v] = savefile[v]
			savefile.cd = entry_path(savefile, ind)
			TICK_CHECK
		if(istype(object, /datum/wound/lost_limb))
			var/datum/wound/lost_limb/restored_wound = object
			restored_wound.validate_restored_state()
		savefile.cd = ".."
		if (ishuman(object))
			var/mob/living/human/H = object
			// A saved corpse must stay dead; do not replay death hooks on import.
			if (H.stat != DEAD && !H.persistence_owner_ckey)
				H.rejuvenate()
			if (!H.name && savefile["name"])
				H.name = savefile["name"]
		if(isturf(object))
			var/turf/coverage_turf = object
			coverage_turf.sync_fullbright_coverage()
		return object
	catch(var/exception/e)
		throw e

/map_storage/proc/decode_saved_value(savefile/F, list/value)
	if(!islist(value))
		throw EXCEPTION("Invalid typed saved value")
	switch(value["kind"])
		if("map")
			return map
		if("zone")
			validate_zone_reference(value["id"], value["type"])
			var/area/A = restored_zones[value["id"]]
			if(!A || A.persistence_zone_id != value["id"] || A.type != value["type"]) throw EXCEPTION("Zone reference was not restored")
			return A
		if("area")
			var/turf/T = locate(value["x"], value["y"], value["z"])
			if(!T || !istype(T.loc, value["type"]))
				throw EXCEPTION("Referenced area differs from the current map")
			return T.loc
		if("value")
			return value["value"]
		if("turf")
			var/turf/T = locate(value["x"], value["y"], value["z"])
			if(!T)
				throw EXCEPTION("Saved turf reference is outside the world")
			return T
		if("entry")
			if(!value["ref"])
				return null
			return Load_Entry(F, value["ref"])
		if("list")
			var/id = value["ref"]
			if(loaded_lists["[id]"])
				return loaded_lists["[id]"]
			var/list/L = list()
			loaded_lists["[id]"] = L
			var/length = F["/lists/[id]/length"]
			for(var/i = 1, i <= length, i++)
				var/encoded_key = F["/lists/[id]/[i]/key"]
				var/encoded_value = F["/lists/[id]/[i]/value"]
				var/key = decode_saved_value(F, encoded_key)
				var/associated_value = decode_saved_value(F, encoded_value)
				L.len++
				L[L.len] = key
				if(!isnum(key) && !isnull(associated_value))
					L[key] = associated_value
			return L
	throw EXCEPTION("Unknown saved value kind: [value["kind"]]")
/map_storage/proc/Load_World()
	return run_world_operation("load")

/map_storage/proc/load_world_contents(datum/persistence_world_operation/operation)
	if(!operation || !operation.enter_contents(src, "load")) return FALSE
	var/datum/extraction_surface_service/surface_inventory
	if (istype(map, /obj/map_metadata/extraction_survival))
		var/obj/map_metadata/extraction_survival/M = map
		surface_inventory = M.surface_service
		if (surface_inventory && !surface_inventory.begin_world_inventory(world.maxz)) return FALSE
	if(validated_zone_state)
		if(!operation.zone_restore) begin_zone_restore(operation)
		operation.zone_restore.clearing_old_world = FALSE
	// Allocate all levels first so references to turfs on later levels stay valid.
	for(var/z = 1, z <= world.maxz, z++)
		var/savefile/F = new("map_saves/[z].sav")
#ifdef CIV13_HUMAN_SPATIAL_EXPERIMENTAL
		if(operation.human_direct_preflight_generation && F["/generation"] != operation.human_direct_preflight_generation) throw EXCEPTION("Human direct generation changed after preflight")
#endif
		for(var/y = 1, y <= world.maxy, y++)
			for(var/x = 1, x <= world.maxx, x++)
				var/ref = F["/map/[z]/[y]/[x]"]
				var/type = F["[entry_path(F, ref)]/type"]
				var/turf/T = locate(x,y,z)
				T.ChangeTurf(type, FALSE, FALSE)
				TICK_CHECK
	// References may precede the roof object in the saved graph. Rebuild only
	// the roof topology proven by preflight, before any object fields decode.
	materialize_saved_roof_areas()
	begin_level_link_import()
	for(var/B = 1, B <= world.maxz, B++)
		loading_z = B
		try
			var/watch = start_watch()
			existing_references = list()
			all_loaded = list()
			loaded_lists = list()
			if(!fexists("map_saves/[B].sav"))
				throw EXCEPTION("Missing saved level [B]")
			var/savefile/savefile = new("map_saves/[B].sav")
#ifdef CIV13_HUMAN_SPATIAL_EXPERIMENTAL
			if(operation.human_direct_preflight_generation && savefile["/generation"] != operation.human_direct_preflight_generation) throw EXCEPTION("Human direct generation changed during import")
#endif
			saved_turfs = list()
			// Index every turf before recursive contents/variable references load.
			for(var/ty = 1, ty <= world.maxy, ty++)
				for(var/tx = 1, tx <= world.maxx, tx++)
					savefile.cd = "/map/[B]/[ty]"
					var/ref = savefile["[tx]"]
					saved_turfs["[ref]"] = locate(tx, ty, B)
			savefile.cd = "/map"
			TICK_CHECK
			for(var/z in savefile.dir)
				savefile.cd = "/map/[z]"
				for(var/y in savefile.dir)
					savefile.cd = "/map/[z]/[y]"
					for(var/x in savefile.dir)
						var/turf_ref = savefile["[x]"]
						if(!turf_ref)
							message_admins("turf_ref not found, x: [x]")
							continue
						var/turf/old_turf = locate(text2num(x), text2num(y), text2num(z))
						Load_Entry(savefile, turf_ref, old_turf)
						savefile.cd = "/map/[z]/[y]"
						TICK_CHECK
			for(var/i in 1 to all_loaded.len)
				var/datum/ob = all_loaded[i]
				if (ob)
					ob.after_load()
					register_restored_player(ob)
				if(istype(ob, /obj))
					var/obj/obbie = ob
					if(obbie.load_datums)
						if(obbie.reagents)
							obbie.reagents.my_atom = ob
#ifdef CIV13_HUMAN_SPATIAL_EXPERIMENTAL
			// Check the actual local placement after all level callbacks, including
			// neighbouring objects whose physical bounds overhang the tile.
			var/list/final_placement_entries = all_loaded
			for(var/mob/living/human/H in final_placement_entries)
				if(!operation.current(src, "load") || all_loaded != final_placement_entries || loading_z != B) throw EXCEPTION("Load ownership changed during human placement validation")
				if(!QDELETED(H) && !H.gcDestroyed && !H.human_saved_tile_final_clear()) throw EXCEPTION("Restored human tile is obstructed")
				TICK_CHECK
			if(!operation.current(src, "load") || all_loaded != final_placement_entries || loading_z != B) throw EXCEPTION("Load ownership changed during human placement validation")
#endif
			if (surface_inventory && !surface_inventory.feed_loaded_level(B, all_loaded)) throw EXCEPTION("Surface world identity inventory requires recovery")
			// Constructors see defaults before saved fields/contents are restored.
			// Rebuild obstruction caches before queuing any final source updates.
			var/list/lighting_entries = all_loaded
			for(var/turf/light_turf in lighting_entries)
				if(!QDELETED(light_turf) && !light_turf.gcDestroyed) light_turf.recalc_atom_opacity()
				if(TICK_CHECK)
					if(!operation.current(src, "load") || all_loaded != lighting_entries || loading_z != B) throw EXCEPTION("Load ownership changed during lighting restoration")
			for(var/atom/light_owner in lighting_entries)
				if(!QDELETED(light_owner) && !light_owner.gcDestroyed) light_owner.update_light()
				if(TICK_CHECK)
					if(!operation.current(src, "load") || all_loaded != lighting_entries || loading_z != B) throw EXCEPTION("Load ownership changed during lighting restoration")
			log_startup_progress("	Loaded z-level [B] in [stop_watch(watch)]s.")
		catch(var/exception/e)
			if (surface_inventory) surface_inventory.discovery_fail()
			clear_saved_roof_areas()
			last_error = "[e] on [e.file]:[e.line]"
			world.log << "World-save restoration failed: [last_error]"
			message_admins("EXCEPTION IN MAP LOADING!! [e] on [e.file]:[e.line]")
			clear_bookkeeping()
			saved_turfs = list()
			return FALSE
	try
		restore_level_links()
	catch(var/exception/link_error)
		if (surface_inventory) surface_inventory.discovery_fail()
		clear_saved_roof_areas()
		last_error = "[link_error] on [link_error.file]:[link_error.line]"
		world.log << "World-save restoration failed: [last_error]"
		message_admins("EXCEPTION IN MAP LOADING!! [link_error] on [link_error.file]:[link_error.line]")
		clear_bookkeeping()
		saved_turfs = list()
		return FALSE
	verify_restored_roof_areas()
	clear_bookkeeping()
	clear_saved_roof_areas()
	saved_turfs = list()
	if (surface_inventory)
		while (!surface_inventory.world_inventory_complete)
			if (!surface_inventory.finish_world_inventory()) return FALSE
			TICK_CHECK
	log_startup_progress("Finished loading.")
	return TRUE

// A failed preflight must leave the running world untouched. Historical saves
// use the same grid; the completion marker is required by the startup contract.
/map_storage/proc/validate_world_save()
	var/list/candidate = zone_candidate_validation
	last_error = null
	clear_saved_roof_areas()
	release_durable_world()
	clear_saved_zones()
	validated_level_links = null
#ifdef CIV13_HUMAN_SPATIAL_EXPERIMENTAL
	if(!candidate && persistence_active_operation && persistence_active_operation.current(src, "load"))
		persistence_active_operation.human_direct_preflight_generation = null
#endif
	try
		if(candidate && (!persistence_active_operation || !persistence_active_operation.current(src, "save") || candidate["generation"] != zone_export_generation)) throw EXCEPTION("Unowned candidate validation")
		if((!candidate && !fexists("map_saves/save_complete.txt")) || !fexists("map_saves/map.txt"))
			throw EXCEPTION("Save is incomplete: metadata or completion marker missing")
		var/list/meta = splittext(file2text("map_saves/map.txt"), "\n")
		if(meta.len < 9 || meta[1] != map.ID)
			throw EXCEPTION("Save metadata does not match the current map")
		var/list/round_state = candidate ? candidate : read_round_state()
		var/list/player_owners = list()
		var/list/level_links = round_state["level_links"]
		if(level_links) validate_level_link_rows(level_links)
		if(isnull(round_mode_metadata(meta)))
			throw EXCEPTION("Save round-mode metadata is malformed")
		prepare_saved_zones(round_state["world_state"], round_state["generation"])
		prepare_saved_roof_areas(round_state["generation"])
		for(var/z = 1, z <= save_validation_maxz(), z++)
			if(!fexists("map_saves/[z].sav"))
				throw EXCEPTION("Missing saved z-level [z]")
			var/savefile/F = new("map_saves/[z].sav")
			if(round_state.len && F["/generation"] != round_state["generation"])
				throw EXCEPTION("Saved level belongs to another round generation")
			var/version = F["/format_version"]
			if(version && version != 2 && version != 3)
				throw EXCEPTION("Unsupported save version [version]")
			if((version == 2 || version == 3) && (F["/maxx"] != world.maxx || F["/maxy"] != world.maxy || F["/maxz"] != save_validation_maxz()))
				throw EXCEPTION("Saved world dimensions differ from the current world")
			var/list/validated_lists = list()
			var/list/turf_refs = list()
#ifdef CIV13_HUMAN_SPATIAL_EXPERIMENTAL
			var/list/human_direct_parents = list()
			var/list/human_direct_parent_counts = list()
			var/list/human_direct_entries = list()
#endif
			F.cd = "/map"
			if(F.dir.len != 1 || !("[z]" in F.dir))
				throw EXCEPTION("Unexpected z-level grid in [z].sav")
			F.cd = "/map/[z]"
			if(F.dir.len != world.maxy)
				throw EXCEPTION("Saved height differs from world.maxy on z=[z]")
			for(var/y = 1, y <= world.maxy, y++)
				F.cd = "/map/[z]/[y]"
				if(F.dir.len != world.maxx)
					throw EXCEPTION("Incomplete row at y=[y], z=[z]")
				for(var/x = 1, x <= world.maxx, x++)
					F.cd = "/map/[z]/[y]"
					var/ref = F["[x]"]
					if(!isnum(ref) || ref < 1 || ref != round(ref) || turf_refs["[ref]"])
						throw EXCEPTION("Missing or duplicate turf at [x],[y],[z]")
					turf_refs["[ref]"] = TRUE
					F.cd = entry_path(F, ref)
					var/type = F["type"]
					if(!ispath(type, /turf))
						throw EXCEPTION("Invalid turf type at [x],[y],[z]")
					if(ispath(type, /turf/floor))
						validate_saved_irrigation(F, version)
					TICK_CHECK
			F.cd = "/entries"
			var/list/entries = F.dir.Copy()
			if(version == 2 || version == 3)
				var/list/shards = entries
				entries = list()
				for(var/shard in shards)
					F.cd = "/entries/[shard]"
					entries += F.dir.Copy()
			var/list/entry_set = list()
			for(var/ref in entries)
				entry_set["[ref]"] = TRUE
				TICK_CHECK
			for(var/ref in entries)
				TICK_CHECK
				F.cd = entry_path(F, ref)
				var/type = F["type"]
				if(!ispath(type, /datum) || ispath(type, /area) || (ispath(type, /turf) && !turf_refs["[ref]"]))
					throw EXCEPTION("Unsupported or unplaced saved entry [ref] on z=[z]")
				if(ispath(type, /mob/living/human))
					validate_saved_player_owner(F, ref, player_owners)
				var/list/fields = F.dir.Copy()
				if("human_subtile_restore_schema" in fields)
#ifdef CIV13_HUMAN_SPATIAL_EXPERIMENTAL
					if(!candidate && (!persistence_active_operation || !persistence_active_operation.current(src, "load"))) throw EXCEPTION("Human direct preflight lacks its load owner")
					if(type != /mob/living/human || human_candidate_scalar(F["human_subtile_restore_schema"]) != 1) throw EXCEPTION("Human direct restore schema is invalid")
					human_direct_entries += "[ref]"
#else
					throw EXCEPTION("Human direct restore schema is unavailable")
#endif
				for(var/field in fields)
					F.cd = entry_path(F, ref)
					var/value = F[field]
					if(field == "type")
						continue
					if(field == "content")
						for(var/content_ref in saved_content_refs(value, version))
							if(!entry_set["[content_ref]"])
								throw EXCEPTION("Missing content entry [content_ref] on z=[z]")
							var/content_type = F["[entry_path(F, content_ref)]/type"]
							if(!ispath(content_type, /atom/movable))
								throw EXCEPTION("Non-movable entry in saved contents on z=[z]")
#ifdef CIV13_HUMAN_SPATIAL_EXPERIMENTAL
							var/child_key = "[content_ref]"
							var/old_count = human_direct_parent_counts[child_key]
							human_direct_parent_counts[child_key] = (isnum(old_count) ? old_count : 0) + 1
							human_direct_parents[child_key] = "[ref]"
#endif
					else if((version == 2 || version == 3) && is_level_link_value(value))
						if(!level_links || !validate_level_link_value(value, level_links))
							throw EXCEPTION("Invalid cross-level link on z=[z]")
					else if(version == 2 || version == 3)
						validate_saved_value(F, value, entry_set, validated_lists)
					else if(istext(value) && findtext(value, "**entry") == 1)
						if(!entry_set[copytext(value, 8)])
							throw EXCEPTION("Missing legacy referenced entry on z=[z]")
					else if(istext(value) && findtext(value, "**list") == 1)
						for(var/item in params2list(copytext(value, 7)))
							if(findtext(item, "**entry") == 1 && !entry_set[copytext(item, 8)])
								throw EXCEPTION("Missing legacy list entry on z=[z]")
#ifdef CIV13_HUMAN_SPATIAL_EXPERIMENTAL
			// Historical schema-1 capsules remain readable. Validate their old
			// parent/tile identity, but never restore their fractional offsets.
			for(var/human_ref in human_direct_entries)
				var/parent_ref = human_direct_parents[human_ref]
				var/list/position = human_candidate_read_position(F, text2num(human_ref))
				if(human_direct_parent_counts[human_ref] != 1 || !turf_refs[parent_ref] || !islist(position) || position["z"] != z || position["x"] < 1 || position["x"] > world.maxx || position["y"] < 1 || position["y"] > world.maxy || position["sx"] < 0 || position["sx"] >= 32 || position["sy"] < 0 || position["sy"] >= 32 || (!position["sx"] && !position["sy"])) throw EXCEPTION("Historical human saved origin is invalid")
				if("[human_candidate_map_ref(F, z, position["y"], position["x"])]" != "[parent_ref]") throw EXCEPTION("Historical human saved origin is invalid")
#endif
		if(level_links) validate_level_link_targets(level_links, round_state["generation"])
		if(round_state["version"] == 2) validate_durable_world(round_state["world_state"], round_state["generation"])
		// Candidate validation during export never authorizes a later import.
		if(!candidate)
			validated_level_links = level_links ? level_links.Copy() : list()
#ifdef CIV13_HUMAN_SPATIAL_EXPERIMENTAL
			if(persistence_active_operation && persistence_active_operation.current(src, "load")) persistence_active_operation.human_direct_preflight_generation = round_state["generation"]
#endif
		return TRUE
	catch(var/exception/e)
#ifdef CIV13_HUMAN_SPATIAL_EXPERIMENTAL
		if(!candidate && persistence_active_operation && persistence_active_operation.current(src, "load"))
			persistence_active_operation.human_direct_preflight_generation = null
#endif
		validated_level_links = null
		clear_saved_roof_areas()
		clear_saved_zones()
		release_durable_world()
		last_error = "[e] on [e.file]:[e.line]"
		world.log << "World-save preflight rejected: [last_error]"
		message_admins("Save rejected before clearing the world: [e]")
		return FALSE

/map_storage/proc/validate_saved_value(savefile/F, list/value, list/entries, list/visited)
	if(!islist(value))
		throw EXCEPTION("Invalid typed saved value")
	switch(value["kind"])
		if("map")
			return TRUE
		if("zone")
			return validate_zone_reference(value["id"], value["type"])
		if("area")
			if(!ispath(value["type"], /area))
				throw EXCEPTION("Invalid saved area type")
			var/area_type = save_validation_area_type(value["x"], value["y"], value["z"])
			if(!ispath(area_type, value["type"]))
				throw EXCEPTION("Referenced area differs from the current map")
			return TRUE
		if("value")
			return TRUE
		if("entry")
			if(value["ref"] && !entries["[value["ref"]]"])
				throw EXCEPTION("Missing saved referenced entry [value["ref"]]")
			return TRUE
		if("turf")
			for(var/axis in list("x", "y", "z"))
				var/coordinate = value[axis]
				if(!isnum(coordinate) || coordinate < 1 || coordinate != round(coordinate))
					throw EXCEPTION("Invalid saved turf coordinate")
			if(!save_validation_coordinate(value["x"], value["y"], value["z"]))
				throw EXCEPTION("Saved turf reference is outside world dimensions")
			return TRUE
		if("list")
			var/id = value["ref"]
			if(visited["[id]"])
				return TRUE
			visited["[id]"] = TRUE
			var/length = F["/lists/[id]/length"]
			if(!isnum(length) || length < 0 || length != round(length))
				throw EXCEPTION("Missing or invalid saved list [id]")
			for(var/i = 1, i <= length, i++)
				TICK_CHECK
				var/key = F["/lists/[id]/[i]/key"]
				var/associated_value = F["/lists/[id]/[i]/value"]
				validate_saved_value(F, key, entries, visited)
				validate_saved_value(F, associated_value, entries, visited)
			return TRUE
	throw EXCEPTION("Unknown saved value kind")

// Large flat savefile directories make repeated entry navigation expensive.
// Legacy files remain flat; new files cap each entry directory at 512 children.
/map_storage/proc/entry_path(savefile/F, ref)
	if(F["/format_version"] == 2 || F["/format_version"] == 3)
		return "/entries/[round((text2num("[ref]") - 1) / 512)]/[ref]"
	return "/entries/[ref]"

// Restores the world-level state written at the top of Save_World(). Load_World()
// only rebuilds turfs (see the /turf/ check in Load_Entry()), so without this the
// epoch and research progress would reset to map defaults on every reload.
/map_storage/proc/round_mode_metadata(list/metadata)
	if(!islist(metadata)) return null
	var/list/meta = metadata.Copy()
	// text2file may append a newline; it is not an additional positional field.
	if(meta.len > 9 && meta[meta.len] == "") meta.Cut(meta.len)
	if(meta.len == 9 || meta.len == 10) return list()
	if(meta.len != 14) return null
	var/list/keys = list("persistence", "research_active", "resourceresearch", "perschadplus")
	var/list/modes = list()
	for(var/i = 1, i <= keys.len, i++)
		var/value = meta[10 + i]
		if(value != "0" && value != "1") return null
		modes[keys[i]] = text2num(value)
	return modes

/map_storage/proc/load_map_metadata()
	if (!map || !fexists("map_saves/map.txt"))
		return FALSE
	var/list/meta = splittext(file2text("map_saves/map.txt"), "\n")
	if (meta.len < 9 || meta[1] != map.ID)
		return FALSE
	var/list/round_modes = round_mode_metadata(meta)
	if(isnull(round_modes)) return FALSE
	map.age = meta[2]
	map.ordinal_age = text2num(meta[3])
	map.default_research = text2num(meta[4])
	map.autoresearch = text2num(meta[5])
	map.autoresearch_mult = text2num(meta[6])
	map.chad_mode = text2num(meta[7])
	map.chad_mode_plus = text2num(meta[8])
	map.gamemode = meta[9]
	for(var/key in round_modes) map.vars[key] = round_modes[key]
	map.age1_done = (map.ordinal_age >= 1)
	map.age2_done = (map.ordinal_age >= 2)
	map.age3_done = (map.ordinal_age >= 3)
	map.age4_done = (map.ordinal_age >= 4)
	map.age5_done = (map.ordinal_age >= 5)
	map.age6_done = (map.ordinal_age >= 6)
	map.age7_done = (map.ordinal_age >= 7)
	map.age8_done = (map.ordinal_age >= 8)
	log_startup_progress("	Restored world metadata (epoch: [map.age], research: [map.default_research]).")
	return TRUE

/map_storage/proc/saved_content_refs(value, version)
	if(version != 3)
		if(!istext(value) && !isnull(value)) throw EXCEPTION("Invalid legacy saved contents")
		return params2list(value)
	if(!islist(value)) throw EXCEPTION("Invalid version-3 saved contents")
	var/list/refs = list()
	for(var/chunk in value)
		if(!istext(chunk) || length(chunk) > 32000)
			throw EXCEPTION("Invalid saved content chunk")
		var/list/part = params2list(chunk)
		if(part.len > 500) throw EXCEPTION("Oversized saved content chunk")
		refs += part
		TICK_CHECK
	return refs

// Cross-level link rows are bounded JSON from round state: target level, entry
// and exact type. Values in level files carry only the row index.
/map_storage/proc/validate_level_link_rows(list/rows)
	if(!islist(rows) || !rows.len || rows.len > 1000000)
		throw EXCEPTION("Invalid cross-level link inventory")
	var/list/seen = list()
	for(var/list/row in rows)
		if(!islist(row) || row.len != 3 || !("z" in row) || !("ref" in row) || !("type" in row))
			throw EXCEPTION("Invalid cross-level link row")
		var/z = row["z"]
		var/ref = row["ref"]
		var/type = istext(row["type"]) ? text2path(row["type"]) : null
		if(!isnum(z) || z < 1 || z != round(z) || z > save_validation_maxz() || !isnum(ref) || ref < 1 || ref != round(ref) || !ispath(type, /atom/movable) || ispath(type, /obj/screen) || ispath(type, /mob/new_player))
			throw EXCEPTION("Invalid cross-level link target identity")
		if(seen["[z]:[ref]"])
			throw EXCEPTION("Duplicate cross-level link target")
		seen["[z]:[ref]"] = TRUE
	if(rows.len != seen.len)
		throw EXCEPTION("Invalid cross-level link inventory")
	return TRUE

/map_storage/proc/is_level_link_value(value)
	if(!islist(value))
		return FALSE
	var/list/L = value
	return L["kind"] == "level_link"

/map_storage/proc/validate_level_link_value(list/value, list/rows)
	if(value.len != 2 || !("id" in value))
		return FALSE
	var/id = value["id"]
	return isnum(id) && id >= 1 && id == round(id) && id <= rows.len

// Every target must be an entry of the same generation which normal contents
// loading reaches from a turf; an orphan entry would never be constructed.
/map_storage/proc/validate_level_link_targets(list/rows, generation)
	for(var/z = 1, z <= save_validation_maxz(), z++)
		var/list/wanted = list()
		for(var/list/row in rows)
			if(row["z"] == z) wanted["[row["ref"]]"] = row["type"]
		if(!wanted.len) continue
		var/savefile/F = new("map_saves/[z].sav")
		if(generation && F["/generation"] != generation)
			throw EXCEPTION("Cross-level link target belongs to another generation")
		for(var/ref in wanted)
			if("[F["[entry_path(F, ref)]/type"]]" != wanted[ref])
				throw EXCEPTION("Cross-level link target differs from its saved level")
		var/list/queue = list()
		var/list/seen = list()
		for(var/y = 1, y <= world.maxy, y++)
			for(var/x = 1, x <= world.maxx, x++) queue += F["/map/[z]/[y]/[x]"]
		var/cursor = 1
		while(cursor <= queue.len && wanted.len)
			TICK_CHECK
			var/ref = "[queue[cursor++]]"
			if(seen[ref]) continue
			seen[ref] = TRUE
			wanted -= ref
			var/path = entry_path(F, ref)
			var/type = F["[path]/type"]
			if(ispath(type, /obj/screen) || ispath(type, /datum/hud)) continue
			for(var/child in saved_content_refs(F["[path]/content"], F["/format_version"])) queue += child
		if(wanted.len) throw EXCEPTION("Cross-level link references an unreachable world entry")

/map_storage/proc/begin_level_link_import()
	loading_level_links = validated_level_links
	validated_level_links = null
	loading_level_link_targets = list()
	loading_level_link_fields = list()
	if(!loading_level_links) return
	for(var/list/row in loading_level_links)
		loading_level_link_targets["[row["z"]]:[row["ref"]]"] = TRUE

/map_storage/proc/level_link_row(list/value)
	if(!loading_level_links || !validate_level_link_value(value, loading_level_links))
		throw EXCEPTION("Cross-level link was not admitted by preflight")
	return loading_level_links[value["id"]]

/map_storage/proc/restore_level_links()
	for(var/list/pending in loading_level_link_fields)
		var/datum/owner = pending[1]
		var/list/row = pending[3]
		var/atom/movable/target = loading_level_link_targets["[row["z"]]:[row["ref"]]"]
		if(!istype(target, /atom/movable) || "[target.type]" != row["type"])
			throw EXCEPTION("Cross-level link target was not restored: type=[row["type"]]")
		if(owner) owner.vars[pending[2]] = target
		TICK_CHECK
	loading_level_link_fields = list()
	loading_level_link_targets = list()
	loading_level_links = null
