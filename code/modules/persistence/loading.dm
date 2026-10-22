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
		if(ispath(type, /obj/screen) || ispath(type, /datum/hud))
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
		else if(replacement)
			object = replacement
		else if(ispath(type, /atom))
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
		all_loaded += object
		existing_references["[ind]"] = object
		if(durable_import) durable_import.accept_entry(loading_z, ind, object)
		for(var/v in savefile.dir)
			savefile.cd = entry_path(savefile, ind)
			if(object.persistence_runtime_var(v))
				continue
			if(v == "type")
				continue
			else if(v in list("loc", "locs", "pixloc", "contents", "vars", "parent_type", "x", "y", "z", "vis_locs", "client", "key", "ckey"))
				continue
			else if(v == "content")
				if(nocontents != 2)
					var/list/refs = params2list(savefile[v])
					var/atom/container = object
					if(container)
						for(var/obj/ob in container.contents.Copy())
							if(istype(ob, /obj/map_metadata) || istype(ob, /atom/movable/lighting_overlay) || istype(ob, /atom/movable/lighting_fullbright))
								continue
							if(ob.loc == container)
								qdel(ob)
					for(var/x in refs)
						Load_Entry(savefile, x, null, object, nocontents = nextContents, lag_fix = lag_fix)
			else if(format_version == 2)
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
	// Allocate all levels first so references to turfs on later levels stay valid.
	for(var/z = 1, z <= world.maxz, z++)
		var/savefile/F = new("map_saves/[z].sav")
		for(var/y = 1, y <= world.maxy, y++)
			for(var/x = 1, x <= world.maxx, x++)
				var/ref = F["/map/[z]/[y]/[x]"]
				var/type = F["[entry_path(F, ref)]/type"]
				var/turf/T = locate(x,y,z)
				T.ChangeTurf(type, FALSE, FALSE)
				TICK_CHECK
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
			// Constructors see defaults before saved fields/contents are restored.
			// Rebuild obstruction caches before queuing any final source updates.
			for(var/turf/light_turf in all_loaded)
				light_turf.recalc_atom_opacity()
			for(var/atom/light_owner in all_loaded)
				light_owner.update_light()
			log_startup_progress("	Loaded z-level [B] in [stop_watch(watch)]s.")
		catch(var/exception/e)
			last_error = "[e] on [e.file]:[e.line]"
			world.log << "World-save restoration failed: [last_error]"
			message_admins("EXCEPTION IN MAP LOADING!! [e] on [e.file]:[e.line]")
			clear_bookkeeping()
			saved_turfs = list()
			return FALSE
	clear_bookkeeping()
	saved_turfs = list()
	log_startup_progress("Finished loading.")
	return TRUE

// A failed preflight must leave the running world untouched. Historical saves
// use the same grid; the completion marker is required by the startup contract.
/map_storage/proc/validate_world_save()
	last_error = null
	release_durable_world()
	try
		if(!fexists("map_saves/save_complete.txt") || !fexists("map_saves/map.txt"))
			throw EXCEPTION("Save is incomplete: metadata or completion marker missing")
		var/list/meta = splittext(file2text("map_saves/map.txt"), "\n")
		if(meta.len < 9 || meta[1] != map.ID)
			throw EXCEPTION("Save metadata does not match the current map")
		var/list/round_state = read_round_state()
		var/list/player_owners = list()
		if(isnull(round_mode_metadata(meta)))
			throw EXCEPTION("Save round-mode metadata is malformed")
		for(var/z = 1, z <= save_validation_maxz(), z++)
			if(!fexists("map_saves/[z].sav"))
				throw EXCEPTION("Missing saved z-level [z]")
			var/savefile/F = new("map_saves/[z].sav")
			if(round_state.len && F["/generation"] != round_state["generation"])
				throw EXCEPTION("Saved level belongs to another round generation")
			var/version = F["/format_version"]
			if(version && version != 2)
				throw EXCEPTION("Unsupported save version [version]")
			if(version == 2 && (F["/maxx"] != world.maxx || F["/maxy"] != world.maxy || F["/maxz"] != save_validation_maxz()))
				throw EXCEPTION("Saved world dimensions differ from the current world")
			var/list/validated_lists = list()
			var/list/turf_refs = list()
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
					TICK_CHECK
			F.cd = "/entries"
			var/list/entries = F.dir.Copy()
			if(version == 2)
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
				for(var/field in fields)
					F.cd = entry_path(F, ref)
					var/value = F[field]
					if(field == "type")
						continue
					if(field == "content")
						for(var/content_ref in params2list(value))
							if(!entry_set["[content_ref]"])
								throw EXCEPTION("Missing content entry [content_ref] on z=[z]")
							var/content_type = F["[entry_path(F, content_ref)]/type"]
							if(!ispath(content_type, /atom/movable))
								throw EXCEPTION("Non-movable entry in saved contents on z=[z]")
					else if(version == 2)
						validate_saved_value(F, value, entry_set, validated_lists)
					else if(istext(value) && findtext(value, "**entry") == 1)
						if(!entry_set[copytext(value, 8)])
							throw EXCEPTION("Missing legacy referenced entry on z=[z]")
					else if(istext(value) && findtext(value, "**list") == 1)
						for(var/item in params2list(copytext(value, 7)))
							if(findtext(item, "**entry") == 1 && !entry_set[copytext(item, 8)])
								throw EXCEPTION("Missing legacy list entry on z=[z]")
		if(round_state["version"] == 2) validate_durable_world(round_state["world_state"], round_state["generation"])
		return TRUE
	catch(var/exception/e)
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
	if(F["/format_version"] == 2)
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
