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
	operation.diagnostic_save_id = "save-[generation_nonce]"
	operation.diagnostic_generation = generation
	if(zone_export_state && !world_state) throw EXCEPTION("Admitted zone capture lost its metadata profile")
	var/list/round_state = capture_round_state(generation)
	if(world_state)
		round_state["version"] = 2
		round_state["world_state"] = world_state
	clear_bookkeeping()
	prepare_moving_save_roster()
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
	if(!moving_save_chunk && istype(A, /atom/movable) && moving_save_roots["\ref[A]"])
		var/list/root = moving_save_roots["\ref[A]"]
		if(root["atom"] != A) throw EXCEPTION("Moving save root identity changed")
		if(!saving_references["\ref[A]"]) return capture_moving_save_root(savefile, root)
	if(moving_save_chunk && istype(A, /atom/movable) && A != moving_save_chunk.root && !saving_references["\ref[A]"])
		throw EXCEPTION("Moving save chunk references an uncaptured external movable")
	var/identity = save_entry_identity(A)
	var/ind = saving_references[identity]
	var/ref = 0
	if(ind && saving_reference_pins[ind] == A)
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
					try
						record_save_child_failure(parent, content, child_ref)
					catch
						// Diagnostics must not replace the original refusal.
						last_save_reference_failure = null
					throw EXCEPTION("Child moved or disappeared during capture")
				add_export_content(frame, child_ref)
				save_work_check()
				require_export_frame(frame)
			for(var/mob/content in parent.contents)
				if(content.loc != parent) continue
				var/child_ref = BuildVarDirectory(savefile, content, 1, TRUE)
				require_export_frame(frame)
				if(child_ref && (!content || (content.loc != parent && !moving_save_root_edge(content, parent))))
					try
						record_save_child_failure(parent, content, child_ref)
					catch
						// Diagnostics must not replace the original refusal.
						last_save_reference_failure = null
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
