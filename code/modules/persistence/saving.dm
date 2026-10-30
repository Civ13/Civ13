// Saves all of the turfs and objects within turfs to their own directories withn
// the specifeid savefile name. If objects or turfs have variables to keep track
// of, it will check to see if those variables have been modified and record the
// new values of any modified variables along with the object. It uses an object
// reference, which records each object type as a position in a list so that it
// can be references using a number instead of a fully written out type class.
// You can also specify a name and password for the map, along with any extra
// variables (in params format) that you want saved along with the map file.
// Experimental duty-cycle policy, not an equivalent-budget optimization.
// Native copies, hooks and writes remain nonpreemptible.
/map_storage/proc/save_work_check()
	saving_work++
	if(saving_work >= 8192 || world.tick_usage - saving_slice_start >= 20 || world.tick_usage >= 80)
		saving_work = 0
		if(world.tick_usage >= 80)
			sleep(world.tick_lag)
		else
			sleep(0)
		saving_slice_start = world.tick_usage

/map_storage/proc/Save_World()
	return run_world_operation("save")

/map_storage/proc/save_world_contents(datum/persistence_world_operation/operation)
	if(!operation || !operation.enter_contents(src, "save")) return FALSE
	operation.diagnostic_phase = "capture"
	if(building_allocating_z || dimension_recovery_required)
		throw EXCEPTION("Cannot save an incomplete building level; finish allocation or restart recovery")
	prepare_player_ownership()
	var/generation_nonce = md5("[world.realtime]-[world.time]-[rand(1, 1000000000)]")
	var/generation = "round-v2:[generation_nonce]"
	if(map.uses_durable_metadata()) begin_zone_export(generation)
	var/list/world_state = capture_durable_world()
	var/prefix = world_state ? "round-v2" : "round-v1"
	generation = "[prefix]:[generation_nonce]"
	if(zone_export_state && !world_state) throw EXCEPTION("Admitted zone capture lost its metadata profile")
	var/list/round_state = capture_round_state(generation)
	if(world_state)
		round_state["version"] = 2
		round_state["world_state"] = world_state
	clear_bookkeeping()
	// ***** MAP SECTION *****
	var/backup_dir = "map_backups/"
	// Back up the whole previous completed generation before overwriting any
	// level. A per-level rolling backup mixed old and new levels after failures.
	if(fexists("map_saves/save_complete.txt"))
		if(fexists("map_backups/save_complete.txt"))
			if(!fdel("map_backups/save_complete.txt"))
				throw EXCEPTION("Could not invalidate backup marker; existing save retained")
		for(var/name in flist("map_saves/"))
			save_work_check()
			if(name == "map.txt" || name == "round.json" || copytext(name, max(1, length(name)-3)) == ".sav")
				if(!fcopy("map_saves/[name]", "[backup_dir][name]"))
					throw EXCEPTION("Could not back up [name]; existing save retained")
		if(!fcopy("map_saves/save_complete.txt", "[backup_dir]save_complete.txt"))
			throw EXCEPTION("Could not mark completed backup; existing save retained")
	// Remove the completion marker first: if this save dies partway through, the
	// marker's absence tells the startup autoload not to trust map_saves/.
	if (fexists("map_saves/save_complete.txt"))
		if(!fdel("map_saves/save_complete.txt"))
			throw EXCEPTION("Could not invalidate completion marker; existing save retained")
	var/F0 = "map_saves/map.txt"
	if (fexists(F0))
		if(!fdel(F0))
			throw EXCEPTION("Could not replace save metadata")
	var/list/metadata = list(map.ID, "[map.age]", "[map.ordinal_age]", "[map.default_research]", "[map.autoresearch]", "[map.autoresearch_mult]", "[map.chad_mode]", "[map.chad_mode_plus]", "[map.gamemode]", time2text(world.realtime,"YYYY-MM-DD-(hh-mm-ss)"))
	// Preserve the legacy fields and timestamp; append ordinary round-mode flags.
	metadata += list("[map.persistence]", "[map.research_active]", "[map.resourceresearch]", "[map.perschadplus]")
	if(!text2file(jointext(metadata, "\n"), F0))
		throw EXCEPTION("Could not write world-save metadata")
	round_state["metadata"] = md5(file2text(F0))
	log_startup_progress("	Saved metadata.")
	for(var/A = 1, A <= world.maxz, A++)
		saving_z = A
		saving_content_owners = list()
		saving_lists = list()
		saving_reference_pins = list()
		saving_list_pins = list()
		saving_references = list()
		existing_references = list()
		found_types = list()
		if(fexists("map_saves/[A].sav"))
			if(!fdel("map_saves/[A].sav"))
				throw EXCEPTION("Could not replace saved level [A]")
		var/savefile/savefile = new("map_saves/[A].sav")
		savefile["/format_version"] << 3
		savefile["/generation"] << generation
		savefile["/maxx"] << world.maxx
		savefile["/maxy"] << world.maxy
		savefile["/maxz"] << world.maxz
		// Visit each coordinate once, without rescanning other levels.
		for(var/y = 1, y <= world.maxy, y++)
			for(var/x = 1, x <= world.maxx, x++)
				var/turf/T = locate(x, y, A)
				var/ref = BuildVarDirectory(savefile, T, 1)
				if(!ref)
					throw EXCEPTION("Turf [x],[y],[A] could not be saved")
				savefile["/map/[A]/[y]/[x]"] << ref
				save_work_check()
		savefile.Flush()
		savefile = null // Close the candidate level before consistency validation.
		sleep(world.tick_lag)
		log_startup_progress("	Saved z-level [A].")
	// Bind every cross-level link before candidate validation reads round state.
	var/list/level_links = finish_level_links()
	if(level_links.len) round_state["level_links"] = level_links
	clear_bookkeeping()
	if(world_state)
		if(zone_export_state) finalize_zone_export(world_state)
		world_state["nodes"] = durable_export.finish_export()
		durable_export = null
		if(zone_export_state)
			operation.diagnostic_phase = "candidate_validation"
			if(!validate_captured_world_save(round_state)) throw EXCEPTION("Captured candidate is inconsistent; completed backup retained")
			clear_saved_zones()
			release_durable_world()
			clear_zone_export()
	operation.diagnostic_phase = "write_marker"
	if(fexists("map_saves/round.json") && !fdel("map_saves/round.json"))
		throw EXCEPTION("Could not replace round state")
	if(!text2file(json_encode(round_state), "map_saves/round.json"))
		throw EXCEPTION("Could not write round state")
	if(!text2file(generation,"map_saves/save_complete.txt"))
		throw EXCEPTION("Could not write save completion marker")
	log_startup_progress("Finished saving.")
	return 1

/map_storage/proc/BuildVarDirectory(savefile/savefile, datum/A, var/contents = 0, traversal = FALSE)
	if(!A || istype(A, /client))
		return 0
	if(!A.should_save)
		return 0
	if(istype(A, /obj/map_metadata))
		return 0
	for(var/ignored in ignore_types)
		if(istype(A, ignored))
			return 0
	if(istype(A, /atom/movable))
		var/atom/movable/movable = A
		var/list/previous = saving_world_movables["\ref[A]"]
		if(previous && previous["atom"] == A && previous["z"] != saving_z)
			if(traversal) return 0
			throw EXCEPTION("Captured object belongs to another saved level")
		if(movable.z && movable.z != saving_z)
			var/turf/location = get_turf(movable)
			var/datum/save_export_frame/owner = saving_export_stack.len ? saving_export_stack[saving_export_stack.len] : null
			var/valid_owner = istype(owner, /datum/save_export_frame)
			var/source_type = valid_owner && owner.source ? "[owner.source.type]" : "none"
			var/source_field = valid_owner && istext(owner.current_field) ? copytext("[owner.current_field]", 1, 81) : "contents"
			record_save_reference_failure("cross_level_object", A)
			throw EXCEPTION("Cross-level object reference cannot be represented in per-level save files: [A.type] saved_z=[saving_z] native_z=[movable.z] turf_z=[location ? location.z : 0] source_type=[source_type] source_field=[source_field]")
	var/ind = saving_references["\ref[A]"]
	var/ref = 0
	if(ind && saving_reference_pins[ind] == A)
		return ind
	ref = saving_reference_pins.len + 1
	saving_reference_pins += A
	saving_references["\ref[A]"] = ref
	if(istype(A, /atom/movable))
		saving_world_movables["\ref[A]"] = list("atom" = A, "z" = saving_z, "ref" = ref)
		bind_level_link(A, ref)
	if(durable_export) durable_export.bind_entry(A, saving_z, ref, src)
	var/datum/save_export_frame/frame = new
	frame.exporter = src
	frame.file = savefile
	frame.source = A
	frame.source_identity = "\ref[A]"
	frame.entry = ref
	if(isturf(A))
		A:persistence_export_frame = frame
	frame.accepts_children = A.load_contents && contents && istype(A, /atom)
	saving_export_frames["[ref]"] = frame
	saving_export_stack += frame
	try
		A.before_save_context(src, frame)
		require_export_frame(frame)
		for(var/datum/save_transfer/ticket in frame.tickets)
			if(!ticket.committed)
				throw EXCEPTION("Save hook left a prepared transfer uncommitted")
		capture_zone_turf(savefile, frame)
		savefile.cd = entry_path(savefile, ref)
		savefile["type"] << A.type
		if(frame.accepts_children)
			var/atom/parent = A
			// Keep obj-before-mob order; only declared transfers extend discovery.
			for(var/obj/content in parent.contents)
				if(content.loc != parent) continue
				var/child_ref = BuildVarDirectory(savefile, content, 1, TRUE)
				require_export_frame(frame)
				if(child_ref && (!content || content.loc != parent))
					throw EXCEPTION("Child moved or disappeared during capture")
				add_export_content(frame, child_ref)
				save_work_check()
				require_export_frame(frame)
			for(var/mob/content in parent.contents)
				if(content.loc != parent) continue
				var/child_ref = BuildVarDirectory(savefile, content, 1, TRUE)
				require_export_frame(frame)
				if(child_ref && (!content || content.loc != parent))
					throw EXCEPTION("Child moved or disappeared during capture")
				add_export_content(frame, child_ref)
				save_work_check()
				require_export_frame(frame)
		var/list/changing_vars = A.get_saved_vars()
		if(istype(A, /atom/movable))
			var/atom/movable/AM = A
			if(contents && AM.load_datums)
				changing_vars += "reagents"
		for(var/v in changing_vars)
			save_work_check()
			require_export_frame(frame)
			if(A.persistence_runtime_var(v))
				continue
			if(v in list("loc", "locs", "pixloc", "contents", "vars", "type", "parent_type", "x", "y", "z", "vis_locs", "client", "key", "ckey"))
				continue
			if(A.vars.Find(v))
				frame.current_field = v
				var/value
				if(level_link_target(A, v, A.vars[v]))
					value = encode_level_link(A.vars[v])
				else
					value = encode_saved_value(savefile, A.vars[v])
				frame.current_field = null
				require_export_frame(frame)
				savefile.cd = entry_path(savefile, ref)
				savefile[v] << value
		// Saved-variable recursion can declare a sibling after direct traversal.
		drain_save_transfers(frame)
		if(frame.accepts_children)
			var/content_value = encode_saved_contents(savefile, frame)
			// Chunk encoding can yield after the first transfer drain. Recheck
			// paid children at publication, not only before that last yield.
			drain_save_transfers(frame)
			savefile.cd = entry_path(savefile, ref)
			savefile["content"] << content_value
		savefile.cd = ".."
	catch(var/exception/e)
		release_export_frame(frame)
		throw e
	release_export_frame(frame)
	return ref

// Typed envelopes preserve literal marker strings and associative/nested lists.
// Lists are indexed separately so aliases and cycles survive a round trip.
/map_storage/proc/encode_saved_value(savefile/F, value)
	if(istype(value, /obj/map_metadata))
		return list("kind" = "map")
	if(istype(value, /area))
		var/area/AR = value
		if(zone_export_state) return encode_zone_reference(AR)
		var/turf/T = locate(/turf) in AR
		if(!T)
			throw EXCEPTION("Referenced area has no world turf: [AR.type]")
		return list("kind" = "area", "x" = T.x, "y" = T.y, "z" = T.z, "type" = AR.type)
	if(islist(value))
		var/list/L = value
		var/id = saving_lists["\ref[L]"]
		if(!id || saving_list_pins[id] != L)
			id = saving_list_pins.len + 1
			saving_list_pins += list(L)
			saving_lists["\ref[L]"] = id
			var/list/snapshot = L.Copy()
			F["/lists/[id]/length"] << snapshot.len
			for(var/i = 1, i <= snapshot.len, i++)
				save_work_check()
				TICK_CHECK
				var/key = snapshot[i]
				var/encoded_key = encode_saved_value(F, key)
				var/encoded_value = encode_saved_value(F, (isnum(key) || isnull(key)) ? null : snapshot[key])
				F["/lists/[id]/[i]/key"] << encoded_key
				F["/lists/[id]/[i]/value"] << encoded_value
		return list("kind" = "list", "ref" = id)
	if(isturf(value))
		var/turf/T = value
		return list("kind" = "turf", "x" = T.x, "y" = T.y, "z" = T.z)
	if(istype(value, /datum))
		var/id = BuildVarDirectory(F, value, 1)
		return list("kind" = "entry", "ref" = id)
	return list("kind" = "value", "value" = value)

// Version 3 advertises dense chunks so version-2 readers reject before import.
// Direct callers writing version 2 retain the historical small-record format.
/map_storage/proc/encode_saved_contents(savefile/F, datum/save_export_frame/frame)
	if(F["/format_version"] != 3)
		if(frame.content_refs.len > 500)
			throw EXCEPTION("Dense contents require save format 3")
		return list2params(frame.content_refs)
	var/list/chunks = list()
	for(var/start = 1, start <= frame.content_refs.len, start += 500)
		chunks += list2params(frame.content_refs.Copy(start, min(start + 500, frame.content_refs.len + 1)))
		save_work_check()
		require_export_frame(frame)
	return chunks

// Cross-level links. A declared field whose movable target is placed on another
// level stores a link ID; round state maps each ID to the target's own level
// entry once that level is exported. A target which would not be saved encodes
// null, exactly as an unsaved same-level entry does. An unbound saved target
// fails closed instead of silently dropping the relationship.
/map_storage/proc/level_link_target(datum/source, field, value)
	if(!istype(value, /atom/movable) || !source.persistence_level_link_var(field))
		return FALSE
	var/turf/T = get_turf(value)
	return T && T.z != saving_z

/map_storage/proc/level_link_target_saved(atom/movable/target)
	if(!target.should_save || istype(target, /obj/map_metadata))
		return FALSE
	for(var/ignored in ignore_types)
		if(istype(target, ignored))
			return FALSE
	return TRUE

/map_storage/proc/encode_level_link(atom/movable/target)
	if(!level_link_target_saved(target))
		return list("kind" = "entry", "ref" = 0)
	var/identity = "\ref[target]"
	var/id = saving_level_link_ids[identity]
	if(id)
		var/list/existing = saving_level_links[id]
		if(existing["atom"] != target)
			throw EXCEPTION("Cross-level link identity changed during export")
		return list("kind" = "level_link", "id" = id)
	var/list/link = list("atom" = target, "z" = 0, "ref" = 0, "type" = "[target.type]")
	saving_level_links += list(link)
	id = saving_level_links.len
	saving_level_link_ids[identity] = id
	// The target's own level may already be complete.
	var/list/previous = saving_world_movables[identity]
	if(previous && previous["atom"] == target)
		link["z"] = previous["z"]
		link["ref"] = previous["ref"]
	return list("kind" = "level_link", "id" = id)

/map_storage/proc/bind_level_link(atom/movable/A, ref)
	var/id = saving_level_link_ids["\ref[A]"]
	if(!id)
		return
	var/list/link = saving_level_links[id]
	if(link["atom"] != A)
		throw EXCEPTION("Cross-level link identity changed during export")
	if(link["ref"] && (link["ref"] != ref || link["z"] != saving_z))
		record_save_reference_failure("duplicate_level_link", A, ref, link["z"], link["ref"])
		throw EXCEPTION("Cross-level link target was exported more than once: type=[A.type] first_z=[link["z"]] first_ref=[link["ref"]] current_z=[saving_z] current_ref=[ref]")
	link["z"] = saving_z
	link["ref"] = ref

// Returns JSON-safe rows without live objects, then releases the export pins.
/map_storage/proc/finish_level_links()
	var/list/rows = list()
	for(var/list/link in saving_level_links)
		if(!link["ref"])
			record_save_reference_failure("unbound_level_link", link["atom"])
			throw EXCEPTION("Cross-level link target is absent from the saved world: type=[link["type"]]")
		rows += list(list("z" = link["z"], "ref" = link["ref"], "type" = link["type"]))
	saving_level_links = list()
	saving_level_link_ids = list()
	return rows
