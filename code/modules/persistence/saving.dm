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
	if(moving_save_chunk)
		moving_save_chunk.check()
		return
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
	prepare_moving_save_roster()
#ifdef CIV13_HUMAN_SPATIAL_EXPERIMENTAL
	prepare_human_save_roster(operation)
	capture_human_save_roster_positions(operation)
#endif
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
		drain_moving_save_roster(savefile)
#ifdef CIV13_HUMAN_SPATIAL_EXPERIMENTAL
		drain_human_save_roster(savefile, operation)
#endif
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
#ifdef CIV13_HUMAN_SPATIAL_EXPERIMENTAL
	inspect_human_saved_origins(operation)
	inspect_human_present_saved_slots(operation)
	inspect_human_saved_geometry(operation)
	inspect_human_saved_owners(operation, generation)
	operation.seal_human_containment_proof()
#endif
#ifdef CIV13_HUMAN_SUBTILE_CAPTURE_SOURCE
	operation.validate_human_spatial_candidates()
#endif
	operation.diagnostic_phase = "write_marker"
	if(fexists("map_saves/round.json") && !fdel("map_saves/round.json"))
		throw EXCEPTION("Could not replace round state")
	if(!text2file(json_encode(round_state), "map_saves/round.json"))
		throw EXCEPTION("Could not write round state")
#ifdef CIV13_HUMAN_SUBTILE_CAPTURE_SOURCE
	operation.validate_human_spatial_candidates()
#endif
	if(!text2file(generation,"map_saves/save_complete.txt"))
		throw EXCEPTION("Could not write save completion marker")
	log_startup_progress("Finished saving.")
	return 1

/map_storage/proc/BuildVarDirectory(savefile/savefile, datum/A, var/contents = 0, traversal = FALSE, datum/human_request = null)
	if(!A || istype(A, /client))
		return 0
#ifdef CIV13_HUMAN_SPATIAL_EXPERIMENTAL
	// The registry is an initial omission check, not a fixed membership set.
	// New humans are registered on first traversal/reference below.
#endif
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
	if(!moving_save_chunk && istype(A, /atom/movable) && moving_save_roots["\ref[A]"])
		var/list/root = moving_save_roots["\ref[A]"]
		if(root["atom"] != A) throw EXCEPTION("Moving save root identity changed")
		if(!saving_references["\ref[A]"]) return capture_moving_save_root(savefile, root)
#ifdef CIV13_HUMAN_SPATIAL_EXPERIMENTAL
	if(!human_request && !moving_save_chunk && ishuman(A))
		var/list/human_root = classify_human_save_entry(A, persistence_active_operation)
		if(human_root["mode"] == "spatial" && !saving_references[save_entry_identity(A)]) return capture_human_save_root(savefile, human_root)
#endif
	if(moving_save_chunk && istype(A, /atom/movable) && A != moving_save_chunk.root && !saving_references["\ref[A]"])
		throw EXCEPTION("Moving save chunk references an uncaptured external movable")
	var/identity = save_entry_identity(A)
	var/ind = saving_references[identity]
	var/ref = 0
	if(ind && saving_reference_pins[ind] == A)
		if(human_request) throw EXCEPTION("Human spatial request reached an existing saved entry")
		return ind
	if(moving_save_chunk) moving_save_chunk.reserve_node()
	ref = saving_reference_pins.len + 1
	saving_reference_pins += A
	saving_references[identity] = ref
	if(istype(A, /atom/movable))
		saving_world_movables["\ref[A]"] = list("atom" = A, "z" = saving_z, "ref" = ref)
		bind_level_link(A, ref)
	if(durable_export && istype(A, /atom/movable)) durable_export.bind_entry(A, saving_z, ref, src)
	var/datum/save_export_frame/frame = new
	frame.exporter = src
	frame.file = savefile
	frame.source = A
	frame.source_identity = identity
	frame.entry = ref
#ifdef CIV13_HUMAN_SPATIAL_EXPERIMENTAL
	if(ishuman(A))
		var/list/human_root = human_save_roots[save_entry_identity(A)]
		if(!human_root || human_root["atom"] != A || human_root["ref"] || (human_request && human_root["request"] != human_request) || (!human_request && human_root["mode"] != "legacy"))
			throw EXCEPTION("Human spatial root registration changed")
		human_root["ref"] = ref
		if(!human_request) frame.human_legacy_aligned = TRUE
#endif
#ifdef CIV13_HUMAN_SUBTILE_CAPTURE_SOURCE
	if(human_request)
		bind_human_spatial_frame(frame, human_request)
#else
	if(human_request) throw EXCEPTION("Human spatial capture is unavailable")
#endif
	if(isturf(A))
		A:persistence_export_frame = frame
	frame.accepts_children = A.load_contents && contents && istype(A, /atom)
	saving_export_frames["[ref]"] = frame
	saving_export_stack += frame
	try
		A.before_save_context(src, frame)
		if(moving_save_chunk) moving_save_chunk.check()
		require_export_frame(frame)
		for(var/datum/save_transfer/ticket in frame.tickets)
			if(!ticket.committed)
				throw EXCEPTION("Save hook left a prepared transfer uncommitted")
		capture_zone_turf(savefile, frame)
		savefile.cd = entry_path(savefile, ref)
		record_save_capture_path(savefile, "type")
		savefile["type"] << A.type
		if(frame.accepts_children)
			var/atom/parent = A
			// Keep obj-before-mob order; only declared transfers extend discovery.
			for(var/obj/content in parent.contents)
				if(content.loc != parent) continue
				var/child_ref = BuildVarDirectory(savefile, content, 1, TRUE)
				require_export_frame(frame)
				if(child_ref && (!content || (content.loc != parent && !moving_save_root_edge(content, parent))))
					throw EXCEPTION("Child moved or disappeared during capture")
				add_export_content(frame, child_ref)
				save_work_check()
				require_export_frame(frame)
			for(var/mob/content in parent.contents)
				if(content.loc != parent) continue
				var/child_ref = BuildVarDirectory(savefile, content, 1, TRUE)
				require_export_frame(frame)
				if(child_ref && (!content || (content.loc != parent && !moving_save_root_edge(content, parent))))
					throw EXCEPTION("Child moved or disappeared during capture")
				add_export_content(frame, child_ref)
				save_work_check()
				require_export_frame(frame)
		var/list/changing_vars = A.get_saved_vars()
#ifdef CIV13_HUMAN_SPATIAL_EXPERIMENTAL
		// Explicitly encode the audited defaults; do not infer constructor state
		// from an absent savefile field or change a live relationship.
		// Freeze a legacy frame's admitted alignment even if the actor starts
		// walking while the remaining fields are serialized.
		if(frame.human_legacy_aligned)
			changing_vars -= list("step_x", "step_y", "human_subtile_position", "human_subtile_restore_schema")
		if(frame.human_spatial_position)
			changing_vars |= human_spatial_link_fields()
			changing_vars |= human_spatial_slot_fields()
			changing_vars |= list("bound_x", "bound_y", "bound_width", "bound_height")
		if(isturf(A))
			var/turf/candidate_turf = A
			var/datum/persistence_world_operation/human_save_operation = persistence_active_operation
			if(!human_save_operation || !human_save_operation.current(src, "save")) throw EXCEPTION("Human footprint serialization lost its save owner")
			// Later enrollment may refer to a turf already serialized. Save the
			// candidate's own geometry for every turf, not a later live value.
			var/prior_turf_fields = changing_vars.len
			changing_vars |= list("density")
			human_save_operation.human_geometry_turf_records++
			human_save_operation.human_geometry_added_fields += changing_vars.len - prior_turf_fields
			// The transformation pointer is temporary runtime state. Retain only
			// a scalar observation for admission; never serialize its live object.
			var/geometry_shard = round((ref - 1) / 512)
			savefile["/human_geometry/[geometry_shard]/[ref]/transforming"] << !!candidate_turf.vehicle_transforming
		if(istype(A, /obj))
			var/datum/persistence_world_operation/human_object_operation = persistence_active_operation
			if(!human_object_operation || !human_object_operation.current(src, "save")) throw EXCEPTION("Human obstruction serialization lost its save owner")
			// Objects may overhang a turf whose actor is enrolled later.
			var/prior_object_fields = changing_vars.len
			changing_vars |= list("density", "bound_x", "bound_y", "bound_width", "bound_height", "step_x", "step_y")
			human_object_operation.human_geometry_object_records++
			human_object_operation.human_geometry_added_fields += changing_vars.len - prior_object_fields
#endif
#ifdef CIV13_HUMAN_SUBTILE_CAPTURE_SOURCE
		if(frame.human_spatial_position)
			changing_vars -= list("step_x", "step_y", "glide_size", "human_subtile_position")
			if(frame.human_spatial_position["sx"] || frame.human_spatial_position["sy"])
				changing_vars |= list("human_subtile_position", "human_subtile_restore_schema")
#endif
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
				var/human_spatial_override = FALSE
#ifdef CIV13_HUMAN_SUBTILE_CAPTURE_SOURCE
				if(frame.human_spatial_position && v == "human_subtile_position")
					value = encode_saved_value(savefile, frame.human_spatial_position)
					human_spatial_override = TRUE
				if(frame.human_spatial_position && v == "human_subtile_restore_schema")
					value = encode_saved_value(savefile, 1)
					human_spatial_override = TRUE
#endif
				if(!human_spatial_override)
					if(level_link_target(A, v, A.vars[v]))
						value = encode_level_link(A.vars[v])
					else
						value = encode_saved_value(savefile, A.vars[v])
				frame.current_field = null
				require_export_frame(frame)
				savefile.cd = entry_path(savefile, ref)
				record_save_capture_path(savefile, v)
				savefile[v] << value
		// Saved-variable recursion can declare a sibling after direct traversal.
		drain_save_transfers(frame)
		if(frame.accepts_children)
			var/content_value = encode_saved_contents(savefile, frame)
			// Chunk encoding can yield after the first transfer drain. Recheck
			// paid children at publication, not only before that last yield.
			drain_save_transfers(frame)
			savefile.cd = entry_path(savefile, ref)
			record_save_capture_path(savefile, "content")
			savefile["content"] << content_value
		savefile.cd = ".."
	catch(var/exception/e)
		release_export_frame(frame)
		throw e
	release_export_frame(frame)
#ifdef CIV13_HUMAN_SUBTILE_CAPTURE_SOURCE
	if(human_request)
		var/datum/human_subtile_save_request/completed_request = human_request
		if(!completed_request.operation || !completed_request.operation.current(src, "save")) throw EXCEPTION("Human spatial operation ended before serialization")
		completed_request.serialized = TRUE
#endif
	return ref

// Typed envelopes preserve literal marker strings and associative/nested lists.
// Lists are indexed separately so aliases and cycles survive a round trip.
/map_storage/proc/encode_saved_value(savefile/F, value)
	var/datum/moving_save_capture/chunk = moving_save_chunk
	if(!chunk) return encode_saved_value_contents(F, value)
	if(++chunk.encoding_depth > 64) throw EXCEPTION("Moving save chunk exceeds its nesting bound")
	try
		. = encode_saved_value_contents(F, value)
	catch(var/exception/error)
		chunk.encoding_depth--
		throw error
	chunk.encoding_depth--

/map_storage/proc/encode_saved_value_contents(savefile/F, value)
	if(moving_save_chunk && istext(value)) moving_save_chunk.reserve_bytes(4 * length(value))
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
		var/id = saving_lists[L]
		if(!id || saving_list_pins[id] != L)
			id = saving_list_pins.len + 1
			saving_list_pins += list(L)
			saving_lists[L] = id
			if(moving_save_chunk)
				moving_save_chunk.reserve_node()
				moving_save_chunk.reserve_edges(L.len)
			var/list/snapshot = L.Copy()
			record_save_capture_path(F, "/lists/[id]/length")
			F["/lists/[id]/length"] << snapshot.len
			for(var/i = 1, i <= snapshot.len, i++)
				save_work_check()
				if(!moving_save_chunk)
					TICK_CHECK
				var/key = snapshot[i]
				var/encoded_key = encode_saved_value(F, key)
				var/encoded_value = encode_saved_value(F, (isnum(key) || isnull(key)) ? null : snapshot[key])
				record_save_capture_path(F, "/lists/[id]/[i]/key")
				F["/lists/[id]/[i]/key"] << encoded_key
				record_save_capture_path(F, "/lists/[id]/[i]/value")
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

// First cohort only: empty, direct-turf simple animals. Their audited save hooks
// have no sleeps or paid-child transfers. Humans and containers keep the existing
// serializer; do not expand this predicate without a field/hook ownership audit.
/map_storage
	var/tmp/list/moving_save_roots = list()
	var/tmp/datum/moving_save_capture/moving_save_chunk
#ifdef CIV13_HUMAN_SPATIAL_EXPERIMENTAL
	var/tmp/list/human_save_roots = list()
#endif

/map_storage/proc/moving_save_root_supported(mob/living/simple_animal/A)
	if(!istype(A) || !A.should_save || A.client || !isturf(A.loc) || A.contents.len) return FALSE
	for(var/ignored in ignore_types)
		if(istype(A, ignored)) return FALSE
	#ifdef CIV13_SUBTILE_PULL_PAIRS
	if(subtile_pull_ownership.owners[A]) return FALSE
	#endif
	for(var/key in list("corpse_decay_record", "pulling", "pulledby", "buckled", "npc_subtile_pulse", "ride", "rider", "control_object", "handcuffed", "legcuffed", "following_mob", "origin"))
		if(A.vars.Find(key) && A.vars[key]) return FALSE
	for(var/key in list("grab_list", "grabbed_by", "pinned", "friends"))
		if(A.vars.Find(key) && length(A.vars[key])) return FALSE
	return TRUE

/map_storage/proc/prepare_moving_save_roster()
	moving_save_roots = list()
	// Fixtures without the production registry retain the legacy path.
	var/list/registry = global.vars["mob_list"]
	if(!islist(registry)) return
	if(registry.len > 8192) return // Preserve legacy saving instead of adding a global refusal.
	var/list/roster = registry.Copy()
	for(var/mob/living/simple_animal/A in roster)
		if(!moving_save_root_supported(A)) continue
		var/datum/moving_save_preflight/preflight = new
		preflight.exporter = src
		preflight.root = A
		preflight.start_tick = world.time
		preflight.start_usage = world.tick_usage
		var/admitted = preflight.accept(A)
		if(!admitted)
			save_work_check()
			continue // No IDs or bindings allocated: unsupported stationary roots keep the legacy path.
		var/identity = "\ref[A]"
		moving_save_roots[identity] = list("atom" = A, "identity" = identity, "z" = A.z, "origin" = null, "ref" = 0)
		save_work_check()

// Side-effect-free eligibility walk. It neither invokes before_save nor allocates
// serializer IDs. Conservative limits leave headroom for the actual typed encoder.
// Source audit: admitted simple-animal and nonmovable datum getters/exclusion
// hooks do not yield; new overrides require extending that audit before admission.
#ifdef CIV13_HUMAN_SUBTILE_CAPTURE_SOURCE
// Install only the detached value of an exact operation-owned handoff. The
// caller must still own roster admission and the frozen spatial edge.
/map_storage/proc/bind_human_spatial_frame(datum/save_export_frame/frame, datum/human_subtile_save_request/request)
	if(!frame || !request || !request.captured || !request.actor || request.actor.human_subtile_save_request != request || frame.source != request.actor || frame.exporter != src || !request.operation || !request.operation.current(src, "save") || !request.origin || !islist(request.position))
		throw EXCEPTION("Human spatial frame does not own a captured request")
	var/list/position = request.position.Copy()
	if(position.len != 5 || position["x"] != request.origin.x || position["y"] != request.origin.y || position["z"] != request.origin.z || !human_subtile_same(position, position) || position["sx"] < 0 || position["sx"] >= 32 || position["sy"] < 0 || position["sy"] >= 32)
		throw EXCEPTION("Human spatial frame has an invalid frozen origin")
	frame.human_spatial_request = request
	frame.human_spatial_position = position
	request.saved_ref = frame.entry
	request.saved_z = saving_z
	return TRUE

// Preparation only: this is not an admission to the moving-save roster and
// does not invoke hooks, reserve export IDs, or encode any values. Human save
// admission must remain disabled until field closure, handoff and mutation
// coverage are separately established. A returned group is a short-lived
// inventory for that future audit, never a durable snapshot or mutation lease.
/datum/moving_human_ownership_preflight
	should_save = FALSE
	var/mob/living/human/root
	var/turf/origin
	var/list/position
	var/start_tick
	var/list/members = list()
	var/list/parents = list()
	var/list/slots = list()

	proc/inspect(map_storage/exporter, mob/living/human/H)
		// A reused or partially failed inspection cannot accidentally authorize.
		root = null
		origin = null
		position = null
		members = list()
		parents = list()
		slots = list()
		if(!exporter || !H || isDeleted(H) || !H.should_save || !isturf(H.loc) || H.human_subtile_pulse) return FALSE
		start_tick = world.time
		var/turf/start = H.loc
		var/list/start_position = H.human_subtile_snapshot()
		var/datum/human_subtile_transaction/transaction = H.human_subtile_transaction
		if(transaction && (transaction.actor != H || transaction.cancelled || !human_subtile_same(transaction.expected, start_position))) return FALSE
		var/list/queue = list(H)
		var/list/seen = list()
		var/list/local_parents = list()
		var/list/local_slots = list()
		var/list/counts = list()
		var/list/slot_names = list("shoulder", "eyes", "l_hand", "r_hand", "back", "wear_mask", "handcuffed", "legcuffed", "wear_suit", "w_uniform", "shoes", "belt", "gloves", "head", "l_ear", "r_ear", "wear_id", "r_store", "l_store")
		seen["\ref[H]"] = H
		for(var/i = 1, i <= queue.len, i++)
			if(world.time != start_tick || queue.len > 128) return FALSE
			var/atom/movable/parent = queue[i]
			if(!parent || isDeleted(parent) || !parent.should_save) return FALSE
			for(var/ignored in exporter.ignore_types)
				if(istype(parent, ignored)) return FALSE
			if(parent.contents.len && !parent.load_contents) return FALSE
			if(parent.contents.len > 128 - queue.len) return FALSE
			counts["\ref[parent]"] = parent.contents.len
			for(var/atom/movable/child in parent.contents)
				if(!child || isDeleted(child) || child.loc != parent || seen["\ref[child]"]) return FALSE
				seen["\ref[child]"] = child
				local_parents["\ref[child]"] = parent
				queue += child
		for(var/key in slot_names)
			var/obj/item/item = H.vars[key]
			if(item)
				if(!istype(item) || item.loc != H || seen["\ref[item]"] != item) return FALSE
				local_slots[key] = item
		if(world.time != start_tick || H.loc != start || H.human_subtile_pulse || H.human_subtile_transaction != transaction || !human_subtile_same(start_position, H.human_subtile_snapshot())) return FALSE
		if(transaction && (transaction.actor != H || transaction.cancelled || !human_subtile_same(transaction.expected, start_position))) return FALSE
		for(var/key in slot_names)
			if(H.vars[key] != local_slots[key]) return FALSE
		for(var/atom/movable/member in queue)
			if(!member || isDeleted(member) || !member.should_save || (member.contents.len && !member.load_contents) || seen["\ref[member]"] != member || member.contents.len != counts["\ref[member]"]) return FALSE
			if(member != H && member.loc != local_parents["\ref[member]"]) return FALSE
		root = H
		origin = start
		position = start_position
		members = queue
		parents = local_parents
		slots = local_slots
		return TRUE
#endif

/datum/moving_save_preflight
	should_save = FALSE
	var/map_storage/exporter
	var/datum/root
	var/start_tick
	var/start_usage
	var/work = 0
	var/bytes = 0
	var/list/seen = list()
	proc/accept(value, depth = 0)
		if(++work > 512 || depth > 32 || world.time != start_tick || world.tick_usage - start_usage > 5) return FALSE
		if(istext(value))
			bytes += 4 * length(value)
			return bytes <= 262144
		if(islist(value))
			var/list/L = value
			var/key = L
			if(seen[key]) return TRUE
			if(L.len > 256 || seen.len >= 64) return FALSE
			seen[key] = TRUE
			for(var/i = 1, i <= L.len, i++)
				var/item = L[i]
				if(!accept(item, depth + 1) || !accept((isnum(item) || isnull(item)) ? null : L[item], depth + 1)) return FALSE
			return TRUE
		if(!istype(value, /datum) || isturf(value) || isarea(value) || istype(value, /obj/map_metadata)) return TRUE
		var/datum/D = value
		if(!D.should_save || istype(D, /client)) return TRUE
		for(var/ignored in exporter.ignore_types)
			if(istype(D, ignored)) return TRUE
		// Even already-written external movers stay legacy, avoiding mixed-root
		// physical relationships and successful-save regressions on stationary pets.
		if(istype(D, /atom/movable) && D != root) return FALSE
		var/key = exporter.save_entry_identity(D)
		if(seen[key]) return TRUE
		if(seen.len >= 64 || D.vars.len > 1024) return FALSE
		seen[key] = TRUE
		var/list/fields = D.get_saved_vars()
		if(istype(D, /atom/movable) && D:load_datums) fields |= "reagents"
		for(var/field in fields)
			if(D.persistence_runtime_var(field) || (field in list("loc", "locs", "pixloc", "contents", "vars", "type", "parent_type", "x", "y", "z", "vis_locs", "client", "key", "ckey"))) continue
			if(D.vars.Find(field) && !accept(D.vars[field], depth + 1)) return FALSE
		return world.time == start_tick && world.tick_usage - start_usage <= 5

/datum/moving_save_capture
	should_save = FALSE
	var/atom/movable/root
	var/start_tick
	var/start_usage
	var/admission_usage
	var/start_clock
	var/work = 0
	var/encoding_depth = 0
	var/nodes = 0
	var/edges = 0
	var/reserved_bytes = 0
	var/list/paths = list()
	proc/check()
		var/tick_delta = world.time - start_tick
		var/current_usage = world.tick_usage
		var/usage_delta = current_usage - start_usage
		var/elapsed_ds = (world.timeofday - start_clock + 864000) % 864000
		if(++work > 8192 || tick_delta || usage_delta > 10 || current_usage >= 90 || elapsed_ds > 1)
			throw EXCEPTION("Moving save chunk exceeded its capture budget or yielded: work=[work] tick_delta=[tick_delta] usage_delta=[usage_delta] total_usage=[current_usage] elapsed_ds=[elapsed_ds] admission_usage=[admission_usage] start_usage=[start_usage]")
	proc/reserve_bytes(count)
		reserved_bytes += count
		if(reserved_bytes > 1048576) throw EXCEPTION("Moving save chunk exceeds its byte reservation")
		check()
	proc/reserve_node()
		reserve_bytes(256)
		if(++nodes > 128) throw EXCEPTION("Moving save chunk exceeds its node bound")
		check()
	proc/reserve_edges(count)
		reserve_bytes(128 * count)
		edges += count
		if(edges > 2048) throw EXCEPTION("Moving save chunk exceeds its list-edge bound")
		check()

/map_storage/proc/record_save_capture_path(savefile/F, path)
	if(moving_save_chunk)
		moving_save_chunk.check()
		var/absolute = copytext(path, 1, 2) == "/" ? path : "[F.cd]/[path]"
		moving_save_chunk.paths += absolute

/map_storage/proc/capture_moving_save_root(savefile/destination, list/record)
	var/mob/living/simple_animal/A = record["atom"]
	// Reserve tick headroom before allocating a stage or any root identities.
	// This wait is bounded; it never occurs inside the synchronous capture.
	var/datum/save_export_frame/parent_frame = saving_export_stack.len ? saving_export_stack[saving_export_stack.len] : null
	if(world.tick_usage >= 80)
		sleep(world.tick_lag)
		if(parent_frame)
			require_export_frame(parent_frame)
			if(!saving_export_stack.len || saving_export_stack[saving_export_stack.len] != parent_frame)
				throw EXCEPTION("Moving save caller changed while awaiting capture headroom")
		else if(saving_export_stack.len)
			throw EXCEPTION("Moving save caller appeared while awaiting capture headroom")
		if(world.tick_usage >= 80)
			throw EXCEPTION("Moving save capture has no tick headroom after bounded wait")
	if(!A || record["atom"] != A || "\ref[A]" != record["identity"] || !moving_save_root_supported(A) || A.z != record["z"] || A.z != saving_z)
		throw EXCEPTION("Admitted moving save root changed containment, level or identity")
	var/turf/origin = A.loc
	var/admission_usage = world.tick_usage
	var/savefile/staged = new
	staged["/format_version"] << 3
	var/datum/moving_save_capture/chunk = new
	chunk.root = A
	chunk.admission_usage = admission_usage
	chunk.start_tick = world.time
	chunk.start_usage = world.tick_usage
	chunk.start_clock = world.timeofday
	moving_save_chunk = chunk
	var/ref
	try
		ref = BuildVarDirectory(staged, A, 1)
		chunk.check()
		if(!ref || !A || A.loc != origin || !moving_save_root_supported(A)) throw EXCEPTION("Moving save root changed during capture")
	catch(var/exception/error)
		moving_save_chunk = null
		// IDs, durable bindings and list aliases may already be reserved. Abort
		// the entire candidate: ordinary operation cleanup owns their release.
		throw error
	moving_save_chunk = null
	record["origin"] = origin
	record["ref"] = ref
	// The native in-memory savefile is detached. Copy only paths written by this
	// chunk, retaining typed envelopes and global per-level entry/list IDs.
	for(var/path in chunk.paths)
		var/value = staged[path]
		destination[path] << value
		save_work_check()
	return ref

/map_storage/proc/moving_save_root_edge(atom/movable/A, atom/parent)
	var/identity = "\ref[A]"
#ifdef CIV13_HUMAN_SPATIAL_EXPERIMENTAL
	var/list/human_root = human_save_roots[identity]
	if(human_root && human_root["mode"] == "spatial" && human_root["atom"] == A && human_root["identity"] == identity && human_root["ref"] && saving_reference_pins[human_root["ref"]] == A)
		return isturf(parent) && isturf(A.loc) && isturf(human_root["origin"]) && A.z == human_root["z"]
#endif
	var/list/record = moving_save_roots[identity]
	// A pre-capture wait can move the root away from the traversed turf.
	// add_export_content defers that edge to its frozen actual origin; never
	// use this allowance for a container or an unsupported ownership change.
	return record && record["atom"] == A && record["identity"] == identity && record["ref"] && saving_reference_pins[record["ref"]] == A && isturf(parent) && isturf(record["origin"]) && moving_save_root_supported(A) && A.z == record["z"]

/map_storage/proc/drain_moving_save_roster(savefile/F)
	for(var/identity in moving_save_roots)
		var/list/record = moving_save_roots[identity]
		if(record["z"] != saving_z) continue
		var/mob/living/simple_animal/A = record["atom"]
		if(!A || "\ref[A]" != identity || !moving_save_root_supported(A) || A.z != saving_z)
			throw EXCEPTION("Moving save roster member disappeared or changed ownership")
		var/ref = record["ref"]
		if(!ref) ref = capture_moving_save_root(F, record)
		// Replay yields too: match the ordinary traversal post-capture refusal.
		if(!A || record["atom"] != A || "\ref[A]" != identity || !moving_save_root_supported(A) || A.z != saving_z)
			throw EXCEPTION("Moving save roster member changed during chunk replay")
		var/turf/origin = record["origin"]
		var/parent_ref = origin ? saving_references["\ref[origin]"] : null
		if(!parent_ref || saving_reference_pins[parent_ref] != origin)
			throw EXCEPTION("Moving save origin turf was replaced or not captured")
		var/key = "[ref]"
		var/owner = saving_content_owners[key]
		if(owner && owner != parent_ref) throw EXCEPTION("Moving save root has conflicting saved owners")
		if(!owner)
			var/path = "[entry_path(F, parent_ref)]/content"
			var/list/chunks = F[path]
			if(!islist(chunks)) throw EXCEPTION("Moving save origin has no version-3 contents")
			chunks += list2params(list(key))
			F[path] << chunks
			saving_content_owners[key] = parent_ref
		save_work_check()

#ifdef CIV13_HUMAN_SPATIAL_EXPERIMENTAL
// This opt-in source prototype has no production enablement. Its pre-marker
// gate deliberately refuses until encoded link and geometry checks exist.
/proc/human_spatial_generic_object(path)
	// Nondense generic objects inherit the human passability profile. Special
	// roots remain refused until their saved-state projection has been audited.
	if(!ispath(path, /obj)) return FALSE
	if(ispath(path, /obj/item/tape) || ispath(path, /obj/item/weapon/gun/projectile/automatic/stationary) || ispath(path, /obj/effect/effect/smoke/bad) || ispath(path, /obj/covers)) return FALSE
	var/static/list/special_structure_roots = list(/obj/structure/TV, /obj/structure/barricade, /obj/structure/closet, /obj/structure/simple_door, /obj/structure/grille, /obj/structure/iv_drip, /obj/structure/optable, /obj/structure/plant_pot, /obj/structure/railing, /obj/structure/bed, /obj/structure/table, /obj/structure/window, /obj/structure/barbwire, /obj/structure/vehicleparts/frame, /obj/structure/lamp, /obj/structure/props, /obj/structure/basketball_hoop, /obj/structure/multiz)
	for(var/special in special_structure_roots)
		if(ispath(path, special)) return FALSE
	return TRUE

/proc/human_spatial_link_fields()
	return list("buckled", "riding", "riding_mob", "using_drone", "control_object", "incorporeal_move", "pulledby", "using_object", "using_cannon", "football", "pulling", "driver", "driver_vehicle")

/proc/human_spatial_slot_fields()
	return list("shoulder", "eyes", "l_hand", "r_hand", "back", "wear_mask", "handcuffed", "legcuffed", "wear_suit", "w_uniform", "shoes", "belt", "gloves", "head", "l_ear", "r_ear", "wear_id", "r_store", "l_store")

/map_storage/proc/human_saved_entry_fields(savefile/F, ref)
	if(!isnum(ref) || ref < 1 || ref != round(ref)) throw EXCEPTION("Human candidate entry identity is invalid")
	F.cd = "/"
	if(!("entries" in F.dir)) throw EXCEPTION("Human candidate entries are missing")
	F.cd = "/entries"
	var/shard = round((ref - 1) / 512)
	if(!("[shard]" in F.dir)) throw EXCEPTION("Human candidate entry shard is missing")
	F.cd = "/entries/[shard]"
	if(!("[ref]" in F.dir)) throw EXCEPTION("Human candidate entry is missing")
	F.cd = entry_path(F, ref)
	return F.dir.Copy()

/proc/human_candidate_scalar(value)
	if(!islist(value)) throw EXCEPTION("Human candidate scalar envelope is invalid")
	var/list/envelope = value
	if(envelope["kind"] == "entry" && ("ref" in envelope) && isnum(envelope["ref"]) && envelope["ref"] == 0) return null
	if(envelope["kind"] != "value" || !("value" in envelope)) throw EXCEPTION("Human candidate field is not a scalar")
	return envelope["value"]

/datum/human_candidate_reference_budget
	should_save = FALSE
	var/work = 0
	var/list/seen = list()

// Traverse only known physical fields. Ordinary AI target fields are not
// treated as physical ownership. Unknown encodings and cross-level physical
// links are refused, not decoded into live objects.
/map_storage/proc/human_candidate_mentions(savefile/F, value, list/targets, datum/human_candidate_reference_budget/budget, depth = 0)
	if(!islist(value) || !budget || ++budget.work > 10000 || depth > 32) throw EXCEPTION("Human reciprocal reference budget or envelope is invalid")
	var/list/envelope = value
	switch(envelope["kind"])
		if("entry")
			if(!("ref" in envelope) || !isnum(envelope["ref"]) || envelope["ref"] < 0 || envelope["ref"] != round(envelope["ref"])) throw EXCEPTION("Human reciprocal entry is invalid")
			return !!targets["[envelope["ref"]]"]
		if("level_link")
			throw EXCEPTION("Human reciprocal cross-level link is unsupported")
		if("list")
			var/id = envelope["ref"]
			if(!isnum(id) || id < 1 || id != round(id)) throw EXCEPTION("Human reciprocal list identity is invalid")
			if(budget.seen["[id]"]) return FALSE
			budget.seen["[id]"] = TRUE
			F.cd = "/"
			if(!("lists" in F.dir)) throw EXCEPTION("Human reciprocal list root is missing")
			F.cd = "/lists"
			if(!("[id]" in F.dir)) throw EXCEPTION("Human reciprocal list is missing")
			F.cd = "/lists/[id]"
			if(!("length" in F.dir)) throw EXCEPTION("Human reciprocal list length is missing")
			var/count = F["length"]
			if(!isnum(count) || count < 0 || count != round(count) || count > 4096) throw EXCEPTION("Human reciprocal list length is invalid")
			for(var/i = 1, i <= count, i++)
				F.cd = "/lists/[id]"
				if(!("[i]" in F.dir)) throw EXCEPTION("Human reciprocal list element is missing")
				F.cd = "/lists/[id]/[i]"
				if(!("key" in F.dir) || !("value" in F.dir)) throw EXCEPTION("Human reciprocal list edge is missing")
				var/key = F["key"]
				var/item = F["value"]
				if(human_candidate_mentions(F, key, targets, budget, depth + 1) || human_candidate_mentions(F, item, targets, budget, depth + 1)) return TRUE
			return FALSE
		if("value", "turf", "area", "zone", "map")
			return FALSE
	throw EXCEPTION("Human reciprocal value kind is unsupported")

/map_storage/proc/human_candidate_scalar_field(savefile/F, ref, key)
	var/list/fields = human_saved_entry_fields(F, ref)
	if(!(key in fields)) throw EXCEPTION("Human candidate required field is missing")
	return human_candidate_scalar(F[key])

/map_storage/proc/human_candidate_turf_transforming(savefile/F, ref)
	if(!isnum(ref) || ref < 1 || ref != round(ref)) throw EXCEPTION("Human turf geometry identity is invalid")
	var/shard = round((ref - 1) / 512)
	F.cd = "/"
	if(!("human_geometry" in F.dir)) throw EXCEPTION("Human turf geometry metadata is missing")
	F.cd = "/human_geometry"
	if(!("[shard]" in F.dir)) throw EXCEPTION("Human turf geometry shard is missing")
	F.cd = "/human_geometry/[shard]"
	if(!("[ref]" in F.dir)) throw EXCEPTION("Human turf geometry entry is missing")
	F.cd = "/human_geometry/[shard]/[ref]"
	if(!("transforming" in F.dir)) throw EXCEPTION("Human turf transform observation is missing")
	var/value = F["transforming"]
	if(!isnum(value) || !(value in list(0, 1))) throw EXCEPTION("Human turf transform observation is invalid")
	return value

/map_storage/proc/human_candidate_map_ref(savefile/F, z, y, x)
	F.cd = "/"
	if(!("map" in F.dir)) throw EXCEPTION("Human candidate map is missing")
	F.cd = "/map"
	if(!("[z]" in F.dir)) throw EXCEPTION("Human candidate level is missing")
	F.cd = "/map/[z]"
	if(!("[y]" in F.dir)) throw EXCEPTION("Human candidate row is missing")
	F.cd = "/map/[z]/[y]"
	if(!("[x]" in F.dir)) throw EXCEPTION("Human candidate cell is missing")
	return F["[x]"]

/map_storage/proc/human_candidate_read_position(savefile/F, ref)
	var/list/fields = human_saved_entry_fields(F, ref)
	if(!("human_subtile_position" in fields)) return null
	var/list/envelope = F["human_subtile_position"]
	if(!islist(envelope) || envelope["kind"] != "list" || !isnum(envelope["ref"]) || envelope["ref"] < 1 || envelope["ref"] != round(envelope["ref"])) throw EXCEPTION("Human saved position envelope is invalid")
	var/id = envelope["ref"]
	F.cd = "/"
	if(!("lists" in F.dir)) throw EXCEPTION("Human saved position lists are missing")
	F.cd = "/lists"
	if(!("[id]" in F.dir)) throw EXCEPTION("Human saved position list is missing")
	F.cd = "/lists/[id]"
	if(!("length" in F.dir) || F["length"] != 5) throw EXCEPTION("Human saved position length is invalid")
	var/list/position = list()
	for(var/i = 1, i <= 5, i++)
		F.cd = "/lists/[id]"
		if(!("[i]" in F.dir)) throw EXCEPTION("Human saved position entry is missing")
		F.cd = "/lists/[id]/[i]"
		if(!("key" in F.dir) || !("value" in F.dir)) throw EXCEPTION("Human saved position field is missing")
		var/key = human_candidate_scalar(F["key"])
		var/value = human_candidate_scalar(F["value"])
		if(!(key in list("x", "y", "z", "sx", "sy")) || (key in position) || !isnum(value) || value != round(value)) throw EXCEPTION("Human saved position field is invalid")
		position[key] = value
	if(position.len != 5) throw EXCEPTION("Human saved position is incomplete")
	return position

/map_storage/proc/human_candidate_position_matches(savefile/F, ref, list/expected)
	var/list/position = human_candidate_read_position(F, ref)
	if(!expected["sx"] && !expected["sy"]) return isnull(position)
	return human_subtile_same(position, expected)

/map_storage/proc/build_human_obstruction_index(savefile/F, z, list/positions, datum/persistence_world_operation/operation, owner_kind, deadline)
	if(!operation || !operation.current(src, owner_kind) || !islist(positions)) throw EXCEPTION("Human obstruction index lacks its owner")
	var/list/targets = list()
	for(var/list/position in positions)
		if(!islist(position) || position["z"] != z) throw EXCEPTION("Human obstruction index position is invalid")
		for(var/dx = 0, dx <= !!position["sx"], dx++)
			for(var/dy = 0, dy <= !!position["sy"], dy++)
				var/x = position["x"] + dx
				var/y = position["y"] + dy
				if(x < 1 || x > world.maxx || y < 1 || y > world.maxy) throw EXCEPTION("Human obstruction index footprint is outside the world")
				targets["[x]:[y]"] = TRUE
	var/list/index = list()
	var/list/seen = list()
	var/cell_work = 0
	var/edge_work = 0
	for(var/y = 1, y <= world.maxy, y++)
		for(var/x = 1, x <= world.maxx, x++)
			if(++cell_work % 256 == 0)
				TICK_CHECK
				if(world.time >= deadline || !operation.current(src, owner_kind)) throw EXCEPTION("Human obstruction index exceeded its budget")
			var/turf_ref = human_candidate_map_ref(F, z, y, x)
			var/list/turf_fields = human_saved_entry_fields(F, turf_ref)
			if(!("type" in turf_fields) || !ispath(F["type"], /turf) || !("content" in turf_fields)) throw EXCEPTION("Human obstruction index turf is invalid")
			var/list/raw = F["content"]
			if(!islist(raw) || raw.len > 256) throw EXCEPTION("Human obstruction index content exceeds its budget")
			var/list/contents = saved_content_refs(raw, 3)
			for(var/child in contents)
				if(++edge_work > 1000000) throw EXCEPTION("Human obstruction index edge budget exceeded")
				if(edge_work % 256 == 0)
					TICK_CHECK
					if(world.time >= deadline || !operation.current(src, owner_kind)) throw EXCEPTION("Human obstruction index exceeded its budget")
				var/ref = text2num("[child]")
				if(!isnum(ref) || ref < 1 || ref != round(ref) || "[ref]" != "[child]") throw EXCEPTION("Human obstruction index identity is invalid")
				var/list/fields = human_saved_entry_fields(F, ref)
				if(!("type" in fields)) throw EXCEPTION("Human obstruction index type is missing")
				var/path = F["type"]
				if(ispath(path, /mob)) continue
				if(!ispath(path, /obj)) throw EXCEPTION("Human obstruction index movable type is unsupported")
				if(seen["[ref]"]) throw EXCEPTION("Human obstruction index object has duplicate parents")
				seen["[ref]"] = TRUE
				var/saved_density = human_candidate_scalar_field(F, ref, "density")
				if(!isnum(saved_density)) throw EXCEPTION("Human obstruction index density is invalid")
				if(!saved_density && human_spatial_generic_object(path)) continue
				var/list/shape = list()
				for(var/key in list("density", "bound_x", "bound_y", "bound_width", "bound_height", "step_x", "step_y"))
					var/value = human_candidate_scalar_field(F, ref, key)
					if(!isnum(value) || isnan(value) || isinf(value) || value != round(value)) throw EXCEPTION("Human obstruction index field is invalid")
					shape[key] = value
				if(shape["bound_width"] < 0 || shape["bound_height"] < 0) throw EXCEPTION("Human obstruction index bounds are invalid")
				if(!shape["bound_width"] || !shape["bound_height"]) continue
				var/left = (x - 1) * 32 + shape["step_x"] + shape["bound_x"]
				var/bottom = (y - 1) * 32 + shape["step_y"] + shape["bound_y"]
				var/right = left + shape["bound_width"]
				var/top = bottom + shape["bound_height"]
				if(isnan(left) || isinf(left) || isnan(bottom) || isinf(bottom) || isnan(right) || isinf(right) || isnan(top) || isinf(top)) throw EXCEPTION("Human obstruction index bounds are not finite")
				var/min_x = max(1, floor(left / 32) + 1)
				var/max_x = min(world.maxx, floor((right - 1) / 32) + 1)
				var/min_y = max(1, floor(bottom / 32) + 1)
				var/max_y = min(world.maxy, floor((top - 1) / 32) + 1)
				if(min_x > max_x || min_y > max_y) continue
				if((max_x - min_x + 1) * (max_y - min_y + 1) > 4096) throw EXCEPTION("Human obstruction index object spans too many tiles")
				var/list/record = list("ref" = ref, "type" = path, "density" = shape["density"], "left" = left, "bottom" = bottom, "right" = right, "top" = top)
				for(var/ox = min_x, ox <= max_x, ox++)
					for(var/oy = min_y, oy <= max_y, oy++)
						if(++edge_work > 1000000) throw EXCEPTION("Human obstruction index tile budget exceeded")
						if(edge_work % 256 == 0)
							TICK_CHECK
							if(world.time >= deadline || !operation.current(src, owner_kind)) throw EXCEPTION("Human obstruction index exceeded its budget")
						var/key = "[ox]:[oy]"
						if(!targets[key]) continue
						var/list/bucket = index[key]
						if(!bucket)
							bucket = list()
							index[key] = bucket
						bucket += list(record)
	return index

/map_storage/proc/validate_human_saved_geometry(savefile/F, ref, list/position, list/obstructions, datum/persistence_world_operation/operation, owner_kind, deadline)
	if(!operation || !operation.current(src, owner_kind) || !islist(position) || position.len != 5 || !islist(obstructions)) throw EXCEPTION("Human geometry lacks its operation or position")
	for(var/key in list("x", "y", "z", "sx", "sy"))
		if(!(key in position) || !isnum(position[key]) || position[key] != round(position[key])) throw EXCEPTION("Human geometry position is invalid")
	if(position["x"] < 1 || position["x"] > world.maxx || position["y"] < 1 || position["y"] > world.maxy || position["z"] < 1 || position["z"] > save_validation_maxz() || position["sx"] < 0 || position["sx"] >= 32 || position["sy"] < 0 || position["sy"] >= 32) throw EXCEPTION("Human geometry position is outside the world")
	var/z = position["z"]
	var/list/human_fields = human_saved_entry_fields(F, ref)
	if(!("type" in human_fields) || F["type"] != /mob/living/human || !human_candidate_position_matches(F, ref, position)) throw EXCEPTION("Human saved type or position is unsupported")
	for(var/key in human_spatial_link_fields())
		var/link = human_candidate_scalar_field(F, ref, key)
		if(!isnull(link) && (!isnum(link) || link != 0)) throw EXCEPTION("Human saved physical link is unsupported")
	for(var/key in list("bound_x", "bound_y"))
		var/offset = human_candidate_scalar_field(F, ref, key)
		if(!isnum(offset) || offset != 0) throw EXCEPTION("Human saved bounds are unsupported")
	for(var/key in list("bound_width", "bound_height"))
		var/size = human_candidate_scalar_field(F, ref, key)
		if(!isnum(size) || size != 32) throw EXCEPTION("Human saved size is unsupported")
	var/left = (position["x"] - 1) * 32 + position["sx"]
	var/bottom = (position["y"] - 1) * 32 + position["sy"]
	for(var/dx = 0, dx <= !!position["sx"], dx++)
		for(var/dy = 0, dy <= !!position["sy"], dy++)
			var/x = position["x"] + dx
			var/y = position["y"] + dy
			if(x < 1 || x > world.maxx || y < 1 || y > world.maxy) throw EXCEPTION("Human saved footprint is outside the map")
			var/turf_ref = human_candidate_map_ref(F, z, y, x)
			var/list/turf_fields = human_saved_entry_fields(F, turf_ref)
			if(!("type" in turf_fields) || !ispath(F["type"], /turf/floor) || !("content" in turf_fields)) throw EXCEPTION("Human saved turf type is not audited")
			var/turf_density = human_candidate_scalar_field(F, turf_ref, "density")
			var/transforming = human_candidate_turf_transforming(F, turf_ref)
			if(!isnum(turf_density) || turf_density != 0 || (!isnull(transforming) && (!isnum(transforming) || transforming != 0))) throw EXCEPTION("Human saved turf is blocked or transforming")
			var/list/occupants = obstructions["[x]:[y]"]
			if(islist(occupants))
				for(var/list/occupant in occupants)
					if(left >= occupant["right"] || occupant["left"] >= left + 32 || bottom >= occupant["top"] || occupant["bottom"] >= bottom + 32) continue
					if(occupant["density"] || !human_spatial_generic_object(occupant["type"])) throw EXCEPTION("Human saved footprint has a hard or unaudited occupant")
			if(world.time >= deadline || !operation.current(src, owner_kind)) throw EXCEPTION("Human geometry inspection exceeded its budget")
	return TRUE

/map_storage/proc/inspect_human_saved_geometry(datum/persistence_world_operation/operation)
	if(!operation || !operation.current(src, "save")) throw EXCEPTION("Human geometry inspection lost its operation")
	var/list/files = list()
	var/list/positions_by_level = list()
	var/list/indexes = list()
	var/deadline = world.time + 1200
	for(var/datum/human_subtile_save_request/request in operation.human_spatial_requests)
		if(!request || !islist(request.position)) throw EXCEPTION("Human geometry position is missing")
		var/z_key = "[request.saved_z]"
		var/list/positions = positions_by_level[z_key]
		if(!positions)
			positions = list()
			positions_by_level[z_key] = positions
		positions += list(request.position)
	for(var/datum/human_subtile_save_request/request in operation.human_spatial_requests)
		if(world.time >= deadline || !request || !request.encoded_origin_checked || !request.encoded_present_slots_checked || !request.reciprocal_links_checked || !operation.current(src, "save")) throw EXCEPTION("Human geometry inspection lacks its prerequisites")
		var/z = request.saved_z
		var/list/position = request.position
		var/savefile/F = files["[z]"]
		if(!F)
			if(!fexists("map_saves/[z].sav")) throw EXCEPTION("Human geometry level is missing")
			F = new("map_saves/[z].sav")
			files["[z]"] = F
			indexes["[z]"] = build_human_obstruction_index(F, z, positions_by_level["[z]"], operation, "save", deadline)
		validate_human_saved_geometry(F, request.saved_ref, position, indexes["[z]"], operation, "save", deadline)
		request.encoded_geometry_checked = TRUE
		request.encoded_links_checked = TRUE
	files = list()

// The admission-time account scan predates late enrollment. Check the actual
// encoded accounts across all captured modes and levels before publication.
/map_storage/proc/inspect_human_saved_owners(datum/persistence_world_operation/operation, generation)
	if(!operation || !operation.current(src, "save") || !islist(operation.human_roster_records)) throw EXCEPTION("Human saved-owner inspection lacks its operation")
	var/list/files = list()
	var/list/owners = list()
	var/deadline = world.time + 1200
	for(var/identity in operation.human_roster_records)
		var/list/record = operation.human_roster_records[identity]
		if(!record["ref"]) continue
		var/z = record["z"]
		if(!isnum(z) || z < 1 || z > world.maxz || z != round(z)) throw EXCEPTION("Human saved-owner level is invalid")
		var/savefile/F = files["[z]"]
		if(!F)
			if(!fexists("map_saves/[z].sav")) throw EXCEPTION("Human saved-owner level is missing")
			F = new("map_saves/[z].sav")
			if(F["/generation"] != generation || F["/format_version"] != 3) throw EXCEPTION("Human saved-owner generation is invalid")
			files["[z]"] = F
		var/list/fields = human_saved_entry_fields(F, record["ref"])
		if(!("type" in fields) || !ispath(F["type"], /mob/living/human)) throw EXCEPTION("Human saved-owner entry is invalid")
		validate_saved_player_owner(F, record["ref"], owners)
		if(world.time >= deadline || !operation.current(src, "save")) throw EXCEPTION("Human saved-owner inspection exceeded its budget")
		save_work_check()
	if(world.time >= deadline || !operation.current(src, "save")) throw EXCEPTION("Human saved-owner inspection exceeded its budget")
	return TRUE

/map_storage/proc/prepare_human_save_roster(datum/persistence_world_operation/operation)
	if(!operation || !operation.current(src, "save")) throw EXCEPTION("Human roster has no save owner")
	var/list/registry = operation.human_initial_roster
	if(!operation.human_roster_sealed || !islist(registry) || registry.len > 8192) throw EXCEPTION("Human save roster is unavailable or over budget")
	human_save_roots = list()
	var/list/copy = registry.Copy()
	for(var/i = 1, i <= copy.len, i++)
		var/mob/living/human/H = copy[i]
		if(!istype(H) || isDeleted(H)) continue
		var/identity = save_entry_identity(H)
		if(human_save_roots[identity]) throw EXCEPTION("Human save roster identity is duplicated")
		var/saveable = !!H.should_save
		if(saveable)
			for(var/ignored in ignore_types)
				if(istype(H, ignored)) throw EXCEPTION("Saveable human matches an ignored type")
		human_save_roots[identity] = list("atom" = H, "identity" = identity, "saveable" = saveable, "initial" = TRUE, "z" = H.z, "origin" = null, "request" = null, "ref" = 0, "mode" = null)
		save_work_check()
	operation.human_roster_records = human_save_roots

// Legacy containment, links and non-owned offsets keep the existing serializer.
// No movement is stopped to enroll a newly discovered spatial actor.
/map_storage/proc/human_save_spatial_supported(mob/living/human/H)
	return H && !isDeleted(H) && H.type == /mob/living/human && H.should_save && H.human_subtile_shape() && H.human_subtile_unlinked() && !H.pulling && !subtile_pull_ownership.owners[H] && ((!H.step_x && !H.step_y) || H.human_subtile_offset_owned)

/map_storage/proc/classify_human_save_entry(mob/living/human/H, datum/persistence_world_operation/operation)
	if(!H || isDeleted(H) || !operation || !operation.current(src, "save") || !islist(operation.human_roster_records)) throw EXCEPTION("Human save entry lacks its operation")
	var/identity = save_entry_identity(H)
	var/list/record = human_save_roots[identity]
	if(!record)
		if(human_save_roots.len >= 8192) throw EXCEPTION("Human save membership exceeds its budget")
		record = list("atom" = H, "identity" = identity, "saveable" = !!H.should_save, "initial" = FALSE, "z" = H.z, "origin" = null, "request" = null, "ref" = 0, "mode" = null)
		human_save_roots[identity] = record
	if(record["atom"] != H || record["identity"] != identity) throw EXCEPTION("Human save entry identity changed")
	if(record["mode"]) return record
	record["saveable"] = !!H.should_save
	record["z"] = H.z
	if(!human_save_spatial_supported(H))
		if(H.human_subtile_pulse || H.human_subtile_transaction || H.step_x || H.step_y) throw EXCEPTION("Human legacy save needs an aligned idle position")
		var/atom/legacy_parent = H.loc
		if(!istype(legacy_parent) || legacy_parent.z != H.z) throw EXCEPTION("Human legacy save has no valid parent")
		record["origin"] = legacy_parent
		record["origin_identity"] = save_entry_identity(legacy_parent)
		record["mode"] = "legacy"
		return record
	var/datum/human_subtile_save_request/request = H.request_human_subtile_save_position(operation)
	if(!request) throw EXCEPTION("Human spatial enrollment failed")
	var/deadline = world.time + 100
	while(!request.captured)
		if(!operation.current(src, "save") || !H || isDeleted(H) || request.actor != H || H.human_subtile_save_request != request || world.time >= deadline) throw EXCEPTION("Human spatial enrollment did not reach a boundary")
		sleep(world.tick_lag)
	if(!request.origin || request.origin.z != record["z"]) throw EXCEPTION("Human spatial enrollment changed level")
	record["origin"] = request.origin
	record["request"] = request
	record["mode"] = "spatial"
	return record

// The saver waits, never the player. Once all currently admitted actors are
// between native pulses, take one bounded synchronous read of their spatial
// state. No hooks, movement, save_work_check or sleep occur during that read.
/map_storage/proc/capture_human_save_roster_positions(datum/persistence_world_operation/operation)
	if(!operation || !operation.current(src, "save") || !islist(operation.human_roster_records)) throw EXCEPTION("Human spatial pass lacks its save owner")
	var/deadline = world.time + 100
	while(TRUE)
		if(!operation.current(src, "save") || operation.human_roster_changed) throw EXCEPTION("Human roster changed before spatial pass")
		var/ready = TRUE
		for(var/identity in human_save_roots)
			var/list/record = human_save_roots[identity]
			if(!record["saveable"]) continue
			var/mob/living/human/H = record["atom"]
			if(!H || isDeleted(H) || !H.should_save || !human_save_spatial_supported(H)) continue
			if(save_entry_identity(H) != identity || H.z != record["z"]) throw EXCEPTION("Human spatial pass member changed")
			var/datum/human_subtile_transaction/T = H.human_subtile_transaction
			if(H.human_subtile_pulse || H.human_subtile_save_request || (T && (T.actor != H || T.cancelled || !human_subtile_same(T.expected, H.human_subtile_snapshot()))))
				ready = FALSE
				break
		if(ready) break
		if(world.time >= deadline) throw EXCEPTION("Human spatial pass did not reach a stable boundary")
		sleep(world.tick_lag)
	for(var/identity in human_save_roots)
		var/list/record = human_save_roots[identity]
		if(!record["saveable"]) continue
		var/mob/living/human/H = record["atom"]
		if(!H || isDeleted(H) || !H.should_save || !human_save_spatial_supported(H)) continue
		var/datum/human_subtile_transaction/T = H.human_subtile_transaction
		var/datum/human_subtile_save_request/request = H.request_human_subtile_save_position(operation)
		if(!request || (!request.captured && !request.acknowledge(H, T)) || !request.origin || request.origin.z != record["z"])
			throw EXCEPTION("Human spatial pass capture failed")
		record["origin"] = request.origin
		record["request"] = request
		record["mode"] = "spatial"
		var/list/position = request.position
		for(var/dx = 0, dx <= !!position["sx"], dx++)
			for(var/dy = 0, dy <= !!position["sy"], dy++)
				var/x = position["x"] + dx
				var/y = position["y"] + dy
				if(x < 1 || x > world.maxx || y < 1 || y > world.maxy) throw EXCEPTION("Human spatial footprint is outside the world")
				operation.human_spatial_footprints["[position["z"]]:[x]:[y]"] = TRUE
	return TRUE

/map_storage/proc/capture_human_save_root(savefile/F, list/record)
	var/mob/living/human/H = record["atom"]
	var/datum/persistence_world_operation/operation = persistence_active_operation
	if(!H || isDeleted(H) || save_entry_identity(H) != record["identity"] || H.z != record["z"] || H.z != saving_z || !operation || !operation.current(src, "save"))
		throw EXCEPTION("Human save root changed before capture")
	var/datum/human_subtile_save_request/request = record["request"]
	if(!request || !request.captured || request.actor != H || request.operation != operation || H.human_subtile_save_request != request || !request.origin || request.origin != record["origin"] || request.origin.z != saving_z)
		throw EXCEPTION("Human save position was not captured by the spatial pass")
	return BuildVarDirectory(F, H, 1, FALSE, request)

/map_storage/proc/drain_human_save_roster(savefile/F, datum/persistence_world_operation/operation)
	for(var/identity in human_save_roots)
		var/list/record = human_save_roots[identity]
		if(!record["saveable"]) continue
		if(record["z"] != saving_z) continue
		var/mob/living/human/H = record["atom"]
		if(!operation.current(src, "save")) throw EXCEPTION("Human save roster lost its owner")
		var/ref = record["ref"]
		if(!ref)
			// An unseen body destroyed before any encoded reference need not be
			// invented in the rolling candidate.
			if(!H || isDeleted(H) || !H.should_save)
				var/datum/human_subtile_save_request/unneeded = record["request"]
				if(unneeded && !unneeded.serialized)
					operation.human_spatial_requests -= unneeded
					unneeded.release()
					record["request"] = null
					record["mode"] = null
				continue
			if(save_entry_identity(H) != identity || H.z != saving_z) throw EXCEPTION("Human save roster changed level before drain")
			ref = BuildVarDirectory(F, H, 1)
			if(!ref) throw EXCEPTION("Human save roster entry could not be serialized")
		if(record["mode"] == "legacy")
			if(record["parent_attached"]) continue
			var/atom/parent = record["origin"]
			if(!parent || isDeleted(parent) || save_entry_identity(parent) != record["origin_identity"] || parent.z != record["z"]) throw EXCEPTION("Legacy human has no captured parent")
			var/legacy_parent_ref = saving_references[save_entry_identity(parent)]
			if(!legacy_parent_ref || saving_reference_pins[legacy_parent_ref] != parent) throw EXCEPTION("Legacy human parent was not captured")
			var/legacy_path = "[entry_path(F, legacy_parent_ref)]/content"
			var/list/legacy_chunks = F[legacy_path]
			if(!islist(legacy_chunks)) throw EXCEPTION("Legacy human parent cannot accept its saved body")
			var/legacy_key = "[ref]"
			var/legacy_owner = saving_content_owners[legacy_key]
			if(legacy_owner && legacy_owner != legacy_parent_ref) throw EXCEPTION("Legacy human has conflicting saved parents")
			if(!legacy_owner)
				legacy_chunks += list2params(list(legacy_key))
				F[legacy_path] << legacy_chunks
				saving_content_owners[legacy_key] = legacy_parent_ref
			record["parent_attached"] = TRUE
			save_work_check()
			continue
		if(record["mode"] != "spatial") throw EXCEPTION("Human save entry has no capture mode")
		var/datum/human_subtile_save_request/request = record["request"]
		var/list/position = request ? request.position : null
		if(!request || !request.serialized || request.saved_ref != ref || request.saved_z != saving_z || !islist(position))
			throw EXCEPTION("Human saved origin or entry was not captured")
		var/parent_ref = human_candidate_map_ref(F, saving_z, position["y"], position["x"])
		if(!isnum(parent_ref) || parent_ref < 1 || parent_ref != round(parent_ref)) throw EXCEPTION("Human saved origin is absent")
		var/key = "[ref]"
		var/owner = saving_content_owners[key]
		if(owner && owner != parent_ref) throw EXCEPTION("Human save root has conflicting spatial owners")
		if(!owner)
			var/path = "[entry_path(F, parent_ref)]/content"
			var/list/chunks = F[path]
			if(!islist(chunks)) throw EXCEPTION("Human saved origin has no version-3 contents")
			chunks += list2params(list(key))
			F[path] << chunks
			saving_content_owners[key] = parent_ref
		request.spatial_attached = TRUE
		save_work_check()

// Read only fields whose directory membership is proven. This checks the
// encoded anchor edge; geometry and reciprocal links are checked separately
// before the operation can seal its candidate-ownership proof.
/map_storage/proc/inspect_human_saved_origins(datum/persistence_world_operation/operation)
	if(!operation || !operation.current(src, "save")) throw EXCEPTION("Human saved-origin inspection lost its operation")
	var/list/files = list()
	for(var/datum/human_subtile_save_request/request in operation.human_spatial_requests)
		if(!request || request.operation != operation || !request.serialized || !request.spatial_attached || !request.saved_ref || !request.saved_z || !islist(request.position))
			throw EXCEPTION("Human saved-origin inspection lacks a completed entry")
		var/z = request.saved_z
		var/x = request.position["x"]
		var/y = request.position["y"]
		if(!isnum(x) || !isnum(y) || !isnum(z) || x != round(x) || y != round(y) || z != round(z) || request.position["z"] != z || x < 1 || x > world.maxx || y < 1 || y > world.maxy || z < 1 || z > world.maxz)
			throw EXCEPTION("Human saved-origin coordinates are invalid")
		var/savefile/F = files["[z]"]
		if(!F)
			if(!fexists("map_saves/[z].sav")) throw EXCEPTION("Human saved-origin level is missing")
			F = new("map_saves/[z].sav")
			F.cd = "/"
			if(!("format_version" in F.dir) || F["format_version"] != 3 || !("map" in F.dir)) throw EXCEPTION("Human saved-origin format is invalid")
			files["[z]"] = F
		F.cd = "/map"
		if(!("[z]" in F.dir)) throw EXCEPTION("Human saved-origin level is absent")
		F.cd = "/map/[z]"
		if(!("[y]" in F.dir)) throw EXCEPTION("Human saved-origin row is absent")
		F.cd = "/map/[z]/[y]"
		if(!("[x]" in F.dir)) throw EXCEPTION("Human saved-origin cell is absent")
		var/parent_ref = F["[x]"]
		if(!isnum(parent_ref) || parent_ref < 1 || parent_ref != round(parent_ref)) throw EXCEPTION("Human saved-origin reference is invalid")
		F.cd = "/"
		if(!("entries" in F.dir)) throw EXCEPTION("Human saved-origin entries are absent")
		F.cd = "/entries"
		var/shard = round((parent_ref - 1) / 512)
		if(!("[shard]" in F.dir)) throw EXCEPTION("Human saved-origin shard is absent")
		F.cd = "/entries/[shard]"
		if(!("[parent_ref]" in F.dir)) throw EXCEPTION("Human saved-origin entry is absent")
		F.cd = entry_path(F, parent_ref)
		if(!("type" in F.dir) || !("content" in F.dir) || !ispath(F["type"], /turf)) throw EXCEPTION("Human saved-origin entry is invalid")
		var/list/contents = saved_content_refs(F["content"], 3)
		if(!operation.current(src, "save")) throw EXCEPTION("Human saved-origin inspection lost ownership")
		var/matches = 0
		for(var/child in contents)
			if("[child]" == "[request.saved_ref]") matches++
		if(matches != 1) throw EXCEPTION("Human saved-origin edge is missing or duplicated")
		var/ref = request.saved_ref
		if(!isnum(ref) || ref < 1 || ref != round(ref)) throw EXCEPTION("Human saved entry reference is invalid")
		F.cd = "/entries"
		var/human_shard = round((ref - 1) / 512)
		if(!("[human_shard]" in F.dir)) throw EXCEPTION("Human saved entry shard is absent")
		F.cd = "/entries/[human_shard]"
		if(!("[ref]" in F.dir)) throw EXCEPTION("Human saved entry is absent")
		F.cd = entry_path(F, ref)
		if(!("type" in F.dir) || !ispath(F["type"], /mob/living/human)) throw EXCEPTION("Human saved entry has an invalid type")
		request.encoded_origin_checked = TRUE
	files = list()

// A partial candidate check: explicit saved slot references must name direct
// saved children with a unique saved parent. Missing fields, constructor hooks,
// reciprocal links and collision geometry need independent proofs.
/map_storage/proc/inspect_human_present_saved_slots(datum/persistence_world_operation/operation)
	if(!operation || !operation.current(src, "save")) throw EXCEPTION("Human slot inspection lost its operation")
	var/list/files = list()
	var/list/parents_by_level = list()
	var/list/targets_by_level = list()
	var/deadline = world.time + 1200
	var/edge_count = 0
	var/list/slot_names = human_spatial_slot_fields()
	var/list/physical_fields = list("buckled_mob", "buckled", "rider", "riding_mob", "pulledby", "pulling", "driver", "driver_vehicle", "ontop", "riders", "passengers", "occupants", "control_object", "using_cannon", "using_drone", "football")
	for(var/datum/human_subtile_save_request/target in operation.human_spatial_requests)
		if(!target || !target.encoded_origin_checked || !target.saved_ref) throw EXCEPTION("Human reciprocal target is unavailable")
		var/z_key = "[target.saved_z]"
		var/list/targets = targets_by_level[z_key]
		if(!targets)
			targets = list()
			targets_by_level[z_key] = targets
		targets["[target.saved_ref]"] = TRUE
	for(var/datum/human_subtile_save_request/request in operation.human_spatial_requests)
		if(world.time >= deadline || !request || !request.encoded_origin_checked || !operation.current(src, "save")) throw EXCEPTION("Human slot inspection lacks a verified origin or exceeded its budget")
		var/z_key = "[request.saved_z]"
		var/savefile/F = files[z_key]
		var/list/parents = parents_by_level[z_key]
		if(!F)
			if(!fexists("map_saves/[z_key].sav")) throw EXCEPTION("Human slot level is missing")
			F = new("map_saves/[z_key].sav")
			F.cd = "/"
			if(!("format_version" in F.dir) || F["format_version"] != 3 || !("entries" in F.dir)) throw EXCEPTION("Human slot format is invalid")
			F.cd = "/entries"
			var/list/shards = F.dir.Copy()
			if(shards.len > 4096) throw EXCEPTION("Human slot shard budget exceeded")
			parents = list()
			for(var/shard in shards)
				var/shard_number = text2num("[shard]")
				if(!isnum(shard_number) || shard_number < 0 || shard_number != round(shard_number) || "[shard_number]" != "[shard]") throw EXCEPTION("Human slot shard identity is invalid")
				F.cd = "/entries/[shard]"
				var/list/entries = F.dir.Copy()
				if(entries.len > 512) throw EXCEPTION("Human slot entry shard exceeds its bound")
				for(var/ref in entries)
					var/number = text2num("[ref]")
					if(!isnum(number) || number < 1 || number != round(number) || "[number]" != "[ref]" || round((number - 1) / 512) != shard_number) throw EXCEPTION("Human slot entry identity is invalid")
					F.cd = entry_path(F, number)
					var/list/entry_fields = F.dir.Copy()
					if(!("type" in entry_fields)) throw EXCEPTION("Human reciprocal entry type is missing")
					var/entry_type = F["type"]
					if("content" in F.dir)
						var/list/raw_contents = F["content"]
						if(!islist(raw_contents) || raw_contents.len > 256) throw EXCEPTION("Human slot parent content budget exceeded")
						var/list/children = saved_content_refs(raw_contents, 3)
						edge_count += children.len
						if(edge_count > 1000000) throw EXCEPTION("Human slot edge budget exceeded")
						for(var/child in children)
							var/key = "[child]"
							if(parents[key]) throw EXCEPTION("Human slot candidate has duplicate saved parents")
							parents[key] = "[ref]"
					if(ispath(entry_type, /atom/movable))
						var/list/fields_to_check = physical_fields
						if(ispath(entry_type, /obj/item/football)) fields_to_check = physical_fields + list("owner")
						for(var/key in fields_to_check)
							if(!(key in entry_fields)) continue
							F.cd = entry_path(F, number)
							var/datum/human_candidate_reference_budget/budget = new
							if(human_candidate_mentions(F, F[key], targets_by_level[z_key], budget)) throw EXCEPTION("Human saved reciprocal physical link is unsupported")
					if(world.time >= deadline || !operation.current(src, "save")) throw EXCEPTION("Human slot inspection lost ownership or exceeded its budget")
					save_work_check()
			files[z_key] = F
			parents_by_level[z_key] = parents
		F.cd = entry_path(F, request.saved_ref)
		var/list/fields = F.dir.Copy()
		for(var/key in slot_names)
			if(!(key in fields)) throw EXCEPTION("Human saved slot field is missing")
			F.cd = entry_path(F, request.saved_ref)
			var/list/value = F[key]
			if(!islist(value)) throw EXCEPTION("Human saved slot encoding is invalid")
			if(value["kind"] == "value" && isnull(value["value"])) continue
			if(value["kind"] != "entry" || !isnum(value["ref"]) || value["ref"] < 0 || value["ref"] != round(value["ref"]))
				throw EXCEPTION("Human saved slot reference is invalid")
			if(value["ref"] && parents["[value["ref"]]"] != "[request.saved_ref]")
				throw EXCEPTION("Human saved slot does not match direct containment")
		if(!operation.current(src, "save")) throw EXCEPTION("Human slot inspection lost ownership")
		request.encoded_present_slots_checked = TRUE
		request.reciprocal_links_checked = TRUE
	files = list()
#endif
