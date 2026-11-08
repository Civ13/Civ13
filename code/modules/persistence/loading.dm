// Only roof transformations backed by direct saved turf contents are projected.
// No save bytes or world areas change during this preflight.
/map_storage
	var/list/validated_roof_areas = list()
	var/list/validated_roof_entries = list()
	var/list/validated_roof_types = list()
	var/list/validated_roof_instances = list()
	var/list/validated_roof_absent = list()
	var/restoring_roof_areas = FALSE
	// Levels whose roofs the entry walk projects (prepare_saved_roof_areas
	// hands them over when the walk reads the level in full).
	var/list/validated_roof_walk_levels = list()
	// Durable metadata targets ("z:ref") the entry walk proved reachable from
	// a turf, and whether the validation record stood in for that walk.
	var/list/validated_reachable_entries = list()
	var/validated_entries_trusted = FALSE

/map_storage/proc/clear_saved_roof_areas()
	validated_roof_areas = list()
	validated_roof_entries = list()
	validated_roof_types = list()
	validated_roof_instances = list()
	validated_roof_absent = list()
	restoring_roof_areas = FALSE
	validated_roof_walk_levels = list()

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
	if(validated_entries_trusted && islist(validated_record_roofs))
		// The trusted record projected these from the same files: replay them
		// instead of reading every turf of every level back.
		prepare_record_roofs(validated_record_roofs, roof_root)
		return
	for(var/z = 1, z <= save_validation_maxz(), z++)
		if(!fexists("map_saves/[z].sav")) throw EXCEPTION("Missing saved roof level [z]")
		var/savefile/F = new("map_saves/[z].sav")
		var/version = F["/format_version"]
		if(version == 4 || version == 5) version = level_content_version(F)
		if(version != 2 && version != 3) continue
		if((generation && F["/generation"] != generation) || F["/maxx"] != world.maxx || F["/maxy"] != world.maxy || F["/maxz"] != save_validation_maxz())
			throw EXCEPTION("Saved roof generation or dimensions differ")
		// A stream save's candidate check takes the roofs it just wrote from
		// its structural record (saving.dm) instead of reading every turf back.
		var/list/structure = candidate_structure_record(z)
		if(structure)
			var/list/rows = structure["roofs"]
			for(var/list/roof in rows)
				var/key = "[roof["x"]],[roof["y"]],[z]"
				if(validated_roof_areas[key] || validated_roof_entries["[z]:[roof["entry"]]"])
					throw EXCEPTION("Ambiguous or multiply placed saved roof")
				prepare_saved_roof(null, roof["x"], roof["y"], z, roof["entry"], roof["type"], roof["switch"], roof["base"])
				TICK_CHECK
			continue
		if(!validated_entries_trusted)
			// validate_world_save walks every entry of this level and projects
			// its roofs as it meets them, instead of a second read here.
			validated_roof_walk_levels["[z]"] = TRUE
			continue
		// A sparse level's unsaved cells hold nothing, so only its saved cells
		// can carry a roof.
		var/list/sparse = sparse_level_header(F)
		var/list/sparse_cells = sparse ? sparse_level_cells(F, z, sparse) : null
		for(var/y = 1, y <= world.maxy, y++)
			var/list/columns = sparse_cells ? sparse_cells["[y]"] : null
			if(sparse_cells && !columns) continue
			var/next_column = 1
			for(var/x = 1, x <= world.maxx, x++)
				if(columns)
					if(next_column > columns.len || columns[next_column] != x) continue
					next_column++
				var/ref = F["/map/[z]/[y]/[x]"]
				if(!isnum(ref) || ref < 1 || ref != round(ref)) throw EXCEPTION("Missing roof-validation turf")
				if(!ispath(level_entry_value(F, ref, "type"), /turf)) throw EXCEPTION("Invalid roof-validation turf")
				var/list/contents = saved_content_refs(level_entry_value(F, ref, "content"), version)
				for(var/child in contents)
					var/type = level_entry_value(F, child, "type")
					if(!ispath(type, roof_root)) continue
					var/key = "[x],[y],[z]"
					if(validated_roof_areas[key] || validated_roof_entries["[z]:[child]"])
						throw EXCEPTION("Ambiguous or multiply placed saved roof")
					if(validated_zone_state)
						prepare_zone_roof(level_entry_file(F, child), x, y, z, child, type)
						continue
					// These fields are explicitly emitted by /obj/roof/get_saved_vars.
					// Do not guess missing legacy settings or decode an object graph here.
					prepare_saved_roof(F, x, y, z, child, type, persistence_saved_scalar(level_entry_value(F, child, "switch_area")), persistence_saved_scalar(level_entry_value(F, child, "current_area_type")))
				TICK_CHECK

/map_storage/proc/prepare_record_roofs(list/rows, roof_root)
	for(var/list/roof in rows)
		var/z = roof["z"]
		var/type = istext(roof["type"]) ? text2path(roof["type"]) : null
		var/base = istext(roof["base"]) ? text2path(roof["base"]) : null
		if(!isnum(z) || z < 1 || z > save_validation_maxz() || !isnum(roof["x"]) || !isnum(roof["y"]) || !istext(roof["entry"]) || !ispath(type, roof_root) || !ispath(base, /area))
			throw EXCEPTION("Malformed roof in the validation record")
		var/key = "[roof["x"]],[roof["y"]],[z]"
		if(validated_roof_areas[key] || validated_roof_entries["[z]:[roof["entry"]]"])
			throw EXCEPTION("Ambiguous or multiply placed saved roof")
		prepare_saved_roof(null, roof["x"], roof["y"], z, roof["entry"], type, roof["switch"], base)
		TICK_CHECK

// Once every level's roofs are projected: the destination areas they need.
/map_storage/proc/finish_saved_roof_areas()
	for(var/key in validated_roof_types)
		var/type = validated_roof_types[key]
		var/area/A = find_saved_roof_area(type)
		if(A || (key in validated_roof_instances))
			unique_saved_roof_area(type, TRUE)
		else
			// Only the destination derived from a proven saved roof may be
			// prospective. Base areas above remain required exact instances.
			validated_roof_absent[key] = type

// One saved roof's area metadata, from its saved fields (the read-back) or the
// live object a stream save just wrote (F is null then; prepare_zone_roof
// gets the values instead of a file).
/map_storage/proc/prepare_saved_roof(savefile/F, x, y, z, child, type, switch_value, base_type)
	var/key = "[x],[y],[z]"
	if(!F && validated_zone_state)
		prepare_zone_roof(null, x, y, z, child, type, switch_value, base_type)
		return
	if(!isnum(switch_value) || !(switch_value in list(TRUE, FALSE)) || !ispath(base_type, /area))
		throw EXCEPTION("Saved roof lacks scalar area metadata")
	var/turf/T = z <= world.maxz ? locate(x, y, z) : null
	var/current_type = T ? T.loc.type : world.area
	var/target_type
	var/underlying_type = current_type
	if(switch_value)
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
	var/list/row = list("x" = x, "y" = y, "z" = z, "entry" = "[child]", "type" = type, "base" = base_type, "unroofed" = underlying_type, "area" = target_type, "switch" = switch_value)
	validated_roof_areas[key] = row
	validated_roof_entries["[z]:[child]"] = row
	if(target_type) validated_roof_types["[target_type]"] = target_type

// The structural record a stream save kept for level z while it is the
// candidate under validation, or null (read-back path).
/map_storage/proc/candidate_structure_record(z)
	if(!zone_candidate_validation || !saving_candidate_structure) return null
	return saving_candidate_structure["[z]"]

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

// Restore contract hooks (restore_contract.dm overrides them for atoms).
// Called after an entry's saved fields are applied, before
// persistence_import_fields; saved_fields lists the field names it recorded.
/datum/proc/persistence_reset_omitted_fields(list/saved_fields)
	return
// Called once after after_load() for every entry of the level.
/datum/proc/persistence_restore_finished()
	return

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
		// A segmented level keeps this entry in one of its segment files.
		savefile = level_entry_file(savefile, ind)
		var/entry_dir = entry_path(savefile, ind)
		savefile.cd = entry_dir
		var/type = savefile["type"]
		var/format_version = savefile["/format_version"]
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
			// A saved atom first reached through another entry's field (a limb's
			// parent or children) has no holder yet. Its owner is restored as a
			// field below, so constructors must not discard it as an orphan.
			persistence_saved_atom_construction++
			try
				object = new type(starting_loc)
			catch(var/exception/construct_error)
				persistence_saved_atom_construction--
				throw construct_error
			persistence_saved_atom_construction--
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
			savefile.cd = entry_dir
			restored_human.human_subtile_prepare_import(savefile)
		if (istype(object, /mob/living/simple_animal))
			var/mob/living/simple_animal/restored_npc = object
			savefile.cd = entry_dir
			restored_npc.npc_subtile_prepare_import(savefile)
		all_loaded += object
		existing_references["[ind]"] = object
		if(durable_import) durable_import.accept_entry(loading_z, ind, object)
		if(loading_level_link_targets["[loading_z]:[ind]"])
			loading_level_link_targets["[loading_z]:[ind]"] = object
		for(var/v in savefile.dir)
			savefile.cd = entry_dir
			if(object.persistence_runtime_var(v))
#ifdef CIV13_VARIABLE_OBSERVABILITY
				variable_observability_skipped(null, TRUE)
#endif
				continue
			switch(v)
				if("type", "loc", "locs", "pixloc", "contents", "vars", "parent_type", "x", "y", "z", "vis_locs", "client", "key", "ckey")
					continue
			if(v == "content")
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
				savefile.cd = entry_dir
				object.vars[v] = savefile[v]
			savefile.cd = entry_dir
			TICK_CHECK
		// The saver omits map_storage_saved_vars scalars still at their compiled
		// default. Constructors may have changed them (random turf states), so
		// restore the default the save recorded by omission.
		var/list/default_fields = object.persistence_field_allowlist()
		if(default_fields)
			savefile.cd = entry_dir
			var/list/saved_fields = savefile.dir
			for(var/v in default_fields)
				if((v in saved_fields) || !(v in object.vars) || object.persistence_runtime_var(v))
					continue
				var/default_value = initial(object.vars[v])
				if(persistence_default_scalar(default_value) && object.vars[v] != default_value)
					object.vars[v] = default_value
		// Let a type rebuild state its saved fields describe only by presence.
		savefile.cd = entry_dir
		var/list/import_fields = savefile.dir.Copy()
		object.persistence_reset_omitted_fields(import_fields)
		object.persistence_import_fields(import_fields)
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

// Value format 2 stores a scalar list as one node; returns it once validated,
// or null when the list uses the per-edge layout.
/map_storage/proc/saved_scalar_list(savefile/LF, id)
	var/list/node = LF["/lists/[id]"]
	if(isnull(node)) return null
	var/count = node["length"]
	var/list/keys = node["keys"]
	var/list/values = node["values"]
	if(node["kind"] != "scalars" || !isnum(count) || count < 0 || count != round(count) || !islist(keys) || !islist(values) || keys.len != count || values.len != count)
		throw EXCEPTION("Missing or invalid saved list [id]")
	for(var/i = 1, i <= count, i++)
		if(!persistence_default_scalar(keys[i]) || !persistence_default_scalar(values[i]))
			throw EXCEPTION("Invalid saved scalar list [id]")
	return node

/map_storage/proc/decode_saved_value(savefile/F, list/value)
	if(!islist(value))
		return persistence_saved_scalar(value)
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
			var/savefile/LF = level_list_file(F, id)
			var/length = LF["/lists/[id]/length"]
			if(isnull(length))
				var/list/node = saved_scalar_list(LF, id)
				if(!node) throw EXCEPTION("Missing or invalid saved list [id]")
				var/list/keys = node["keys"]
				var/list/values = node["values"]
				L.len = keys.len
				for(var/i = 1, i <= keys.len, i++)
					var/key = keys[i]
					L[i] = key
					if(!isnum(key) && !isnull(key) && !isnull(values[i]))
						L[key] = values[i]
				return L
			for(var/i = 1, i <= length, i++)
				var/encoded_key = LF["/lists/[id]/[i]/key"]
				var/encoded_value = LF["/lists/[id]/[i]/value"]
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
	if(plan_low_memory("load"))
		log_startup_progress("Low-memory world load: [last_low_memory_plan].")
		if(split_large_full_file_levels()) log_startup_progress("Split large saved levels into segments; loading one segment at a time.")
	// Floors are replaced level by level; their icons refresh once per level
	// after its entries load (floor.dm), not on every neighbour placement.
	set_floor_icon_updates_deferred(TRUE)
	try
		// Allocate all levels first so references to turfs on later levels stay valid.
		for(var/z = 1, z <= world.maxz, z++)
			var/savefile/F = new("map_saves/[z].sav")
#ifdef CIV13_HUMAN_SPATIAL_EXPERIMENTAL
			if(operation.human_direct_preflight_generation && F["/generation"] != operation.human_direct_preflight_generation) throw EXCEPTION("Human direct generation changed after preflight")
#endif
			var/list/sparse = sparse_level_header(F)
			if(sparse)
				// Unsaved cells are the baseline: a restored level already holds it,
				// a reloaded one is reset to it. Saved cells take their saved type.
				var/list/cells = sparse_level_cells(F, z, sparse)
				var/baseline = sparse["turf"]
				for(var/y = 1, y <= world.maxy, y++)
					var/list/columns = cells["[y]"]
					var/next = 1
					for(var/x = 1, x <= world.maxx, x++)
						var/turf/T = locate(x,y,z)
						if(columns && next <= columns.len && columns[next] == x)
							next++
							T.ChangeTurf(level_entry_value(F, F["/map/[z]/[y]/[x]"], "type"), FALSE, FALSE)
						else if(T.type != baseline)
							T.ChangeTurf(baseline, FALSE, FALSE)
					TICK_CHECK
				continue
			// The preflight's turf types (full walk or trusted record) spare a read
			// of every turf entry; Load_Entry still applies each saved type.
			var/list/grid = validated_turf_grid(z)
			var/cell = 0
			for(var/y = 1, y <= world.maxy, y++)
				for(var/x = 1, x <= world.maxx, x++)
					var/type
					if(grid) type = grid[++cell]
					if(!type) type = level_entry_value(F, F["/map/[z]/[y]/[x]"], "type")
					var/turf/T = locate(x,y,z)
					T.ChangeTurf(type, FALSE, FALSE)
					TICK_CHECK
		// References may precede the roof object in the saved graph. Rebuild only
		// the roof topology proven by preflight, before any object fields decode.
		materialize_saved_roof_areas()
		begin_level_link_import()
	catch(var/exception/allocation_error)
		// The caller rethrows; the world keeps running, so floors must redraw again.
		set_floor_icon_updates_deferred(FALSE)
		throw allocation_error
	for(var/B = 1, B <= world.maxz, B++)
		loading_z = B
		try
			var/watch = start_watch()
			// Deferred while this level's entries are placed; the refresh below
			// rebuilds every floor of the level once, then after_load and the
			// next level's work refresh neighbours as they change turfs.
			set_floor_icon_updates_deferred(TRUE)
			existing_references = alist()
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
			var/list/sparse_level = sparse_level_header(savefile)
			if(sparse_level)
				var/list/cells = sparse_level_cells(savefile, B, sparse_level)
				for(var/row in cells)
					for(var/tx in cells[row])
						saved_turfs["[savefile["/map/[B]/[row]/[tx]"]]"] = locate(tx, text2num(row), B)
					TICK_CHECK
			else
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
			// A ground level's unsaved cells were plain turfs: restore them the way
			// Load_Entry restores a turf entry that holds only its type.
			if(sparse_level && sparse_level["kind"] == "ground")
				restore_sparse_ground_cells(savefile, B, sparse_level)
			// Every floor of the level is placed and its fields restored: rebuild
			// each icon once before after_load adds snow and irrigation overlays.
			refresh_deferred_floor_icons_level(B)
			set_floor_icon_updates_deferred(FALSE)
			for(var/i in 1 to all_loaded.len)
				var/datum/ob = all_loaded[i]
				if (ob)
					ob.after_load()
					register_restored_player(ob)
					ob.persistence_restore_finished()
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
			report_load_memory(B, stop_watch(watch))
		catch(var/exception/e)
			set_floor_icon_updates_deferred(FALSE)
			if (surface_inventory) surface_inventory.discovery_fail()
			clear_saved_roof_areas()
			last_error = "[e] on [e.file]:[e.line]"
			world.log << "World-save restoration failed: [last_error]"
			message_admins("EXCEPTION IN MAP LOADING!! [e] on [e.file]:[e.line]")
			clear_bookkeeping()
			saved_turfs = list()
			return FALSE
	set_floor_icon_updates_deferred(FALSE)
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
	// An unreadable round state reports an empty capture; the agent then holds
	// if it has confirmed anything, instead of trusting the reloaded world.
	var/list/transfer_round_state = null
	try
		transfer_round_state = read_round_state()
	catch
		transfer_round_state = null
	transfer_loaded(transfer_round_state)
	try
		restore_dug_levels()
	catch(var/exception/cave_error)
		world.log << "Dug underground lighting was not rebuilt: [cave_error]"
	log_startup_progress("Finished loading.")
	return TRUE

// Validation record. A full preflight writes map_saves/validated.json: the
// running build, a checksum of every file of that generation and the roofs the
// walk projected. A later preflight on the same build whose files still match
// skips the per-entry walk and takes the roofs from the record instead of
// reading every level back; metadata, zones and level links are still
// prepared. A different build, a changed or damaged file, or a missing record
// falls back to the full check.
//
// A handover save writes a "candidate" record from its structural check
// instead: only the handover itself trusts it (the saving world's identity
// checks and the standby's load), because there the standby's import is the
// validation and a failed import leaves the old world running.
var/global/persistence_boot_build_identity = persistence_build_identity()

// Hashed at boot: a binary recompiled while the world runs must not vouch for
// files the old binary wrote. Shard regions run region.dmb, the standalone
// server civ13.dmb, and a staged handover boots the spare slot region.b.dmb;
// DM cannot name the running binary, so every one present is hashed and a
// rebuild of any changes the identity. DreamMaker output is byte-identical for
// identical source, so the per-start recompile keeps it.
/proc/persistence_build_identity(list/names = list("civ13.dmb", "region.dmb", "region.b.dmb"))
	var/list/parts = list()
	for(var/name in names)
		if(!fexists(name)) continue
		var/digest = md5(file(name))
		if(!digest) return null
		parts += "[name]=[digest]"
	if(!parts.len) return null
	return "[world.byond_version].[world.byond_build]:[jointext(parts, ",")]"

/map_storage
	var/save_build_identity = null // Fixtures pin a build identity here.
	var/last_validation_note
	// TRUE after a validate_world_save() that walked every saved field; the
	// validation record may only vouch for files after such a walk.
	var/tmp/last_validation_full = FALSE
	// Candidate validation during a save checks the files' structure (grid,
	// entry set and types, owners, contents) and trusts the field values, which
	// the export just wrote from objects still pinned in memory. Debug recovery
	// sets this so the candidate gets the full walk.
	var/tmp/candidate_full_walk = FALSE
	// TRUE while a handover owns the save: its save writes a candidate record
	// and its preflights (the saving world's and the standby's) trust one.
	var/tmp/handover_candidate = FALSE
	// The roofs of the validation record the last preflight trusted, or null.
	var/tmp/list/validated_record_roofs
	// Each full level's turf types ("z" -> one type per cell, row by row), from
	// the full walk or the trusted record, so the load's turf pass need not read
	// every turf entry back. Encoded in the record by turf_grid_runs().
	var/tmp/list/validated_turf_grids = list()
	var/tmp/list/validated_record_turfs

/map_storage/proc/current_build_identity()
	return save_build_identity ? save_build_identity : persistence_boot_build_identity

/map_storage/proc/validation_record_checksums(maxz)
	var/list/names = list("map.txt", "round.json")
	for(var/z = 1, z <= maxz, z++)
		names += "[z].sav"
		names += level_segment_files("map_saves/", z)
	var/list/sums = list()
	for(var/name in names)
		if(!fexists("map_saves/[name]")) return null
		var/digest = md5(file("map_saves/[name]"))
		if(!digest) return null
		sums[name] = digest
	return sums

/map_storage/proc/clear_validation_record()
	if(fexists("map_saves/validated.json") && !fdel("map_saves/validated.json"))
		throw EXCEPTION("Could not remove the previous validation record")

// The projected roofs, as the inputs prepare_saved_roof takes, for the record.
// A level's turf types as runs: "types" names each distinct type, "runs" holds
// (type index, cell count) pairs in row order.
/proc/turf_grid_runs(list/grid)
	var/list/types = list()
	var/list/index_of = list()
	var/list/runs = list()
	var/last
	var/count = 0
	for(var/i = 1, i <= grid.len, i++)
		var/type = "[grid[i]]"
		if(count && type == last)
			count++
			continue
		if(count) runs += list(index_of[last], count)
		if(!index_of[type])
			types += type
			index_of[type] = types.len
		last = type
		count = 1
	if(count) runs += list(index_of[last], count)
	return list("types" = types, "runs" = runs)

// The turf types of level z from the trusted record or the full walk, or null.
/map_storage/proc/validated_turf_grid(z)
	var/list/grid = validated_turf_grids["[z]"]
	if(islist(grid)) return grid
	var/list/encoded = islist(validated_record_turfs) ? validated_record_turfs["[z]"] : null
	if(!islist(encoded)) return null
	var/list/types = encoded["types"]
	var/list/runs = encoded["runs"]
	if(!islist(types) || !islist(runs) || runs.len % 2) return null
	var/list/paths = list()
	for(var/name in types)
		var/path = istext(name) ? text2path(name) : null
		if(!ispath(path, /turf)) return null
		paths += path
	grid = list()
	for(var/i = 1, i <= runs.len, i += 2)
		var/index = runs[i]
		var/count = runs[i + 1]
		if(!isnum(index) || index < 1 || index > paths.len || !isnum(count) || count < 1 || grid.len + count > world.maxx * world.maxy) return null
		var/path = paths[index]
		for(var/n = 1, n <= count, n++) grid += path
	if(grid.len != world.maxx * world.maxy) return null
	validated_turf_grids["[z]"] = grid
	return grid

/map_storage/proc/validation_record_turfs(list/grids = validated_turf_grids)
	var/list/encoded = list()
	for(var/z in grids)
		var/list/grid = grids[z]
		if(islist(grid) && grid.len == world.maxx * world.maxy) encoded[z] = turf_grid_runs(grid)
	return encoded

/map_storage/proc/validation_record_roofs()
	var/list/rows = list()
	for(var/key in validated_roof_areas)
		var/list/row = validated_roof_areas[key]
		rows += list(list("x" = row["x"], "y" = row["y"], "z" = row["z"], "entry" = "[row["entry"]]", "type" = "[row["type"]]", "switch" = row["switch"], "base" = "[row["base"]]"))
	return rows

// Called after the completion marker, only for a candidate that validated, or
// after a full preflight. kind "candidate" is a handover save's structural check.
/map_storage/proc/write_validation_record(generation, maxz = world.maxz, kind = "full", list/roofs = null, list/turf_grids = null)
	var/build = current_build_identity()
	if(!build) return FALSE
	var/list/sums = validation_record_checksums(maxz)
	if(!sums) return FALSE
	if(!roofs) roofs = validation_record_roofs()
	var/list/record = list("version" = 2, "kind" = kind, "build" = build, "generation" = generation, "maxx" = world.maxx, "maxy" = world.maxy, "maxz" = maxz, "files" = sums, "roofs" = roofs, "turfs" = validation_record_turfs(turf_grids ? turf_grids : validated_turf_grids))
	clear_validation_record() // text2file appends.
	return !!text2file(json_encode(record), "map_saves/validated.json")

/map_storage/proc/validation_record_matches(generation, maxz)
	validated_record_roofs = null
	validated_record_turfs = null
	var/build = current_build_identity()
	if(!build) return "no build identity"
	if(!fexists("map_saves/validated.json")) return "no validation record"
	var/list/record
	try
		record = json_decode(file2text("map_saves/validated.json"))
	catch
		return "unreadable validation record"
	if(!islist(record) || record["version"] != 2 || !(record["kind"] in list("full", "candidate")) || !islist(record["roofs"])) return "unreadable validation record"
	if(record["kind"] == "candidate")
		// The handover's own structural check; the standby's import proves the rest.
		if(!handover_candidate) return "only a handover trusts a save's own check"
	else if(record["build"] != build) return "saved by a different build"
	if(!generation || record["generation"] != generation || record["maxz"] != maxz) return "record is for another generation"
	if(record["maxx"] != world.maxx || record["maxy"] != world.maxy) return "record is for other world dimensions"
	if(!fexists("map_saves/save_complete.txt") || trim(file2text("map_saves/save_complete.txt")) != generation) return "record is for another generation"
	var/list/expected = record["files"]
	var/list/current = validation_record_checksums(maxz)
	if(!islist(expected) || !current || expected.len != current.len) return "saved files changed"
	for(var/name in current)
		if(expected[name] != current[name]) return "[name] changed since it was validated"
	validated_record_roofs = record["roofs"]
	validated_record_turfs = islist(record["turfs"]) ? record["turfs"] : null
	return null

// An interrupted save: a crash or power-down after the save removed the
// completion marker and before it wrote the new one leaves map_saves/ with
// files but no marker, so startup refuses it. The whole previous generation was
// copied to map_backups/ before any level was replaced (save_world_contents),
// so when that copy is complete and marked it is put back and startup goes on.
// scripts/gaia-host does the same swap before starting the process; this is
// the path for a world started by hand. Nothing is restored while a restart
// intent exists: the restart transaction owns that recovery.
/map_storage/proc/recover_interrupted_save()
	if(fexists("map_saves/save_complete.txt") || fexists("map_saves/restart_intent.json")) return FALSE
	var/interrupted = FALSE
	for(var/name in flist("map_saves/"))
		if(name == "map.txt" || name == "round.json" || copytext(name, max(1, length(name)-3)) == ".sav")
			interrupted = TRUE
			break
	if(!interrupted) return FALSE
	if(!fexists("map_backups/save_complete.txt") || !fexists("map_backups/round.json") || !fexists("map_backups/map.txt"))
		world.log << "Interrupted save found and map_backups/ holds no completed generation; map_saves/ left as it is."
		return FALSE
	var/generation = trim(file2text("map_backups/save_complete.txt"))
	var/list/round_state
	try
		round_state = json_decode(file2text("map_backups/round.json"))
	catch
		round_state = null
	var/metadata_text = file2text("map_backups/map.txt")
	var/list/meta = istext(metadata_text) ? splittext(metadata_text, "\n") : list()
	var/maxz = islist(round_state) ? round_state["maxz"] : null
	if(!islist(round_state) || round_state["generation"] != generation || copytext(generation, 1, 7) != "round-" || !isnum(maxz) || maxz < 1 || maxz > 255 || round_state["metadata"] != md5(metadata_text) || meta.len < 9 || meta[1] != map.ID)
		world.log << "Interrupted save found but map_backups/ is not a complete generation for this map; map_saves/ left as it is."
		return FALSE
	for(var/z = 1, z <= maxz, z++)
		if(!fexists("map_backups/[z].sav"))
			world.log << "Interrupted save found but map_backups/ lacks level [z]; map_saves/ left as it is."
			return FALSE
	world.log << "Interrupted save in map_saves/ (no completion marker); restoring the completed generation [generation] from map_backups/."
	// The marker goes last, so a second interruption here still reads as interrupted.
	for(var/name in flist("map_saves/"))
		if(name == "map.txt" || name == "round.json" || name == "validated.json" || copytext(name, max(1, length(name)-3)) == ".sav")
			if(!fdel("map_saves/[name]")) throw EXCEPTION("Could not remove interrupted file map_saves/[name]")
	for(var/name in flist("map_backups/"))
		if(name == "map.txt" || name == "round.json" || copytext(name, max(1, length(name)-3)) == ".sav")
			if(!fcopy("map_backups/[name]", "map_saves/[name]")) throw EXCEPTION("Could not restore map_backups/[name]")
	if(!fcopy("map_backups/save_complete.txt", "map_saves/save_complete.txt")) throw EXCEPTION("Could not restore the completion marker")
	persistence_game_log("Restored generation [generation] from map_backups/ after an interrupted save.")
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
	validated_record_roofs = null
	validated_record_turfs = null
	validated_turf_grids = list()
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
		// The per-entry walk below is what the validation record can stand in for.
		var/trusted = FALSE
		// A save's candidate check reads each entry's type, owner and contents
		// but not its other fields: the export wrote them moments ago from the
		// live objects, and the next preflight on disk walks them in full.
		var/walk_fields = !candidate || candidate_full_walk
		last_validation_note = null
		last_validation_full = FALSE
		if(candidate)
			last_validation_note = walk_fields ? "candidate full check" : "candidate structural check (field values trusted from the export; the next preflight walks them)"
		if(!candidate)
#ifdef CIV13_HUMAN_SPATIAL_EXPERIMENTAL
			last_validation_note = "full check (human spatial prototype)"
#else
			var/mismatch = validation_record_matches(round_state["generation"], save_validation_maxz())
			trusted = !mismatch
			last_validation_note = trusted ? "skipped the entry check: files match the save this build validated" : "full check ([mismatch])"
#endif
			world.log << "World-save preflight: [last_validation_note]."
			persistence_game_log("World-save preflight: [last_validation_note].")
		validated_entries_trusted = trusted
		validated_reachable_entries = list()
		validated_roof_walk_levels = list()
		// Roofs on a level the walk reads in full are projected by the walk
		// (prepare_saved_roof_areas hands those levels over); the rest are
		// read here.
		prepare_saved_roof_areas(round_state["generation"])
		var/list/durable_targets = durable_entry_targets(round_state)
		var/roof_root = text2path("/obj/roof")
		var/screen_root = text2path("/obj/screen")
		var/hud_root = text2path("/datum/hud")
		// Area references are checked once every level's roofs are projected.
		var/list/pending_areas = list()
		if(world.maxx >= 4096 || world.maxy >= 4096) throw EXCEPTION("World too wide for the preflight cell index")
		for(var/z = 1, z <= save_validation_maxz(), z++)
			if(!fexists("map_saves/[z].sav"))
				throw EXCEPTION("Missing saved z-level [z]")
			if(trusted) continue
			var/savefile/F = new("map_saves/[z].sav")
			if(round_state.len && F["/generation"] != round_state["generation"])
				throw EXCEPTION("Saved level belongs to another round generation")
			var/version = level_content_version(F)
			if(version && version != 2 && version != 3)
				throw EXCEPTION("Unsupported save version [version]")
			if((version == 2 || version == 3) && (F["/maxx"] != world.maxx || F["/maxy"] != world.maxy || F["/maxz"] != save_validation_maxz()))
				throw EXCEPTION("Saved world dimensions differ from the current world")
			// A stream save checked this level's structure from the pinned
			// objects as it wrote it (record_candidate_level_structure): entry
			// types, turf placement, content edges, player owners and roofs.
			// The helper proved every referenced entry and list exists when it
			// published the stream, and prepare_saved_zones proved the grid
			// above. The next preflight on disk walks the values in full.
			var/list/structure = candidate_structure_record(z)
			if(structure)
				if(F["/format_version"] != 5 || !isnum(structure["entries"])) throw EXCEPTION("Candidate structure record does not match the saved level")
				continue
			var/project_roofs = roof_root && validated_roof_walk_levels["[z]"]
			var/list/validated_lists = list()
			// Grid turf entry -> y * 4096 + x. The entry's type, irrigation
			// fields and contents are checked when the walk reaches it, so
			// the grid pass reads the index alone.
			var/list/turf_refs = list()
#ifdef CIV13_HUMAN_SPATIAL_EXPERIMENTAL
			var/list/human_direct_parents = list()
			var/list/human_direct_parent_counts = list()
			var/list/human_direct_entries = list()
#endif
			// A sparse level's grid holds its saved cells only; the header and
			// each coordinate are checked by sparse_level_cells (functions.dm).
			var/list/sparse = sparse_level_header(F)
			var/list/sparse_cells = sparse ? sparse_level_cells(F, z, sparse) : null
			// The walk fills each full level's turf types for the load's turf
			// pass and the validation record.
			var/list/turf_grid = sparse ? null : new /list(world.maxx * world.maxy)
			if(turf_grid) validated_turf_grids["[z]"] = turf_grid
			if(!sparse)
				F.cd = "/map"
				if(F.dir.len != 1 || !("[z]" in F.dir))
					throw EXCEPTION("Unexpected z-level grid in [z].sav")
				F.cd = "/map/[z]"
				if(F.dir.len != world.maxy)
					throw EXCEPTION("Saved height differs from world.maxy on z=[z]")
			for(var/y = 1, y <= world.maxy, y++)
				var/list/columns = sparse_cells ? sparse_cells["[y]"] : null
				if(sparse_cells && !columns) continue
				if(!sparse)
					F.cd = "/map/[z]/[y]"
					if(F.dir.len != world.maxx)
						throw EXCEPTION("Incomplete row at y=[y], z=[z]")
				var/next_column = 1
				for(var/x = 1, x <= world.maxx, x++)
					if(columns)
						if(next_column > columns.len || columns[next_column] != x) continue
						next_column++
					F.cd = "/map/[z]/[y]"
					var/ref = F["[x]"]
					if(!isnum(ref) || ref < 1 || ref != round(ref) || turf_refs["[ref]"])
						throw EXCEPTION("Missing or duplicate turf at [x],[y],[z]")
					turf_refs["[ref]"] = y * 4096 + x
				TICK_CHECK
			var/list/entries
			if(F["/format_version"] == 4 || F["/format_version"] == 5)
				entries = level_segment_entries(F)
			else
				F.cd = "/entries"
				entries = F.dir.Copy()
			if(F["/format_version"] != 4 && F["/format_version"] != 5 && (version == 2 || version == 3))
				var/list/shards = entries
				entries = list()
				for(var/shard in shards)
					F.cd = "/entries/[shard]"
					entries += F.dir.Copy()
			// One pass over the entries proves the level: each entry's type,
			// its placement, owner and fields, every content edge, each roof's
			// turf and the ancestry of the durable metadata targets. Reading a
			// stream level materializes its shards, so every extra pass cost
			// about as much as the walk itself.
			var/list/entry_set = list()
			// Roof entry -> list(type, switch_area, current_area_type).
			var/list/roof_fields = list()
			// Content edges whose child entry the walk has not reached yet.
			var/list/pending_children = list()
			var/list/pending_parents = list()
			// Referenced entries the walk has not reached yet.
			var/list/pending_refs = list()
			// Durable metadata targets on this level and, as the walk finds
			// them, their containers up to a turf.
			var/list/tracked = list()
			var/list/parent_of = list()
			var/level_prefix = "[z]:"
			for(var/key in durable_targets)
				if(findtext(key, level_prefix) == 1) tracked[copytext(key, length(level_prefix) + 1)] = TRUE
			// An export numbers a container before the contents it writes,
			// so walking the entries in reverse meets each child before the
			// parent that lists it: content edges resolve as they are read.
			for(var/index = entries.len, index >= 1, index--)
				TICK_CHECK
				var/ref = entries[index]
				var/key = "[ref]"
				var/savefile/E = level_entry_file(F, ref)
				var/entry_dir = entry_path(E, ref)
				E.cd = entry_dir
				var/type = E["type"]
				if(entry_set[key]) throw EXCEPTION("Duplicate saved entry [ref] on z=[z]")
				entry_set[key] = isnull(type) ? TRUE : type
				var/cell = turf_refs[key]
				if(!ispath(type, /datum) || ispath(type, /area) || (ispath(type, /turf) && !cell))
					throw EXCEPTION("Unsupported or unplaced saved entry [ref] on z=[z]")
				if(cell)
					if(!ispath(type, /turf))
						throw EXCEPTION("Invalid turf type at [cell % 4096],[round(cell / 4096)],[z]")
					if(turf_grid) turf_grid[(round(cell / 4096) - 1) * world.maxx + cell % 4096] = type
					if(ispath(type, /turf/floor))
						validate_saved_irrigation(E, version)
						E.cd = entry_dir
				if(ispath(type, /mob/living/human))
					validate_saved_player_owner(E, ref, player_owners)
					E.cd = entry_dir
				var/list/fields = E.dir.Copy()
				if("human_subtile_restore_schema" in fields)
#ifdef CIV13_HUMAN_SPATIAL_EXPERIMENTAL
					if(!candidate && (!persistence_active_operation || !persistence_active_operation.current(src, "load"))) throw EXCEPTION("Human direct preflight lacks its load owner")
					if(type != /mob/living/human || human_candidate_scalar(E["human_subtile_restore_schema"]) != 1) throw EXCEPTION("Human direct restore schema is invalid")
					human_direct_entries += "[ref]"
#else
					throw EXCEPTION("Human direct restore schema is unavailable")
#endif
				if(project_roofs && ispath(type, roof_root))
					// These fields are explicitly emitted by /obj/roof/get_saved_vars.
					// Do not guess missing legacy settings or decode an object graph here.
					if(!("switch_area" in fields) || !("current_area_type" in fields)) throw EXCEPTION("Missing saved roof settings")
					roof_fields[key] = list(type, E["switch_area"], E["current_area_type"])
				for(var/field in fields)
					if(field == "type")
						continue
					if(!walk_fields && field != "content")
						continue
					E.cd = entry_dir
					var/value = E[field]
					if(field == "content")
						for(var/content_ref in saved_content_refs(value, version))
							var/child_key = "[content_ref]"
							if(tracked[child_key] && !parent_of[child_key])
								parent_of[child_key] = key
								tracked[key] = TRUE
#ifdef CIV13_HUMAN_SPATIAL_EXPERIMENTAL
							var/old_count = human_direct_parent_counts[child_key]
							human_direct_parent_counts[child_key] = (isnum(old_count) ? old_count : 0) + 1
							human_direct_parents[child_key] = key
#endif
							var/child_type = entry_set[child_key]
							if(child_type)
								validate_saved_content_edge(z, child_key, child_type, cell, roof_fields)
							else
								pending_children += child_key
								pending_parents += key
					else if((version == 2 || version == 3) && is_level_link_value(value))
						if(!level_links || !validate_level_link_value(value, level_links))
							throw EXCEPTION("Invalid cross-level link on z=[z]")
					else if(version == 2 || version == 3)
						validate_saved_value(F, value, entry_set, validated_lists, pending_refs, pending_areas)
					else if(istext(value) && findtext(value, "**entry") == 1)
						pending_refs[copytext(value, 8)] = TRUE
					else if(istext(value) && findtext(value, "**list") == 1)
						for(var/item in params2list(copytext(value, 7)))
							if(findtext(item, "**entry") == 1) pending_refs[copytext(item, 8)] = TRUE
			// Content edges and references that pointed past the walk.
			for(var/i = 1, i <= pending_children.len, i++)
				var/child_key = pending_children[i]
				var/child_type = entry_set[child_key]
				if(!child_type) throw EXCEPTION("Missing content entry [child_key] on z=[z]")
				validate_saved_content_edge(z, child_key, child_type, turf_refs[pending_parents[i]], roof_fields)
				if(i % 1024 == 0) TICK_CHECK
			for(var/key in pending_refs)
				if(!entry_set[key]) throw EXCEPTION("Missing saved referenced entry [key]")
			var/checked = 0
			for(var/key in turf_refs)
				if(!entry_set[key]) throw EXCEPTION("Missing turf entry [key] on z=[z]")
				if(++checked % 4096 == 0) TICK_CHECK
			// A durable target whose containers the walk recorded up to a
			// turf is reachable; validate_durable_reachability reads the
			// level back for any it could not follow.
			for(var/key in durable_targets)
				if(findtext(key, level_prefix) != 1) continue
				var/cursor = copytext(key, length(level_prefix) + 1)
				var/steps = 0
				while(cursor && !turf_refs[cursor])
					var/parent = parent_of[cursor]
					var/parent_type = parent ? entry_set[parent] : null
					if(!parent || (screen_root && ispath(parent_type, screen_root)) || (hud_root && ispath(parent_type, hud_root)) || ++steps > entries.len)
						cursor = null
					else
						cursor = parent
				if(cursor) validated_reachable_entries[key] = TRUE
#ifdef CIV13_HUMAN_SPATIAL_EXPERIMENTAL
			// Historical schema-1 capsules remain readable. Validate their old
			// parent/tile identity, but never restore their fractional offsets.
			for(var/human_ref in human_direct_entries)
				var/parent_ref = human_direct_parents[human_ref]
				var/list/position = human_candidate_read_position(F, text2num(human_ref))
				if(human_direct_parent_counts[human_ref] != 1 || !turf_refs[parent_ref] || !islist(position) || position["z"] != z || position["x"] < 1 || position["x"] > world.maxx || position["y"] < 1 || position["y"] > world.maxy || position["sx"] < 0 || position["sx"] >= 32 || position["sy"] < 0 || position["sy"] >= 32 || (!position["sx"] && !position["sy"])) throw EXCEPTION("Historical human saved origin is invalid")
				if("[human_candidate_map_ref(F, z, position["y"], position["x"])]" != "[parent_ref]") throw EXCEPTION("Historical human saved origin is invalid")
#endif
		finish_saved_roof_areas()
		for(var/key in pending_areas)
			var/list/row = pending_areas[key]
			var/area_type = save_validation_area_type(row[1], row[2], row[3])
			if(!ispath(area_type, row[4]))
				throw EXCEPTION("Referenced area differs from the current map")
		if(level_links) validate_level_link_targets(level_links, round_state["generation"])
		if(round_state["version"] == 2) validate_durable_world(round_state["world_state"], round_state["generation"])
		last_validation_full = walk_fields && !trusted
		// Candidate validation during export never authorizes a later import.
		if(!candidate)
			validated_level_links = level_links ? level_links.Copy() : list()
#ifdef CIV13_HUMAN_SPATIAL_EXPERIMENTAL
			if(persistence_active_operation && persistence_active_operation.current(src, "load")) persistence_active_operation.human_direct_preflight_generation = round_state["generation"]
#else
			// A full preflight proved these files on this build: record it so the
			// restart transaction's repeated identity checks and the next startup
			// skip the walk. The record only speeds up later checks.
			if(last_validation_full && istext(round_state["generation"]) && current_build_identity())
				try
					if(!write_validation_record(round_state["generation"], save_validation_maxz())) world.log << "Validation record not written after the full preflight; later checks run in full."
				catch(var/exception/record_error)
					world.log << "Validation record failed after the full preflight: [record_error]"
#endif
		drop_segment_reader() // Preflight keeps no segment handles open.
		return TRUE
	catch(var/exception/e)
		drop_segment_reader()
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

// pending_refs and pending_areas defer the entry and area checks of a walk
// that has not read every entry or projected every roof yet (validate_world_save).
/map_storage/proc/validate_saved_value(savefile/F, list/value, list/entries, list/visited, list/pending_refs, list/pending_areas)
	if(!islist(value))
		persistence_saved_scalar(value) // Value format 2 raw scalar; rejects anything else.
		return TRUE
	switch(value["kind"])
		if("map")
			return TRUE
		if("zone")
			return validate_zone_reference(value["id"], value["type"])
		if("area")
			if(!ispath(value["type"], /area))
				throw EXCEPTION("Invalid saved area type")
			if(pending_areas)
				var/area_key = "[value["x"]],[value["y"]],[value["z"]]|[value["type"]]"
				if(!pending_areas[area_key]) pending_areas[area_key] = list(value["x"], value["y"], value["z"], value["type"])
				return TRUE
			var/area_type = save_validation_area_type(value["x"], value["y"], value["z"])
			if(!ispath(area_type, value["type"]))
				throw EXCEPTION("Referenced area differs from the current map")
			return TRUE
		if("value")
			return TRUE
		if("entry")
			if(value["ref"] && !entries["[value["ref"]]"])
				if(!pending_refs) throw EXCEPTION("Missing saved referenced entry [value["ref"]]")
				pending_refs["[value["ref"]]"] = TRUE
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
			var/savefile/LF = level_list_file(F, id)
			var/length = LF["/lists/[id]/length"]
			if(isnull(length) && saved_scalar_list(LF, id))
				return TRUE
			if(!isnum(length) || length < 0 || length != round(length))
				throw EXCEPTION("Missing or invalid saved list [id]")
			for(var/i = 1, i <= length, i++)
				TICK_CHECK
				var/key = LF["/lists/[id]/[i]/key"]
				var/associated_value = LF["/lists/[id]/[i]/value"]
				validate_saved_value(F, key, entries, visited, pending_refs, pending_areas)
				validate_saved_value(F, associated_value, entries, visited, pending_refs, pending_areas)
			return TRUE
	throw EXCEPTION("Unknown saved value kind")

// One saved content edge, once both entries are known: the child is a
// movable, and a roof listed by a grid turf (parent_cell, y * 4096 + x) is
// projected onto that turf once.
/map_storage/proc/validate_saved_content_edge(z, child_key, child_type, parent_cell, list/roof_fields)
	if(!ispath(child_type, /atom/movable))
		throw EXCEPTION("Non-movable entry in saved contents on z=[z]")
	var/list/roof = roof_fields[child_key]
	if(!roof || !parent_cell) return
	var/x = parent_cell % 4096
	var/y = round(parent_cell / 4096)
	if(validated_roof_areas["[x],[y],[z]"] || validated_roof_entries["[z]:[child_key]"])
		throw EXCEPTION("Ambiguous or multiply placed saved roof")
	prepare_saved_roof(null, x, y, z, child_key, roof[1], persistence_saved_scalar(roof[2]), persistence_saved_scalar(roof[3]))

// The entries ("z:ref") the durable metadata graph binds, read from the round
// state without validating it (validate_durable_world does that later): the
// entry walk proves these reachable from a turf while it reads each level.
/map_storage/proc/durable_entry_targets(list/round_state)
	var/list/targets = list()
	if(!islist(round_state) || round_state["version"] != 2) return targets
	var/list/state = round_state["world_state"]
	var/list/nodes = islist(state) ? state["nodes"] : null
	if(!islist(nodes)) return targets
	for(var/node in nodes)
		if(!islist(node)) continue
		var/list/row = node
		if(row["kind"] != "entry" || !isnum(row["z"]) || !isnum(row["ref"])) continue
		targets["[row["z"]]:[row["ref"]]"] = TRUE
	return targets

// Large flat savefile directories make repeated entry navigation expensive.
// Legacy files remain flat; new files cap each entry directory at 512 children.
/map_storage/var/tmp/entry_path_key
/map_storage/proc/entry_path(savefile/F, ref)
	// Validation and loads call this millions of times per level; reading
	// /format_version each time dominated it. Cache per open handle by text
	// key only: holding the handle itself would keep a whole level in memory.
	var/key = "\ref[F]|[F.name]"
	if(key != entry_path_key)
		var/format_version = F["/format_version"]
		if(!(format_version == 2 || format_version == 3 || format_version == 4 || format_version == 5))
			// Legacy flat files are only read during upgrades; never cache them.
			return "/entries/[ref]"
		entry_path_key = key
	return "/entries/[round((text2num("[ref]") - 1) / 512)]/[ref]"

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
			if("[level_entry_value(F, ref, "type")]" != wanted[ref])
				throw EXCEPTION("Cross-level link target differs from its saved level")
		var/list/queue = level_turf_refs(F, z)
		var/list/seen = list()
		var/cursor = 1
		while(cursor <= queue.len && wanted.len)
			TICK_CHECK
			var/ref = "[queue[cursor++]]"
			if(seen[ref]) continue
			seen[ref] = TRUE
			wanted -= ref
			var/type = level_entry_value(F, ref, "type")
			if(ispath(type, /obj/screen) || ispath(type, /datum/hud)) continue
			for(var/child in saved_content_refs(level_entry_value(F, ref, "content"), level_content_version(F))) queue += child
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

// Low-memory world save and load.
//
// BYOND holds an open savefile in memory as a whole tree: the first read of any
// key materializes every node, and writing grows the same tree until the file
// object is released. A native probe measured about 5.8 bytes of resident memory
// per byte of savefile (a 39 MB level held 227 MB), and BYOND never returns that
// memory to the operating system. One large level file therefore sets the
// server's resident high-water mark for the rest of its uptime.
//
// Segmented levels (format 4) bound that cost. map_saves/<z>.sav becomes an
// index that keeps the header, the turf grid, zone capture rows and a segment
// table. Entries and lists are written to map_saves/<z>.part<k>.sav, each an
// ordinary format-3 file. A segment is closed and a new one started at a turf
// boundary once it holds PERSISTENCE_SEGMENT_SIZE entries plus lists, so only
// one segment's tree is resident while saving. Readers resolve an entry or list
// ID to its segment through the table and keep at most a few segments open.
// Saves choose this layout only when the projected memory would pass the
// configured limit; otherwise they keep the single-file format 3 layout.
//
// Bound: the reader cache holds at most 2 (low-memory) or 6 segments, but a
// recursive Load_Entry or list decode keeps its own segment handle while it
// follows a reference into another segment. Resident segments are therefore
// the cache plus one per distinct segment on the active reference chain.
// Fresh references are captured in the segment that first reaches them, so
// cross-segment chains come from references to entries captured on earlier
// tiles and from late parent appends (roster drain, animal sweep). A long
// chain of such references degrades toward the full-file cost, never beyond.

#define PERSISTENCE_SAVEFILE_MEMORY_FACTOR 6
#define PERSISTENCE_SEGMENT_CACHE_NORMAL 6
#define PERSISTENCE_SEGMENT_CACHE_LOW 2
// Assumed resident set when the process memory cannot be read (no trusted
// shell): a running world is rarely smaller, so the plan errs toward low-memory.
#define PERSISTENCE_UNKNOWN_RESIDENT_MB 1024

/map_storage
	var/datum/level_segment_writer/saving_segments
	var/datum/level_segment_reader/segment_reader
	var/datum/persistence_world_operation/low_memory_operation
	var/low_memory_active = FALSE
	var/last_low_memory_plan
	var/low_memory_override = null // TRUE/FALSE pins the plan for admins and fixtures.
	var/segment_size_override = null
	var/split_min_bytes = 8388608 // Smaller full-file levels load whole even in low-memory mode.

// map_saves/2.sav -> map_saves/2.part3.sav. The index's own path names its
// segments, so a copied generation (map_backups/) reads its own copies.
/proc/level_segment_path(index_path, number)
	index_path = "[index_path]"
	if(copytext(index_path, max(1, length(index_path) - 3)) != ".sav") throw EXCEPTION("Segmented level index has no .sav name")
	return "[copytext(index_path, 1, length(index_path) - 3)].part[number].sav"

// Segment files of one level, by file name in the given directory, including
// a stream-backed level's stream file (level_stream.dm).
/proc/level_segment_files(directory, z)
	var/list/found = list()
	var/prefix = "[z].part"
	for(var/name in flist(directory))
		if(name == "[z].stream.sav" || (findtext(name, prefix) == 1 && copytext(name, max(1, length(name) - 3)) == ".sav")) found += name
	return found

/proc/delete_level_segment_files(directory, z)
	for(var/name in level_segment_files(directory, z))
		if(!fdel("[directory][name]")) throw EXCEPTION("Could not remove stale level segment [name]")

// Floor icon deferral (code/game/turfs/floor.dm) when the full game is
// compiled; serializer fixtures without floors leave both as no-ops.
/proc/set_floor_icon_updates_deferred(deferred)
	if("floor_icon_updates_deferred" in global.vars) global.vars["floor_icon_updates_deferred"] = deferred

/proc/refresh_deferred_floor_icons_level(z)
	var/refresh = text2path("/proc/refresh_deferred_floor_icons")
	if(refresh) call(refresh)(z, TRUE)

// Resident set of this process in MiB, or null when it cannot be read. shell()
// needs a trusted daemon; a probe failure only removes the resident term from
// the projection, it never blocks a save or load.
// The daily game log, when the full game is compiled (fixtures omit it).
/proc/persistence_game_log(text)
	var/datum/settings = ("config" in global.vars) ? global.vars["config"] : null
	var/game_log_proc = text2path("/proc/log_game")
	if(settings && game_log_proc) call(game_log_proc)(text)

// Why the last reading failed, for the game log; null after a good reading.
var/global/persistence_memory_probe_error

/proc/persistence_process_memory_mb()
	persistence_memory_probe_error = null
	var/pid = world.process
	if(!pid)
		persistence_memory_probe_error = "no process id"
		return null
	var/windows = world.system_type != UNIX
	// On Windows the command shell may not start in the world's directory, so
	// the probe writes to an absolute path in the temp folder both sides agree on.
	var/temp = windows ? world.GetConfig("env", "TEMP") : null
	var/path = length(temp) ? "[temp]\\civ13_memory_[pid].txt" : "data/persistence_memory_probe.txt"
	var/result
	try
		if(fexists(path)) fdel(path)
		var/status
		if(windows)
			status = shell("cmd /c tasklist /FI \"PID eq [pid]\" /FO CSV /NH > \"[path]\"")
		else
			status = shell("grep VmRSS /proc/[pid]/status > [path]")
		var/text = fexists(path) ? file2text(path) : null
		fdel(path)
		if(!istext(text) || !length(text))
			persistence_memory_probe_error = isnull(status) ? "shell unavailable" : "no output (exit [status], [path])"
			return null
		if(windows)
			result = persistence_parse_tasklist_kib(text)
		else
			result = persistence_digits(copytext(text, findtext(text, ":") + 1))
		if(!isnum(result) || result <= 0)
			persistence_memory_probe_error = "unparsed output: [copytext(text, 1, 121)]"
			return null
	catch(var/exception/e)
		persistence_memory_probe_error = "[e]"
		return null
	return round(result / 1024) // Both sources report KiB.

// tasklist /FO CSV row: "image","pid","session","number","memory K". The
// memory field's grouping separator depends on locale (1,234 or 1.234 or 1 234).
/proc/persistence_parse_tasklist_kib(text)
	if(!istext(text)) return null
	var/list/fields = splittext(text, "\",\"")
	if(fields.len < 5) return null
	return persistence_digits(fields[5])

/proc/persistence_digits(text)
	var/digits = ""
	for(var/i = 1, i <= length(text), i++)
		var/c = copytext(text, i, i + 1)
		if(c >= "0" && c <= "9") digits += c
	return length(digits) ? text2num(digits) : null

// Bytes a full single-file save of the largest level would hold, from the
// current generation on disk (index plus any segments of that level).
/proc/persistence_largest_level_bytes(directory = "map_saves/")
	var/largest = 0
	for(var/z = 1, z <= world.maxz, z++)
		var/total = 0
		if(fexists("[directory][z].sav")) total += length(file("[directory][z].sav"))
		for(var/name in level_segment_files(directory, z))
			// A level stream is never materialised as a savefile tree.
			if(name == "[z].stream.sav") continue
			total += length(file("[directory][name]"))
		largest = max(largest, total)
	return largest

// Decides once per world operation. "always" forces the low-memory path; a
// positive limit enables it when the resident set plus the projected tree of
// the largest level would pass that limit.
/map_storage/proc/plan_low_memory(kind)
	var/datum/persistence_world_operation/operation = persistence_active_operation
	if(operation && low_memory_operation == operation) return low_memory_active
	low_memory_operation = operation
	low_memory_active = FALSE
	// A failed operation can leave its segment handles behind; drop them here.
	drop_segment_writer()
	drop_segment_reader()
	if(!isnull(low_memory_override))
		low_memory_active = !!low_memory_override
		last_low_memory_plan = "[kind]: [low_memory_active ? "low-memory" : "full-file"] (override)"
		return low_memory_active
#ifdef CIV13_HUMAN_SPATIAL_EXPERIMENTAL
	// The human spatial prototype reads level files directly; keep it on format 3.
	last_low_memory_plan = "[kind]: full-file (human spatial prototype)"
	return FALSE
#else
	// Read through vars: isolated persistence fixtures compile without config.
	var/datum/settings = ("config" in global.vars) ? global.vars["config"] : null
	var/limit = settings && ("persistence_memory_limit_mb" in settings.vars) ? settings.vars["persistence_memory_limit_mb"] : 0
	var/forced = settings && ("persistence_low_memory_always" in settings.vars) && settings.vars["persistence_low_memory_always"]
	if(!forced && (!isnum(limit) || limit <= 0))
		last_low_memory_plan = "[kind]: full-file (no memory limit configured)"
		return FALSE
	var/resident = persistence_process_memory_mb()
	var/level_mb = round(persistence_largest_level_bytes() / 1048576)
	var/projected = (isnum(resident) ? resident : PERSISTENCE_UNKNOWN_RESIDENT_MB) + PERSISTENCE_SAVEFILE_MEMORY_FACTOR * level_mb
	low_memory_active = forced || projected > limit
	last_low_memory_plan = "[kind]: [low_memory_active ? "low-memory" : "full-file"] (resident=[isnum(resident) ? "[resident] MiB" : "unknown, assumed [PERSISTENCE_UNKNOWN_RESIDENT_MB] MiB"], largest level=[level_mb] MiB, projected=[projected] MiB, limit=[limit] MiB[forced ? ", forced" : ""])"
	world.log << "World [last_low_memory_plan]"
	// world.log is only the console on hosts started without -log; keep a copy
	// in the daily game log so the memory reading can be checked afterwards.
	persistence_game_log("World [last_low_memory_plan][isnum(resident) ? "" : "; memory reading failed: [persistence_memory_probe_error]"]")
	return low_memory_active
#endif

// BYOND is a 32-bit process: past the configured limit, warn admins while
// there is still time to save and restart before the address space runs out.
/map_storage/proc/report_load_memory(z, seconds)
	var/resident = persistence_process_memory_mb()
	log_startup_progress("	Loaded z-level [z] in [seconds]s[isnum(resident) ? " (server memory [resident] MiB)" : ""].")
	persistence_game_log("Loaded z-level [z] in [seconds]s; server memory [isnum(resident) ? "[resident] MiB" : "unreadable ([persistence_memory_probe_error])"].")
	if(!isnum(resident)) return
	var/datum/settings = ("config" in global.vars) ? global.vars["config"] : null
	var/limit = settings && ("persistence_memory_limit_mb" in settings.vars) ? settings.vars["persistence_memory_limit_mb"] : 0
	if(isnum(limit) && limit > 0 && resident > limit)
		message_admins("World load is using [resident] MiB, past the persistence memory limit of [limit] MiB. BYOND is 32-bit and fails near 4 GiB; consider PERSISTENCE_LOW_MEMORY_ALWAYS or a lower limit.")

// Low-memory loads of single-file levels. BYOND reads a whole level file into
// memory on first access and holds it while that level's objects are created,
// so a large format-3 level stacks its file tree on top of the loaded world.
// When the plan is low-memory, each large format-3 level is first split into a
// format-4 index plus segments, before any saved object exists. The released
// tree's memory is then reused by the import, which reads one segment at a
// time. Slower, but the peak becomes the larger of the two, not their sum.
// Content and generation are unchanged; the full-file generation is kept in
// map_rollback/ first, as for the first segmented save.
/map_storage/proc/split_large_full_file_levels()
	var/list/candidates = list()
	for(var/z = 1, z <= world.maxz, z++)
		var/path = "map_saves/[z].sav"
		if(!fexists(path) || length(file(path)) < split_min_bytes) continue
		var/savefile/F = new(path)
		var/version = F["/format_version"]
		F = null
		if(version == 3) candidates += z
	if(!candidates.len) return 0
	// Segments beside a full-file level are leftovers; the level ignores them.
	for(var/z in candidates)
		delete_level_segment_files("map_saves/", z)
	preserve_full_file_rollback()
	var/split = 0
	for(var/z in candidates)
		var/watch = start_watch()
		try
			var/count = split_full_file_level(z)
			split++
			world.log << "Split saved level [z] into [count] segments for a low-memory load in [stop_watch(watch)]s."
		catch(var/exception/e)
			// The level file is untouched until its index replaces it; a failed
			// split leaves it as a full-file level and the load reads it whole.
			fdel("map_saves/[z].index.tmp")
			delete_level_segment_files("map_saves/", z)
			world.log << "Could not split saved level [z] for a low-memory load ([e] on [e.file]:[e.line]); loading it as one file."
	return split

/map_storage/proc/split_full_file_level(z)
	var/path = "map_saves/[z].sav"
	var/index_path = "map_saves/[z].index.tmp"
	if(fexists(index_path) && !fdel(index_path)) throw EXCEPTION("Could not replace [index_path]")
	var/savefile/F = new(path)
	if(F["/format_version"] != 3) throw EXCEPTION("Level [z] is not a full-file level")
	var/generation = F["/generation"]
	F.cd = "/"
	var/list/top = F.dir.Copy()
	var/list/present = list()
	var/last_entry = 0
	if("entries" in top)
		F.cd = "/entries"
		for(var/shard in F.dir.Copy())
			F.cd = "/entries/[shard]"
			for(var/ref in F.dir)
				present["/entries/[shard]/[ref]"] = TRUE
				last_entry = max(last_entry, text2num(ref))
			F.cd = "/entries"
	var/last_list = 0
	if("lists" in top)
		F.cd = "/lists"
		for(var/id in F.dir)
			present["/lists/[id]"] = TRUE
			last_list = max(last_list, text2num(id))
	var/count = max(1, -round(-(last_entry + last_list) / segment_budget()))
	var/list/entry_last = list()
	var/list/list_last = list()
	for(var/number = 1, number <= count, number++)
		var/first_entry = round(last_entry * (number - 1) / count) + 1
		var/first_list = round(last_list * (number - 1) / count) + 1
		entry_last += round(last_entry * number / count)
		list_last += round(last_list * number / count)
		var/segment_path = level_segment_path(path, number)
		var/savefile/S = new(segment_path)
		S["/format_version"] << 3
		S["/generation"] << generation
		S["/segment"] << number
		S["/level"] << z
		var/list/copied = list()
		for(var/ref = first_entry, ref <= entry_last[number], ref++)
			var/node = "/entries/[round((ref - 1) / 512)]/[ref]"
			if(!present[node]) continue
			copied[node] = copy_saved_node(F, S, node)
			TICK_CHECK
		for(var/id = first_list, id <= list_last[number], id++)
			var/node = "/lists/[id]"
			if(!present[node]) continue
			copied[node] = copy_saved_node(F, S, node)
			TICK_CHECK
		S.Flush()
		S = null
		S = new(segment_path)
		for(var/node in copied)
			verify_saved_node(F, S, node, copied[node])
			TICK_CHECK
		S = null
	// The index keeps every other top-level node; the turf grid row by row so
	// no single exported text holds the whole grid.
	var/savefile/I = new(index_path)
	var/list/index_nodes = list()
	for(var/key in top)
		if(key == "entries" || key == "lists" || key == "segments") continue
		if(key != "map")
			index_nodes["/[key]"] = copy_saved_node(F, I, "/[key]")
			continue
		F.cd = "/map"
		for(var/level in F.dir.Copy())
			F.cd = "/map/[level]"
			for(var/row in F.dir.Copy())
				index_nodes["/map/[level]/[row]"] = copy_saved_node(F, I, "/map/[level]/[row]")
				TICK_CHECK
	I["/format_version"] << 4
	I["/segments/count"] << count
	I["/segments/entries"] << entry_last
	I["/segments/lists"] << list_last
	I.Flush()
	I = null
	I = new(index_path)
	for(var/node in index_nodes)
		if(node == "/format_version") continue
		verify_saved_node(F, I, node, index_nodes[node])
		TICK_CHECK
	I = null
	F = null
	if(!fcopy(index_path, path)) throw EXCEPTION("Could not replace level [z] with its segmented index")
	fdel(index_path)
	var/savefile/check = new(path)
	if(check["/format_version"] != 4 || check["/segments/count"] != count || check["/generation"] != generation)
		check = null
		// The full-file generation was kept before any level was replaced.
		if(fexists("map_rollback/[z].sav")) fcopy("map_rollback/[z].sav", path)
		throw EXCEPTION("Level [z] index did not read back after replacement")
	return count

// Raw text copy keeps every node exactly, including types the build no longer
// defines. Text macros do not survive the text form, so a node whose copy
// exports differently is copied again value by value and compared by value.
/map_storage/proc/copy_saved_node(savefile/F, savefile/G, path)
	var/text = F.ExportText(path)
	G.ImportText(path, text)
	return md5(text)

/map_storage/proc/verify_saved_node(savefile/F, savefile/G, path, digest)
	if(md5(G.ExportText(path)) == digest) return
	var/cut = findlasttext(path, "/")
	G.cd = cut > 1 ? copytext(path, 1, cut) : "/"
	G.dir -= copytext(path, cut + 1)
	copy_saved_values(F, G, path)
	G.Flush()
	if(!same_saved_tree(F, G, path)) throw EXCEPTION("Saved node [path] changed when copied")

/map_storage/proc/copy_saved_values(savefile/F, savefile/G, path)
	F.cd = path
	var/list/children = F.dir.Copy()
	var/value = F[path]
	if(!isnull(value) || !children.len) G[path] << value
	for(var/child in children)
		copy_saved_values(F, G, "[path]/[child]")

/map_storage/proc/same_saved_tree(savefile/F, savefile/G, path)
	F.cd = path
	G.cd = path
	var/list/source = F.dir.Copy()
	var/list/copy = G.dir.Copy()
	if(source.len != copy.len) return FALSE
	for(var/child in source)
		if(!(child in copy)) return FALSE
	if(!same_saved_value(F[path], G[path])) return FALSE
	for(var/child in source)
		if(!same_saved_tree(F, G, "[path]/[child]")) return FALSE
	return TRUE

/proc/same_saved_value(a, b)
	if(islist(a) && islist(b))
		var/list/A = a
		var/list/B = b
		if(A.len != B.len) return FALSE
		for(var/i = 1, i <= A.len, i++)
			var/key = A[i]
			if(!same_saved_value(key, B[i])) return FALSE
			if(!isnum(key) && !isnull(key) && !same_saved_value(A[key], B[key])) return FALSE
		return TRUE
	if(isicon(a) || isfile(a)) return "[a]" == "[b]"
	return a == b

// Format 4 is unreadable by builds before it. Before the first segmented
// save replaces a full-file generation, copy that completed generation to
// map_rollback/ (once: a segmented current generation is never copied).
/map_storage/proc/preserve_full_file_rollback()
	if(!fexists("map_saves/save_complete.txt")) return
	for(var/z = 1, z <= world.maxz, z++)
		if(level_segment_files("map_saves/", z).len) return
	var/rollback = "map_rollback/"
	if(fexists("[rollback]save_complete.txt") && !fdel("[rollback]save_complete.txt"))
		throw EXCEPTION("Could not invalidate rollback marker; existing save retained")
	for(var/name in flist("map_saves/"))
		save_work_check()
		if(name == "map.txt" || name == "round.json" || copytext(name, max(1, length(name)-3)) == ".sav")
			if(!fcopy("map_saves/[name]", "[rollback][name]"))
				throw EXCEPTION("Could not copy [name] to the full-file rollback; existing save retained")
	if(!fcopy("map_saves/save_complete.txt", "[rollback]save_complete.txt"))
		throw EXCEPTION("Could not mark the full-file rollback; existing save retained")
	world.log << "Kept the last full-file world save in [rollback] for builds without segmented levels."

/map_storage/proc/segment_cache_limit()
	if(persistence_active_operation)
		plan_low_memory(persistence_active_operation.kind)
	return low_memory_active ? PERSISTENCE_SEGMENT_CACHE_LOW : PERSISTENCE_SEGMENT_CACHE_NORMAL

/map_storage/proc/segment_budget()
	var/datum/settings = ("config" in global.vars) ? global.vars["config"] : null
	var/budget = settings && ("persistence_segment_size" in settings.vars) ? settings.vars["persistence_segment_size"] : 0
	if(isnum(segment_size_override) && segment_size_override >= 1) return round(segment_size_override)
	if(!isnum(budget) || budget < 256) budget = 4096
	return round(budget)

// Content semantics of a level file: a segmented index describes format-3
// content. Validates the segment table before reporting it.
/map_storage/proc/level_content_version(savefile/F)
	var/version = F["/format_version"]
	if(version != 4 && version != 5) return version
	level_segments(F)
	return 3

/map_storage/proc/level_segments(savefile/F)
	// A segment file passed down a reader's recursion routes through the
	// reader of its own index. Never probe absent keys of ordinary levels.
	if(segment_reader && findtext("[F.name]", segment_reader.part_prefix) == 1) return segment_reader
	// Stream levels hand out scratch files; reading an absent key would add it,
	// so they are recognised by name, never by probing.
	if(segment_reader && segment_reader.owns_file(F)) return segment_reader
	var/version = F["/format_version"]
	if(version != 4 && version != 5) return null
	if(!segment_reader || segment_reader.index != F)
		drop_segment_reader()
		segment_reader = version == 5 ? new_stream_level_reader(F, segment_cache_limit()) : new /datum/level_segment_reader(F, segment_cache_limit())
	return segment_reader

// Format 5 (stream-backed levels) lives in stream/level_stream.dm, which
// overrides these. Fixtures that compile the loader alone keep /savefile levels.
/map_storage/proc/stream_level_writer_type()
	return null

/map_storage/proc/new_stream_level_reader(savefile/F, cache_limit)
	throw EXCEPTION("Stream-backed levels need the stream save module")

/map_storage/proc/stream_level_entries(datum/level_segment_reader/R)
	throw EXCEPTION("Stream-backed levels need the stream save module")

/map_storage/proc/drop_segment_reader()
	var/datum/level_segment_reader/R = segment_reader
	segment_reader = null
	if(R) R.close()

/map_storage/proc/drop_segment_writer()
	var/datum/level_segment_writer/W = saving_segments
	saving_segments = null
	if(W) W.abort()

// The file that holds an entry's fields: the level file itself, the segment
// being written, or the segment the index assigns to that entry.
/map_storage/proc/level_entry_file(savefile/F, ref)
	if(saving_segments && saving_segments.owns(F)) return saving_segments.file_for_entry(ref)
	var/datum/level_segment_reader/R = level_segments(F)
	return R ? R.entry_file(ref) : F

/map_storage/proc/level_list_file(savefile/F, id)
	var/datum/level_segment_reader/R = level_segments(F)
	return R ? R.list_file(id) : F

/map_storage/proc/level_entry_value(savefile/F, ref, field)
	var/savefile/E = level_entry_file(F, ref)
	return E["[entry_path(E, ref)]/[field]"]

// Every entry ID of a segmented level. Each entry must sit in the segment its
// ID range names, or readers would not find it.
/map_storage/proc/level_segment_entries(savefile/F)
	var/datum/level_segment_reader/R = level_segments(F)
	if(F["/format_version"] == 5) return stream_level_entries(R)
	var/list/entries = list()
	var/first = 1
	for(var/number = 1, number <= R.count, number++)
		var/last = R.entry_last[number]
		var/savefile/S = R.open(number)
		S.cd = "/"
		if("entries" in S.dir)
			S.cd = "/entries"
			var/list/shards = S.dir.Copy()
			for(var/shard in shards)
				S.cd = "/entries/[shard]"
				for(var/ref in S.dir.Copy())
					var/value = text2num(ref)
					if(!isnum(value) || value < first || value > last) throw EXCEPTION("Saved entry [ref] is outside segment [number]")
					entries += ref
				TICK_CHECK
		S.cd = "/"
		first = last + 1
	return entries

/datum/level_segment_reader
	var/savefile/index
	var/base_path
	var/part_prefix
	var/generation
	var/count = 0
	var/list/entry_last
	var/list/list_last
	var/limit = PERSISTENCE_SEGMENT_CACHE_NORMAL
	var/list/open_order = list()
	var/list/open_files = list()

/datum/level_segment_reader/New(savefile/F, cache_limit)
	index = F
	base_path = F.name
	part_prefix = copytext(level_segment_path(base_path, 1), 1, -length("1.sav"))
	generation = F["/generation"]
	if(isnum(cache_limit) && cache_limit >= 1) limit = cache_limit
	count = F["/segments/count"]
	entry_last = F["/segments/entries"]
	list_last = F["/segments/lists"]
	if(!isnum(count) || count < 1 || count != round(count) || count > 1000000) throw EXCEPTION("Invalid level segment count")
	if(!islist(entry_last) || !islist(list_last) || entry_last.len != count || list_last.len != count) throw EXCEPTION("Invalid level segment table")
	check_bounds(entry_last)
	check_bounds(list_last)

/datum/level_segment_reader/proc/entry_file(ref)
	return file_for(entry_last, ref, "entry")

/datum/level_segment_reader/proc/list_file(id)
	return file_for(list_last, id, "list")

// Scratch files a reader hands out that are not named after its segments.
/datum/level_segment_reader/proc/owns_file(savefile/F)
	return FALSE

/datum/level_segment_reader/proc/close()
	return

/datum/level_segment_reader/proc/check_bounds(list/bounds)
	var/previous = 0
	for(var/value in bounds)
		if(!isnum(value) || value < previous || value != round(value)) throw EXCEPTION("Invalid level segment bounds")
		previous = value

/datum/level_segment_reader/proc/file_for(list/bounds, id, kind)
	if(!isnum(id)) id = text2num("[id]")
	if(!isnum(id) || id < 1 || id > bounds[bounds.len]) throw EXCEPTION("Saved [kind] [id] is outside its level segments")
	var/low = 1
	var/high = bounds.len
	while(low < high)
		var/middle = round((low + high) / 2)
		if(bounds[middle] >= id) high = middle
		else low = middle + 1
	return open(low)

/datum/level_segment_reader/proc/open(number)
	var/key = "[number]"
	var/savefile/S = open_files[key]
	if(S)
		open_order -= key
		open_order += key
		return S
	var/path = level_segment_path(base_path, number)
	if(!fexists(path)) throw EXCEPTION("Missing level segment [path]")
	S = new(path)
	if(S["/format_version"] != 3 || S["/segment"] != number || S["/generation"] != generation) throw EXCEPTION("Level segment [path] belongs to another generation")
	open_files[key] = S
	open_order += key
	while(open_order.len > limit)
		var/oldest = open_order[1]
		open_order.Cut(1, 2)
		open_files -= oldest
	return S

/datum/level_segment_writer
	var/map_storage/owner
	var/savefile/index
	var/savefile/current
	var/savefile/late_file
	var/late_number = 0
	var/index_path
	var/generation
	var/z
	var/budget
	var/number = 0
	var/start_nodes = 0
	var/list/entry_last = list()
	var/list/list_last = list()

/datum/level_segment_writer/New(map_storage/storage, savefile/F, path, level, generation_id, segment_budget)
	owner = storage
	index = F
	index_path = path
	z = level
	generation = generation_id
	budget = segment_budget
	open_next()

// A failed save drops its writer; stream writers stop their helper here.
/datum/level_segment_writer/proc/abort()
	return

/datum/level_segment_writer/proc/owns(savefile/F)
	return F && (F == current || F == index || F == late_file)

/datum/level_segment_writer/proc/open_next()
	close_current()
	number++
	var/path = level_segment_path(index_path, number)
	if(fexists(path) && !fdel(path)) throw EXCEPTION("Could not replace level segment [path]")
	current = new(path)
	current["/format_version"] << 3
	current["/generation"] << generation
	current["/segment"] << number
	current["/level"] << z
	start_nodes = owner.saving_reference_pins.len + owner.saving_list_pins.len

/datum/level_segment_writer/proc/close_current()
	if(!current) return
	entry_last += owner.saving_reference_pins.len
	list_last += owner.saving_list_pins.len
	current.Flush()
	current = null

// Only between turfs: every entry's fields stay inside the segment that
// allocated its ID, so the ID ranges in the table are exact.
/datum/level_segment_writer/proc/rotate_if_full()
	if(owner.saving_export_stack.len || owner.moving_save_chunk) return
	if(owner.saving_reference_pins.len + owner.saving_list_pins.len - start_nodes < budget) return
	open_next()
	// Let the released tree's memory be reused before the next segment grows.
	sleep(world.tick_lag)

// Late writes (roster drain, animal sweep) can append to a turf saved in an
// earlier segment. Reopen that one segment for the write.
/datum/level_segment_writer/proc/file_for_entry(ref)
	if(!isnum(ref)) ref = text2num("[ref]")
	var/closed = entry_last.len ? entry_last[entry_last.len] : 0
	if(!isnum(ref) || ref < 1) throw EXCEPTION("Invalid saved entry for a level segment")
	if(ref > closed) return current
	var/target = 1
	while(entry_last[target] < ref) target++
	if(late_number != target)
		if(late_file) late_file.Flush()
		late_file = null
		late_file = new(level_segment_path(index_path, target))
		late_number = target
	return late_file

/datum/level_segment_writer/proc/finish()
	close_current()
	if(late_file) late_file.Flush()
	late_file = null
	index["/segments/count"] << entry_last.len
	index["/segments/entries"] << entry_last
	index["/segments/lists"] << list_last

#undef PERSISTENCE_SEGMENT_CACHE_LOW
#undef PERSISTENCE_SEGMENT_CACHE_NORMAL
#undef PERSISTENCE_SAVEFILE_MEMORY_FACTOR
#undef PERSISTENCE_UNKNOWN_RESIDENT_MB

// Unsaved cells of a sparse ground level held the baseline turf with every
// saved field at its default; constructors may have changed some (random
// states), so put the defaults back and queue each turf's after_load.
/map_storage/proc/restore_sparse_ground_cells(savefile/F, z, list/header)
	var/list/cells = sparse_level_cells(F, z, header)
	for(var/y = 1, y <= world.maxy, y++)
		var/list/columns = cells["[y]"]
		var/next = 1
		for(var/x = 1, x <= world.maxx, x++)
			if(columns && next <= columns.len && columns[next] == x)
				next++
				continue
			var/turf/T = locate(x, y, z)
			var/list/default_fields = T.persistence_field_allowlist()
			for(var/v in default_fields)
				if(!(v in T.vars) || T.persistence_runtime_var(v)) continue
				var/default_value = initial(T.vars[v])
				if(persistence_default_scalar(default_value) && T.vars[v] != default_value)
					T.vars[v] = default_value
			T.persistence_reset_omitted_fields(list("type"))
			T.persistence_import_fields(list("type"))
			all_loaded += T
		TICK_CHECK
