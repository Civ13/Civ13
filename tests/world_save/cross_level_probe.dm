// Tiny native fixture: actual production exporter, loader, graph and spatial
// reachability validator. Only the metadata field schema and game startup are
// adapted. Each scenario runs in a fresh process and private save directory.
var/cross_case
var/cross_checks = 0
var/cross_runtime_failed = FALSE
var/cross_mutated = FALSE
var/cross_capture_target = TRUE
var/cross_move_mode
var/obj/item/cross_target/cross_target
var/atom/cross_origin
var/atom/cross_destination
var/turf/cross_trigger
var/list/cross_observations = list()

/world
	name = "Civ13 isolated cross-level save fixture"
	maxx = 3
	maxy = 2
	maxz = 2
	fps = 10
	visibility = 0
	sleep_offline = FALSE
	turf = /turf/cross_level
	hub = ""
	hub_password = ""
/world/OpenPort(port)
	return ..("none")
/client/New()
	del(src)
/world/Error(exception/E)
	cross_runtime_failed = TRUE
	world.log << "Unexpected runtime error: [E] at [E.file]:[E.line]"

/proc/cross_check(condition, message)
	cross_checks++
	if(!condition) throw EXCEPTION(message)

/obj/item/cross_target
	var/paid_units = 731
/obj/item/cross_target/get_saved_vars()
	return list("name", "paid_units")
/obj/cross_box/get_saved_vars()
	return list("name")
/obj/cross_holder
	var/payload
/obj/cross_holder/get_saved_vars()
	return list("payload")
/turf/cross_level/get_saved_vars()
	return list("name")
/turf/cross_level/before_save_context(map_storage/exporter, datum/save_export_frame/frame)
	if(src != cross_trigger || cross_mutated) return
	if(cross_move_mode == "move")
		var/first_ref = exporter.saving_references["\ref[cross_origin]"]
		// Per-level references have already reset on entry to the second plane.
		// The old turf's own frame is independently cleared at completion.
		var/turf/old_turf = get_turf(cross_origin)
		cross_check(old_turf && !old_turf.persistence_export_frame, "movement ran before first spatial parent completed")
		if(src.z == old_turf.z)
			cross_check(first_ref && !exporter.saving_export_frames["[first_ref]"], "same-level first parent was still active")
		cross_check(cross_target.loc == cross_origin, "movement input lost its original owner")
		cross_target.loc = cross_destination
		cross_check(get_turf(cross_target) == get_turf(cross_destination), "native movement did not reach destination")
	else if(cross_move_mode == "place")
		cross_check(!cross_target.loc, "first-capture target was already spatially placed")
		cross_target.loc = cross_destination
	else if(cross_move_mode == "hide")
		cross_target.loc = null
	cross_mutated = TRUE

// Metadata adapter deliberately keeps two aliases to the same native atom.
// All encoding/binding/validation/decoding is the production graph's work.
/map_storage/cross_level
	var/list/fixture_roots
	var/list/fixture_restored
/map_storage/cross_level/capture_durable_world()
	durable_export = new
	var/list/aliases = cross_capture_target ? list(cross_target, cross_target) : list()
	return list("root" = durable_export.encode(aliases))
/map_storage/cross_level/validate_durable_world(list/state, generation)
	durable_import = new
	durable_import.validate(state["nodes"], generation)
	validate_durable_reachability(durable_import)
	fixture_roots = state
	return TRUE
/map_storage/cross_level/restore_durable_world()
	durable_import.decode()
	fixture_restored = durable_import.restored[fixture_roots["root"]]
	return TRUE

/proc/cross_try_save()
	try
		cross_check(map_storage.Save_World(), "save admission unexpectedly failed")
	catch(var/exception/save_error)
		return save_error.name
	return null

/proc/cross_assert_failed_save(reason, expected_prefix, accepted_message)
	cross_check(istext(reason) && findtext(reason, expected_prefix) == 1, reason ? "wrong rejection: [reason]" : accepted_message)
	cross_check(!fexists("map_saves/save_complete.txt"), "rejected export left a completion marker")
	cross_check(!persistence_active_operation && !persistence_save_in_progress, "rejected export retained operation admission")
	cross_check(!map_storage.durable_export && !map_storage.saving_export_stack.len && !map_storage.saving_reference_pins.len, "rejected export retained live export pins")

/proc/cross_setup_movement(nested = FALSE, same_level = FALSE)
	var/turf/first = locate(1,1,1)
	var/turf/second = same_level ? locate(2,1,1) : locate(1,1,2)
	if(nested)
		var/obj/cross_box/old_box = new(first)
		old_box.name = "first spatial owner"
		var/obj/cross_box/new_box = new(second)
		new_box.name = "later spatial owner"
		cross_origin = old_box
		cross_destination = new_box
	else
		cross_origin = first
		cross_destination = second
	cross_target = new(cross_origin)
	cross_target.name = "one durable target"
	cross_observations["initial_native_z"] = cross_target.z
	var/turf/initial_turf = get_turf(cross_target)
	cross_observations["initial_turf_z"] = initial_turf.z
	cross_trigger = second
	cross_move_mode = "move"

/proc/cross_check_movement(nested = FALSE, same_level = FALSE)
	cross_setup_movement(nested, same_level)
	var/reason = cross_try_save()
	cross_check(!reason, "movement export rejected: [reason]")
	cross_check(cross_mutated && get_turf(cross_target) == get_turf(cross_destination), "movement hook was not reached")
	var/list/state = map_storage.read_round_state()
	cross_check(state["version"] == 2, "movement changed round envelope version")
	var/list/world_state = state["world_state"]
	var/list/nodes = world_state["nodes"]
	var/list/entry
	var/entry_count = 0
	for(var/list/node in nodes)
		if(node["kind"] == "entry")
			entry = node
			entry_count++
	cross_check(entry_count == 1 && entry["z"] == 1 && entry["ref"] > 0, "metadata did not retain its first level binding")
	var/total_targets = 0
	var/total_placements = 0
	for(var/z = 1, z <= world.maxz, z++)
		var/savefile/F = new("map_saves/[z].sav")
		cross_check(F["/format_version"] == 2, "movement changed native save format version")
		F.cd = "/entries"
		var/list/shards = F.dir.Copy()
		for(var/shard in shards)
			F.cd = "/entries/[shard]"
			var/list/refs = F.dir.Copy()
			for(var/ref in refs)
				var/path = map_storage.entry_path(F, ref)
				if(F["[path]/type"] == /obj/item/cross_target) total_targets++
				F.cd = path
				// Do not create an absent optional native field while inspecting it.
				if("content" in F.dir)
					for(var/child in params2list(F["content"]))
						if(F["[map_storage.entry_path(F, child)]/type"] == /obj/item/cross_target) total_placements++
	cross_check(total_targets == 1, "movement serialized more than one target entry")
	cross_check(total_placements == 1, "movement serialized more than one spatial parent")
	cross_check(map_storage.validate_world_save(), "movement generation failed production preflight: [map_storage.last_error]")
	cross_trigger = null
	map_storage.ClearMap()
	cross_check(map_storage.Load_World(), "movement generation failed production loading")
	map_storage.restore_durable_world()
	var/map_storage/cross_level/storage = map_storage
	var/obj/item/cross_target/restored
	var/restored_count = 0
	for(var/obj/item/cross_target/I in world)
		restored = I
		restored_count++
	cross_check(restored_count == 1, "movement restored duplicate or missing targets")
	cross_check(get_turf(restored) == locate(1,1,1), "movement restored target at the later location")
	if(nested)
		cross_check(istype(restored.loc, /obj/cross_box) && restored.loc.name == "first spatial owner", "movement lost the first nested parent")
	else
		cross_check(restored.loc == locate(1,1,1), "movement added an unexpected container")
	cross_check(restored.paid_units == 731, "movement lost saved scalar state")
	cross_check(storage.fixture_restored.len == 2 && storage.fixture_restored[1] == restored && storage.fixture_restored[2] == restored, "metadata alias did not resolve to the single restored target")
	map_storage.release_durable_world()
	cross_check(!map_storage.saving_reference_pins.len && !map_storage.saving_export_stack.len, "completed movement retained export pins")

/proc/cross_check_field_reference(nested = FALSE, backward = FALSE)
	cross_capture_target = FALSE
	var/obj/cross_holder/holder
	if(backward)
		cross_setup_movement(nested)
		holder = new(locate(2,1,2))
	else
		var/atom/target_loc = locate(1,1,2)
		if(nested) target_loc = new /obj/cross_box(target_loc)
		cross_target = new(target_loc)
		holder = new(locate(1,1,1))
		cross_observations["initial_native_z"] = cross_target.z
		var/turf/initial_turf = get_turf(cross_target)
		cross_observations["initial_turf_z"] = initial_turf.z
	if(nested)
		var/list/inner = list("target" = cross_target)
		holder.payload = list("wrapper" = inner)
	else
		holder.payload = cross_target
	var/reason = cross_try_save()
	cross_assert_failed_save(reason, "Cross-level object reference cannot be represented", "foreign-level saved-variable reference was accepted")
	if(!nested && !backward)
		cross_check(findtext(reason, "saved_z=1 native_z=2 turf_z=2 source_type=/obj/cross_holder source_field=payload"), "cross-level diagnostic omitted its source field context")

/proc/cross_check_unplaced()
	cross_capture_target = FALSE
	cross_target = new(null)
	var/obj/cross_holder/holder = new(locate(1,1,1))
	holder.payload = cross_target
	cross_destination = locate(1,1,2)
	cross_trigger = locate(1,1,2)
	cross_move_mode = "place"
	var/reason = cross_try_save()
	cross_check(cross_mutated, "unplaced first-capture scenario did not reach later placement")
	cross_assert_failed_save(reason, "Cross-level object reference cannot be represented", "unplaced first capture was silently skipped or duplicated")

/proc/cross_check_missing()
	cross_target = new(locate(1,1,1))
	cross_trigger = locate(1,1,1)
	cross_move_mode = "hide"
	var/reason = cross_try_save()
	cross_assert_failed_save(reason, "Durable metadata atom is absent from the saved world", "missing durable target was accepted")

/proc/cross_check_binder()
	var/obj/item/cross_target/I = new(locate(1,1,1))
	var/datum/durable_save_graph/G = new
	var/id = G.encode(I)
	G.bind_entry(I, 1, 7)
	G.bind_entry(I, 1, 7)
	var/reason
	try
		G.bind_entry(I, 2, 7)
	catch(var/exception/duplicate_error)
		reason = duplicate_error.name
	cross_check(findtext(reason, "Durable metadata atom was exported more than once") == 1, "original graph binder accepted a true duplicate")
	cross_check(findtext(reason, "type=/obj/item/cross_target first_z=1 first_ref=7 current_z=2 current_ref=7 native_z=1 turf_z=1"), "duplicate binding diagnostic omitted safe identity context")
	var/list/node = G.nodes[id]
	cross_check(node["z"] == 1 && node["ref"] == 7, "rejected duplicate changed the original binding")
	reason = null
	try
		G.bind_entry(I, 1, 8)
	catch(var/exception/different_ref_error)
		reason = different_ref_error.name
	cross_check(findtext(reason, "Durable metadata atom was exported more than once") == 1, "original graph binder accepted a changed entry on the same level")

/proc/cross_check_pins()
	map_storage.clear_bookkeeping()
	map_storage.saving_z = 1
	var/savefile/F = new("pin-check.sav")
	F["/format_version"] << 2
	var/obj/item/cross_target/I = new(locate(1,1,1))
	var/identity = "\ref[I]"
	var/ref = map_storage.BuildVarDirectory(F, I, 1)
	cross_check(ref && map_storage.BuildVarDirectory(F, I, 1) == ref, "same atom revisit allocated a new identity")
	cross_check(map_storage.saving_reference_pins[ref] == I, "export did not retain a native identity pin")
	del(I)
	cross_check(!locate(identity) && !map_storage.saving_reference_pins[ref], "explicit native deletion did not clear pinned references")
	cross_check(!map_storage.BuildVarDirectory(F, I, 1), "deleted atom remained exportable")
	var/obj/item/cross_target/replacement = new(locate(1,1,1))
	// Exercise the collision branch deterministically; no allocator timing claim.
	map_storage.saving_references["\ref[replacement]"] = ref
	var/new_ref = map_storage.BuildVarDirectory(F, replacement, 1)
	cross_check(new_ref != ref && map_storage.saving_reference_pins[new_ref] == replacement, "replacement inherited a deleted atom's entry")
	map_storage.clear_bookkeeping()
	cross_check(!map_storage.saving_reference_pins.len && !map_storage.saving_references.len, "pin cleanup retained live state")

/world/New()
	OpenPort("none")
	..()
	sleep(1)
	cross_case = world.params["case"]
	var/result = "PASS"
	try
		cross_check(!world.port, "fixture opened a network port")
		OpenPort(0)
		cross_check(!world.port, "fixture allowed reopening a network port")
		map = new /obj/map_metadata(locate(3,2,1))
		map_storage = new /map_storage/cross_level("cross-level-fixture")
		switch(cross_case)
			if("move-direct") cross_check_movement()
			if("move-nested") cross_check_movement(TRUE)
			if("same-level") cross_check_movement(TRUE, TRUE)
			if("field-direct") cross_check_field_reference()
			if("field-nested") cross_check_field_reference(TRUE)
			if("field-backward-direct") cross_check_field_reference(FALSE, TRUE)
			if("field-backward-nested") cross_check_field_reference(TRUE, TRUE)
			if("unplaced") cross_check_unplaced()
			if("missing-target") cross_check_missing()
			if("binder") cross_check_binder()
			if("pins") cross_check_pins()
			else throw EXCEPTION("Unknown cross-level fixture scenario")
	catch(var/exception/probe_error)
		result = "FAIL: [probe_error.name]"
	text2file(json_encode(list("case" = cross_case, "done" = TRUE, "result" = result, "checks" = cross_checks, "runtime_failed" = cross_runtime_failed, "port" = world.port, "observations" = cross_observations)), "result.json")
	del(world)
	sleep(1)
