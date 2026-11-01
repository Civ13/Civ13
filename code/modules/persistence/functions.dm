//from https://github.com/Persistent-SS13/Persistent-SS13/blob/master/code/modules/world_save/Map%20Storage.dm
//7-september-2021

//////////////////////////////////
///PERSISTENCE STUFF/////////////
/////////////////////////////////

// age is the displayed epoch/date, not ordinal_age's technology tier. Only
// recognized BC epochs and canonical numeric years can be ordered here.
/obj/map_metadata/proc/apply_persistence_age_floor()
	if (!persistence)
		return
	if (age != "5000 B.C." && age != "313 B.C.")
		if (!istext(age))
			return
		var/year = text2num(age)
		if (isnull(year) || "[year]" != age || year >= 1943)
			return
	age = "1943"
	// Keep any independently advanced research tier. Mark the skipped epochs
	// complete so legacy research cannot send the displayed date backward.
	ordinal_age = max(ordinal_age, 6)
	age1_done = TRUE
	age2_done = TRUE
	age3_done = TRUE
	age4_done = TRUE
	age5_done = TRUE
	age6_done = TRUE

//needs to be defined for some atoms
/datum/proc/after_load()
	return
/datum/proc/before_save()
	return

// Geographic metres, independent of native areas, climate and z-level height.
// Author fields are read once; the effective profile owns only copied scalars.
/obj/map_metadata
	var/elevation_default_metres = 0
	var/list/elevation_regions = null
	var/tmp/datum/elevation_profile/elevation_profile_cache

/proc/elevation_metres_valid(value)
	return isnum(value) && value >= -12000 && value <= 12000

/proc/elevation_coordinate_valid(value, limit)
	return isnum(value) && value >= 1 && value <= limit && value == round(value)

// Admission is O(R^2), with R <= 256; it never visits world turfs.
/proc/build_elevation_profile(default_metres, list/source_regions, maxx, maxy, maxz)
	if(!elevation_metres_valid(default_metres) || !islist(source_regions) || source_regions.len > 256)
		throw EXCEPTION("Invalid elevation profile")
	for(var/limit in list(maxx, maxy, maxz))
		if(!elevation_coordinate_valid(limit, 32767))
			throw EXCEPTION("Invalid elevation dimensions")
	var/datum/elevation_profile/profile = new
	profile.default_metres = default_metres
	for(var/entry in source_regions)
		if(!islist(entry) || !isnull(source_regions[entry]))
			throw EXCEPTION("Invalid elevation region record")
		var/list/row = entry
		if(row.len != 6)
			throw EXCEPTION("Invalid elevation region fields")
		for(var/key in list("x1", "x2", "y1", "y2", "z", "metres"))
			if(!(key in row))
				throw EXCEPTION("Missing elevation region field")
		if(!elevation_coordinate_valid(row["x1"], maxx) || !elevation_coordinate_valid(row["x2"], maxx) || !elevation_coordinate_valid(row["y1"], maxy) || !elevation_coordinate_valid(row["y2"], maxy) || !elevation_coordinate_valid(row["z"], maxz) || !elevation_metres_valid(row["metres"]) || row["x1"] > row["x2"] || row["y1"] > row["y2"])
			throw EXCEPTION("Invalid elevation region bounds")
		for(var/list/other in profile.regions)
			if(row["z"] == other["z"] && row["x1"] <= other["x2"] && row["x2"] >= other["x1"] && row["y1"] <= other["y2"] && row["y2"] >= other["y1"])
				throw EXCEPTION("Overlapping elevation regions")
		profile.regions += list(row.Copy())
	return profile

/datum/elevation_profile
	var/default_metres = 0
	var/list/regions = list()
	should_save = FALSE

// Bounded O(R) lookup, including edges. z selects a plane, never a height.
/datum/elevation_profile/proc/at(x, y, z)
	for(var/list/row in regions)
		if(z == row["z"] && x >= row["x1"] && x <= row["x2"] && y >= row["y1"] && y <= row["y2"])
			return row["metres"]
	return default_metres

/obj/map_metadata/proc/effective_elevation_profile()
	if(!elevation_profile_cache)
		elevation_profile_cache = build_elevation_profile(elevation_default_metres, isnull(elevation_regions) ? list() : elevation_regions, world.maxx, world.maxy, world.maxz)
	return elevation_profile_cache

/proc/get_elevation(atom/location)
	var/turf/T = get_turf(location)
	if(!T || !map)
		return 0
	var/datum/elevation_profile/profile = map.effective_elevation_profile()
	return profile.at(T.x, T.y, T.z)

/obj/map_metadata/proc/elevation_snapshot()
	var/datum/elevation_profile/profile = effective_elevation_profile()
	// Revalidate against current dimensions, and detach every row from live state.
	var/datum/elevation_profile/copy = build_elevation_profile(profile.default_metres, profile.regions, world.maxx, world.maxy, world.maxz)
	return list("version" = 1, "maxx" = world.maxx, "maxy" = world.maxy, "maxz" = world.maxz, "default_metres" = copy.default_metres, "regions" = copy.regions)

/proc/elevation_profile_from_snapshot(list/snapshot, maxx, maxy, maxz)
	if(!islist(snapshot) || snapshot.len != 6)
		throw EXCEPTION("Invalid saved elevation snapshot")
	var/list/state = snapshot
	for(var/key in list("version", "maxx", "maxy", "maxz", "default_metres", "regions"))
		if(!(key in state))
			throw EXCEPTION("Missing saved elevation field")
	if(state["version"] != 1 || state["maxx"] != maxx || state["maxy"] != maxy || state["maxz"] != maxz)
		throw EXCEPTION("Saved elevation dimensions or version differ")
	return build_elevation_profile(state["default_metres"], state["regions"], maxx, maxy, maxz)

/obj/map_metadata/proc/restore_elevation_snapshot(list/round_state, maxx, maxy, maxz)
	var/datum/elevation_profile/profile
	if("elevation" in round_state)
		profile = elevation_profile_from_snapshot(round_state["elevation"], maxx, maxy, maxz)
	else
		// Legacy saves predate elevation, even if newer map defaults add it.
		profile = build_elevation_profile(0, list(), maxx, maxy, maxz)
	// Replace the effective profile only after the complete snapshot is valid.
	elevation_profile_cache = profile

// Custom persistence iterates vars, including tmp. Runtime fields require explicit exclusion.
// Omit only known process-local state, on export and historical import, without
// mutating the live value. Unknown object links still require integrity validation;
// never drop a relationship merely because it points to another z-level.
/datum/proc/persistence_runtime_var(key)
	// Weak handles cache native references from this process, never durable IDs.
	return key == "persistence_export_frame" || key == "weak_reference"

// Durable links which may point at a movable on another level. Only top-level
// fields named here use the cross-level codec; every other field keeps the
// per-level rejection. Same-level values still use ordinary entry encoding.
/datum/proc/persistence_level_link_var(key)
	return FALSE

/datum/proc/get_saved_vars()
	var/list/to_save = list()
	var/partial = FALSE

	if (!istype(src, /mob) && ((istype(src, /turf) || istype(src, /obj/structure/wild) || (!istype(src, /obj/item) && !istype(src, /obj/structure) && !istype(src, /obj/map_metadata) && !istype(src, /obj/covers)))))
		partial = TRUE
	if (istype(src, /datum) && !istype(src, /mob) && !istype(src, /obj) && !istype(src, /turf))
		partial = FALSE
	if (partial)
		to_save |= params2list(map_storage_saved_vars)
	else
		for (var/key in src.vars)
			if (persistence_runtime_var(key))
#ifdef CIV13_VARIABLE_OBSERVABILITY
				variable_observability_skipped(src.vars[key])
#endif
				continue
			if (src.vars[key] != initial(src.vars[key]) && key != "verbs" && key != "locs" && key != "group")
				to_save |= key
			to_save |= "name"
	return to_save

// The composite appearance is not a supported saved datum. Restoring its null
// envelope resets independently restored fields such as transform and color.
/atom/persistence_runtime_var(key)
	switch(key)
		if ("appearance", "light", "light_sources")
			return TRUE
	return ..()

// A throw's target belongs to the live throwing processor, not the saved world.
// Apply on import too so historical references cannot recreate a foreign owner.
// The target atom (including a roofbuilder) remains independently saveable.
/atom/movable/persistence_runtime_var(key)
	// Minimal serializer fixtures may omit carriage type declarations.
	if (key == "glide_size" && ("carriage_glide_owner" in vars) && vars["carriage_glide_owner"])
		return TRUE
	return key == "original_target" || key == "woodwork_owner" || key == "carriage_glide_owner" || key == "carriage_glide_previous" || key == "carriage_glide_applied" || key == "carriage_glide_step" || key == "throw_launch_source" || key == "throw_launch_dx" || key == "throw_launch_dy" || key == "throw_launch_x" || key == "throw_launch_y" || key == "throw_flight_token" || ..()

// Lighting graphs belong to the current map/owners and are rebuilt after import.
// The custom serializer enumerates tmp fields as well as durable fields.
/datum/light_source
	should_save = FALSE

/datum/lighting_corner
	should_save = FALSE

/atom/movable/lighting_overlay
	should_save = FALSE

/turf/persistence_runtime_var(key)
	if (key == "area_change_owner")
		return TRUE
	if (key == "snowfall_ground_index" || key == "snowfall_ground_generation" || key == "weather_snow_overlay")
		return TRUE
	if (key == "pickaxe_mining_owner" || key == "mining_in_progress")
		return TRUE
	switch(key)
		if ("lighting_reserved", "affecting_lights", "lighting_overlay", "corners", "has_opaque_atom", "window_coeff_dirty", "next_calculate_window_coeff")
			return TRUE
	return ..()

// Author policy is not restored from an ordinary or historical area payload.
/area/persistence_runtime_var(key)
	return key == "lighting_reserved_clearance_enabled" || key == "persistence_zone_id" || ..()

// HUD objects belong to a client session and are rebuilt by the normal HUD path.
// The custom saver visits tmp vars too; exclude these on both export and import.
// Click/move deadlines and in-flight action locks belong to the running process.
// LAssailant is a last-attacker pointer that can name a mob on another z-level,
// which per-level saves reject, so one stale attacker would block every save.
// Ignoring historical values during import leaves new mobs at their defaults,
// without resetting cooldowns or active actions on an existing live mob.
/mob/persistence_runtime_var(key)
	if (key == "mouth_covered")
		return TRUE
	if (key == "actions" || key == "grab_list" || key == "grabbed_by")
		return TRUE
	if (key == "pickaxe_mining_action" || key == "next_animal_retaliation" || key == "LAssailant")
		return TRUE
	switch(key)
		if ("next_click", "next_move", "may_do_after", "may_do_mob", "blackout_click_owner", "blackout_click_client_ref", "blackout_click_counts", "blackout_click_started", "blackout_click_expires", "hud_used", "HUDneed", "HUDinventory", "HUDfrippery", "HUDprocess", "HUDtech", "hands", "pullin", "purged", "i_select", "m_select", "zone_sel")
			return TRUE
	return ..()

/obj/screen
	should_save = FALSE

/datum/hud
	should_save = FALSE

// Actions and grabs are live ownership graphs, not inventory or world assets.
// Exclude whole graphs as well as mob indexes; legacy import rejects their
// types before constructors can require a client, assailant or victim.
/datum/action
	should_save = FALSE

/obj/item/weapon/grab
	should_save = FALSE

/mob/living/simple_animal/hostile/persistence_runtime_var(key)
	return key == "target" || ..()

/mob/living/simple_animal/pet/persistence_runtime_var(key)
	return key == "movement_target" || key == "flee_target" || ..()

/mob/observer/ghost/persistence_runtime_var(key)
	return key == "following" || ..()

// Dirt uses the turf allowlist rather than the object changed-vars encoder.
// Preserve finite fertility across exports without serializing recovery tokens.
/turf/floor/dirt/get_saved_vars()
	. = ..()
	. |= "soil_nutrition"

var/map_storage/map_storage = new("SS13")

/proc/string_explode(var/string, var/separator = "")
	//writepanic("[__FILE__].[__LINE__] \\/proc/string_explode() called tick#: [world.time]")
	if(istext(string) && (istext(separator) || isnull(separator)))
		return splittext(string, separator)
        
/proc/start_watch()
	return TimeOfGame

/proc/stop_watch(wh)
	return round(0.1 * (TimeOfGame - wh), 0.1)

/proc/log_startup_progress(var/message)
	to_chat(world, "<span class='danger'>[message]</span>")

//Key thing that stops lag. Cornerstone of performance in ss13, Just sitting here, in unsorted.dm.
/proc/stoplag()
	. = 1
	sleep(world.tick_lag)
	if(world.tick_usage > TICK_LIMIT_TO_RUN) //woke up, still not enough tick, sleep for more.
		. += 2
		sleep(world.tick_lag*2)
		if(world.tick_usage > TICK_LIMIT_TO_RUN) //woke up, STILL not enough tick, sleep for more.
			. += 4
			sleep(world.tick_lag*4)
			//you might be thinking of adding more steps to this, or making it use a loop and a counter var
			//	not worth it.

/*************************************************************************
ATOM ADDITIONS
**************************************************************************/
datum
	var
		load_contents = 0
		should_save = 1
		map_storage_saved_vars = ""
		safe_list_vars = ""
atom
	map_storage_saved_vars = "density;icon_state;dir;name;pixel_x;pixel_y;id"
	load_contents = 1
/*************************************************************************
MAP STORAGE DATUM
**************************************************************************/
map_storage

	var
		// These are atom types for the map saver to ignore. Objects of these type will
		// not be saved with everything else.
		list/ignore_types = list(/mob/new_player, /atom/movable/lighting_overlay, /atom/movable/lighting_fullbright)

		// This text string is tacked onto all saved passwords so that their md5 values
		// will be different than what the password's hash would normally be, providing
		// a bit of extra protection against md5 hash directories.
		game_id = "SS13"

		// INTERNAL VARIABLES - SHOULD NOT BE ALTERED BY USERS

		// List of object types. This will be converted to params and encrypted when saved.
		list/object_reference = list()
		list/obj_references = list()
		list/existing_references = list()
		list/saving_references = list()
		list/saving_export_frames = list()
		list/saving_export_stack = list()
		list/saving_content_owners = list()
		list/saving_world_movables = list()
		// Cross-level links: export rows pin their target until it is bound to
		// its own level entry. Import rows come from the validated round state.
		list/saving_level_links = list()
		list/saving_level_link_ids = list()
		list/validated_level_links
		list/loading_level_links
		list/loading_level_link_targets = list()
		list/loading_level_link_fields = list()
		var/saving_work = 0
		var/saving_slice_start = 0
		list/all_loaded = list()
		list/found_types = list()
		list/saved_turfs = list()
		list/saving_lists = list()
		list/saving_reference_pins = list()
		list/saving_list_pins = list()
		list/loaded_lists = list()
		var/saving_z = 0
		var/last_error = null
		// Admin VV diagnostic snapshots only. Never retain live objects here.
		var/list/last_save_reference_failure
		var/consecutive_save_failures = 0
		var/round_restored = FALSE
		var/per_pause = 200
		var/so_far = 0
	New(game_id, backdoor, ignore)
		..()
		if(game_id)
			src.game_id = game_id
		if(ignore)
			src.ignore_types = ignore
		return

/map_storage/persistence_runtime_var(key)
	if(key in list("moving_save_roots", "moving_save_chunk")) return TRUE
#ifdef CIV13_HUMAN_SPATIAL_EXPERIMENTAL
	if(key == "human_save_roots") return TRUE
#endif
	if(key == "consecutive_save_failures") return TRUE
	if(key in list("saving_level_links", "saving_level_link_ids", "validated_level_links", "loading_level_links", "loading_level_link_targets", "loading_level_link_fields")) return TRUE
	if(key in list("validated_roof_areas", "validated_roof_entries", "validated_roof_types", "validated_roof_instances", "validated_roof_absent", "restoring_roof_areas")) return TRUE
	if(key in list("validated_zone_state", "validated_zones", "validated_zone_grid", "restored_zones", "zone_export_state", "zone_export_zones", "zone_export_pins", "zone_export_anchors", "zone_id_reservations", "zone_high_water", "zone_namespace", "zone_next_counter", "zone_export_generation", "zone_export_maxz", "zone_candidate_validation")) return TRUE
	if(key in list("last_save_reference_failure", "restore_policy", "restore_cleanup_error")) return TRUE
#ifdef CIV13_VARIABLE_OBSERVABILITY
	if(key in list("last_variable_failure", "last_variable_operation")) return TRUE
#endif
	return ..()

// Native lookup references are process-local hints, not durable IDs. Operators
// must compare type/location before acting: deletion can later recycle a ref.
/map_storage/proc/reference_failure_snapshot(datum/value)
	var/list/snapshot = list("type" = value ? "[value.type]" : "none", "lookup_ref" = value ? "\ref[value]" : null, "native_x" = 0, "native_y" = 0, "native_z" = 0, "turf_x" = 0, "turf_y" = 0, "turf_z" = 0)
	if(istype(value, /atom))
		var/atom/A = value
		snapshot["native_x"] = A.x
		snapshot["native_y"] = A.y
		snapshot["native_z"] = A.z
		// A malformed containment cycle must not hang failure reporting.
		var/turf/T
		var/atom/location = A
		for(var/i = 1 to 8)
			if(!location) break
			if(isturf(location))
				T = location
				break
			location = location.loc
		if(T)
			snapshot["turf_x"] = T.x
			snapshot["turf_y"] = T.y
			snapshot["turf_z"] = T.z
	return snapshot

// Capture only bounded schema context, never values, names or client data. Keep
// this record through failed-operation cleanup so one admin VV field is enough.
/map_storage/proc/record_save_reference_failure(kind, datum/target, current_entry = 0, first_z = 0, first_entry = 0)
	var/list/chain = list()
	for(var/i = max(1, saving_export_stack.len - 7), i <= saving_export_stack.len, i++)
		var/datum/save_export_frame/frame = saving_export_stack[i]
		var/valid_frame = istype(frame, /datum/save_export_frame)
		var/list/frame_snapshot = reference_failure_snapshot(valid_frame ? frame.source : null)
		frame_snapshot["field"] = valid_frame ? (istext(frame.current_field) ? copytext(frame.current_field, 1, 81) : "contents") : "unavailable"
		frame_snapshot["entry"] = valid_frame ? frame.entry : 0
		chain += list(frame_snapshot)
	last_save_reference_failure = list("schema_version" = 1, "kind" = kind, "captured_at" = time2text(world.realtime, "YYYY-MM-DD hh:mm:ss"), "captured_realtime" = world.realtime, "captured_world_time" = world.time, "saved_z" = saving_z, "current_entry" = current_entry, "first_z" = first_z, "first_entry" = first_entry, "source" = chain.len ? chain[chain.len] : reference_failure_snapshot(null), "target" = reference_failure_snapshot(target), "owner_chain" = chain, "owner_chain_truncated" = saving_export_stack.len > 8)
#ifdef CIV13_VARIABLE_OBSERVABILITY
	// Diagnostics cannot replace the serializer's original rejection.
	try
		variable_observability_capture(target)
	catch
		last_variable_failure = list("schema" = 1, "partial" = TRUE, "error" = "capture_failed")
#endif

// Drops the save/load bookkeeping references so qdel'd atoms can be garbage
// collected - these lists otherwise pin every atom they touched until the next
// save/load runs. Called after a save or load finishes, successfully or not.
/map_storage/proc/clear_bookkeeping()
	moving_save_roots = list()
	moving_save_chunk = null
#ifdef CIV13_HUMAN_SPATIAL_EXPERIMENTAL
	human_save_roots = list()
#endif
	for(var/datum/save_export_frame/frame in saving_export_stack.Copy())
		release_export_frame(frame)
	saving_export_frames = list()
	saving_export_stack = list()
	saving_content_owners = list()
	saving_world_movables = list()
	saving_level_links = list()
	saving_level_link_ids = list()
	loading_level_links = null
	loading_level_link_targets = list()
	loading_level_link_fields = list()
	saving_work = 0
	saving_slice_start = world.tick_usage
	saving_references = list()
	existing_references = list()
	found_types = list()
	all_loaded = list()
	saving_lists = list()
	saving_reference_pins = list()
	saving_list_pins = list()
	loaded_lists = list()
	saved_turfs = list()

// Returns true if the value is purely numeric, return false if there are non-numeric
// characters contained within the text string.
/map_storage/proc/IsNumeric(text)
	if(isnum(text))
		return 1
	for(var/n in 1 to length(text))
		var/ascii = text2ascii(text, n)
		if(ascii < 45 || ascii > 57)
			return 0
		if(ascii == 47)
			return 0
	return 1

// If the value is numeric, convert it to a number and return the number value. If
// the value is text, then return it as it is.
/map_storage/proc/Numeric(text)
	if(islist(text))
		return text
	if(IsNumeric(text))
		return text2num(text)
	else
		if(findtext(text, "e+"))
			var/list/nums = string_explode(text, "e+")
			if(nums.len > 1 && nums.len < 3)
				var/integer = text2num(nums[1])
				var/exp = text2num(nums[2])
				if(IsNumeric(integer) && IsNumeric(exp))
					return integer*10**exp
		return text

	// This is called when loading a map after all the verification and
	// password stuff is completed so that the map can have a fresh template
	// to work with.
/map_storage/proc/ClearMap()
	sleep(1)
	world.log << "Clearing mobs..."
	for (var/mob/mob in world)
		// Lighting's runtime view singleton must outlive map contents.
		if (!istype(mob, /mob/new_player) && mob != dview_mob)
			qdel(mob)
	sleep(1)
	world.log << "Clearing objects..."
	for (var/obj/object in world)
		if(istype(object, /obj/map_metadata) || istype(object, /atom/movable/lighting_overlay) || istype(object, /atom/movable/lighting_fullbright))
			continue
		qdel(object)
	return

/datum/data/record
	var/name = "record"
	var/size = 5.0
	var/list/fields = list(  )
	map_storage_saved_vars = "fields"
	safe_list_vars = "fields"
//////////////////////////////////////////
//////////////////GAMETICKER/////////////
//////////////////////////////////////////

var/global/persistence_save_in_progress = FALSE
var/global/datum/persistence_world_operation/persistence_active_operation
var/global/persistence_load_recovery_required = FALSE
// Observational startup state; it never authorizes or releases recovery.
var/global/persistence_startup_recovery_status
// Runtime-only identity changes on each accepted save or load, even when the
// operation completes before a waiting gameplay action wakes.
var/global/datum/persistence_admission_identity

/proc/persistence_save_active()
	return persistence_active_operation && persistence_active_operation.kind == "save"

// Sleep transfers are forbidden even on the same z during owned preparation,
// serialization and cleanup. Retain the legacy load/recovery admission hold.
/proc/persistence_sleep_transfer_blocked()
	return persistence_save_in_progress || persistence_save_active()

// One admission point for verbs, automatic saves, lifecycle recovery and direct
// lower-level calls. The identity, not the legacy busy flag, owns release.
// Future custody-changing transfers must share this exclusion and durable-state
// reconciliation. This local patch still admits save/load only.
/proc/begin_persistence_operation(map_storage/storage, kind, datum/persistence_restart_transaction/transaction)
	if(!storage || !(kind in list("save", "load")) || persistence_active_operation || persistence_load_recovery_required || storage.dimension_recovery_required || storage.dimension_budget_hold || world_z_budget.active)
		return null
	if(transaction && transaction != persistence_restart) return null
	var/restart_owner = transaction == persistence_restart && transaction
	if(kind == "save" && persistence_restart.startup_hold) return null
	if(persistence_save_in_progress && !(restart_owner && persistence_restart.startup_hold)) return null
	if((persistence_restart.startup_hold || persistence_restart.busy || persistence_restart.exists()) && !restart_owner) return null
	var/datum/persistence_world_operation/operation = new
	operation.storage = storage
	operation.kind = kind
#ifdef CIV13_HUMAN_SPATIAL_EXPERIMENTAL
	// Save motion can be admitted during maintenance only by this operation's
	// already-authorized restart owner, not merely by observing a busy flag.
	if(kind == "save") operation.restart_transaction = transaction
#endif
#ifdef CIV13_VARIABLE_OBSERVABILITY
	operation.observability_id = "operation-[++variable_observability_operation_sequence]"
	operation.observability_started = world.time
	operation.observability_collecting = variable_observability_enabled()
#endif
	persistence_active_operation = operation
	persistence_save_in_progress = TRUE
	persistence_admission_identity = operation.admission_identity
	// Reserve admission before settling quiet held pull pairs, so their
	// movement callbacks cannot begin or overlap another operation. A coupled
	// native intent, interrupted pair or orphaned partial survivor still holds
	// positions; the unstarted reservation is then withdrawn.
	try
#ifdef CIV13_HUMAN_SPATIAL_EXPERIMENTAL
		if(kind == "save")
			var/list/humans = global.vars["human_mob_list"]
			if(!islist(humans) || humans.len > 8192)
				operation.withdraw()
				return null
			// Seal before the single bounded copy, before any save-work yield.
			operation.human_roster_sealed = TRUE
			operation.human_initial_roster = humans.Copy()
#endif
#ifdef CIV13_SUBTILE_PULL_PAIRS
		if(kind == "save" && (!subtile_pull_ownership.resolve_quiet("save_admission", operation) || !operation.current(storage, kind) || !subtile_pull_ownership.save_ready()))
			operation.withdraw()
			to_chat(world, SPAN_WARNING("Map save held: a smooth pull requires an aligned checkpoint."))
			return null
#endif
		if(kind == "save")
			to_chat(world, "<FONT color='yellow'><B>SAVING THE MAP. Do not move between z-levels until saving finishes. Normal gameplay level transfers and protected sleep teleports are blocked; admins should avoid cross-z movement.</B></FONT>")
	catch(var/exception/admission_error)
		operation.withdraw()
		throw admission_error
	return operation

/datum/persistence_world_operation
	should_save = FALSE
	var/datum/admission_identity
	var/map_storage/storage
	var/kind
	var/backend_started = FALSE
	var/contents_started = FALSE
	var/mutation_started = FALSE
	var/restoring_players = FALSE
	// Observational only; never used for admission or recovery decisions.
	var/diagnostic_phase = "admitted"
	var/datum/persistence_restore_policy/restore_policy
	var/datum/persistence_restore_attempt/restore_attempt
	var/restore_reserved = FALSE
	var/datum/persistence_restart_transaction/restart_transaction
#ifdef CIV13_HUMAN_SPATIAL_EXPERIMENTAL
	var/human_roster_sealed = FALSE
	var/human_roster_changed = FALSE
	var/list/human_initial_roster
	var/list/human_roster_records
	var/list/human_spatial_footprints = list()
	// Counts additional requested fields and sidecar records; not byte or time measurements.
	var/human_geometry_turf_records = 0
	var/human_geometry_object_records = 0
	var/human_geometry_added_fields = 0
	// Proof concerns saved candidate ownership, not transient live history.
	var/human_containment_coverage_complete = FALSE
	// Only successful load preflight can bind direct capsules to a generation.
	var/human_direct_preflight_generation
	var/list/human_direct_preflight_records = list()
	var/list/human_direct_restores = list()
#endif
#ifdef CIV13_HUMAN_SUBTILE_CAPTURE_SOURCE
	var/list/human_spatial_requests = list()
	proc/track_human_spatial_request(datum/human_subtile_save_request/request)
		if(!current(storage, "save") || !request || request.operation != src || human_spatial_requests.len >= 8192) return FALSE
		human_spatial_requests += request
		return TRUE
	proc/release_human_spatial_requests()
		var/list/owned = human_spatial_requests
		human_spatial_requests = list()
#ifdef CIV13_HUMAN_SPATIAL_EXPERIMENTAL
		human_initial_roster = null
		human_roster_records = null
		human_spatial_footprints = list()
#endif
		for(var/datum/human_subtile_save_request/request in owned)
			if(request && request.operation == src)
				try
					request.release()
				catch(var/exception/release_error)
					world.log << "Human save request cleanup failed: [release_error]"
#ifdef CIV13_HUMAN_SPATIAL_EXPERIMENTAL
	// Run after all restore callbacks, under the same operation. No yield is
	// allowed between checking the restored static geometry and releasing it.
	proc/validate_human_direct_restores()
		if(!current(storage, "load") || !human_direct_preflight_generation || human_direct_restores.len > 8192) throw EXCEPTION("Human final geometry lacks its load owner")
		var/datum/human_restore_geometry_budget/budget = new
		for(var/list/record in human_direct_restores)
			var/mob/living/human/H = record["actor"]
			var/list/position = record["position"]
			if(!H || isDeleted(H) || !islist(position) || !H.human_subtile_restore_hard_clear(position, budget)) throw EXCEPTION("Human final restored geometry is blocked")
		return TRUE

	// The proof concerns completed candidate entries, not later live state.
	proc/seal_human_containment_proof()
		human_containment_coverage_complete = FALSE
		if(!current(storage, "save") || human_roster_changed || !islist(human_roster_records)) throw EXCEPTION("Human roster proof has no stable owner")
		var/list/owned = list()
		for(var/datum/human_subtile_save_request/request in human_spatial_requests)
			if(!request || request.operation != src || !request.serialized || !request.spatial_attached || !request.encoded_origin_checked || !request.encoded_present_slots_checked || !request.reciprocal_links_checked || !request.encoded_geometry_checked || !request.encoded_links_checked)
				throw EXCEPTION("Human roster proof lacks an encoded check")
			var/key = "\ref[request]"
			if(owned[key]) throw EXCEPTION("Human roster request is duplicated")
			owned[key] = request
		var/matched = 0
		for(var/identity in human_roster_records)
			var/list/record = human_roster_records[identity]
			var/mob/living/human/H = record["atom"]
			if(!record["mode"])
				if(record["initial"] && H && !isDeleted(H) && H.should_save) throw EXCEPTION("Initial human was not represented in the candidate")
			else if(record["mode"] == "legacy")
				if(!record["ref"] || !record["parent_attached"]) throw EXCEPTION("Legacy human candidate lacks a saved parent")
			else if(record["mode"] == "spatial")
				var/datum/human_subtile_save_request/request = record["request"]
				if(!request || owned["\ref[request]"] != request || request.saved_ref != record["ref"] || !record["ref"]) throw EXCEPTION("Human spatial candidate lacks its request")
				matched++
			else
				throw EXCEPTION("Human roster has an unknown capture mode")
			storage.save_work_check()
		if(matched != human_spatial_requests.len || human_roster_changed || !current(storage, "save")) throw EXCEPTION("Human roster proof changed before completion")
		human_containment_coverage_complete = TRUE
		return TRUE
#endif
	proc/validate_human_spatial_candidates()
		if(!current(storage, "save")) throw EXCEPTION("Human spatial validation lost its save operation")
#ifdef CIV13_HUMAN_SPATIAL_EXPERIMENTAL
		if(human_roster_changed) throw EXCEPTION("Human roster changed during capture")
		if(!islist(human_roster_records)) throw EXCEPTION("Human roster coverage is unavailable")
		if(!human_containment_coverage_complete) throw EXCEPTION("Human roster capture or containment proof is incomplete")
#endif
		for(var/datum/human_subtile_save_request/request in human_spatial_requests)
			if(!request || request.operation != src || !request.captured || !islist(request.position) || !human_subtile_same(request.position, request.position))
				throw EXCEPTION("Human spatial request was not captured")
			if(!request.serialized || !request.spatial_attached || !request.encoded_origin_checked || !request.encoded_present_slots_checked || !request.reciprocal_links_checked || !request.encoded_geometry_checked || !request.encoded_links_checked)
				throw EXCEPTION("Human spatial candidate validation is incomplete")
		return TRUE
#endif
	proc/authorize_restore_mutation(map_storage/expected_storage)
		var/datum/persistence_restore_policy/expected_policy = restore_policy
		var/datum/persistence_restore_attempt/expected_attempt = restore_attempt
		if(!current(expected_storage, "load") || map_storage != expected_storage || restore_policy != expected_policy || restore_attempt != expected_attempt || expected_storage.restore_policy != expected_policy || (restore_attempt && (restore_attempt.storage != storage || restore_attempt.policy != restore_policy)))
			throw EXCEPTION("Restore attempt binding changed before mutation")
		if(restore_attempt && !restore_reserved)
			if(restore_attempt.before_mutation() != TRUE)
				throw EXCEPTION("Restore recovery reservation unavailable")
			restore_reserved = TRUE
		// Reservation callbacks can yield or replace the owner: recheck afterward.
		if(!current(expected_storage, "load") || map_storage != expected_storage || restore_policy != expected_policy || restore_attempt != expected_attempt || expected_storage.restore_policy != expected_policy || (restore_attempt && (restore_attempt.storage != storage || restore_attempt.policy != restore_policy)))
			throw EXCEPTION("Restore attempt binding changed before mutation")
		return TRUE
	proc/current(map_storage/expected_storage, expected_kind)
		return persistence_active_operation == src && storage == expected_storage && kind == expected_kind
	proc/enter_backend(map_storage/expected_storage, expected_kind)
		if(!current(expected_storage, expected_kind) || backend_started) return FALSE
		backend_started = TRUE
		if(kind == "load") mutation_started = TRUE
		return TRUE
	proc/enter_contents(map_storage/expected_storage, expected_kind)
		if(!current(expected_storage, expected_kind) || !backend_started || contents_started) return FALSE
		contents_started = TRUE
		return TRUE
	// Release an admission that never entered the backend.
	proc/withdraw()
		if(persistence_active_operation != src || backend_started) return FALSE
#ifdef CIV13_HUMAN_SUBTILE_CAPTURE_SOURCE
		release_human_spatial_requests()
#endif
		persistence_active_operation = null
		persistence_save_in_progress = persistence_load_recovery_required || storage.dimension_recovery_required || storage.dimension_budget_hold || persistence_restart.startup_hold
		return TRUE
	proc/finish(success)
		if(persistence_active_operation != src) return FALSE
#ifdef CIV13_HUMAN_SUBTILE_CAPTURE_SOURCE
		release_human_spatial_requests()
#endif
#ifdef CIV13_VARIABLE_OBSERVABILITY
		try
			storage.variable_observability_finish(src, success)
		catch
			// Observability must never strand operation ownership.
			storage.last_variable_operation = null
#endif
		if(!success && kind == "load" && mutation_started)
			persistence_load_recovery_required = TRUE
		persistence_active_operation = null
		persistence_save_in_progress = persistence_load_recovery_required || storage.dimension_recovery_required || storage.dimension_budget_hold || persistence_restart.startup_hold
		return TRUE

/datum/persistence_world_operation/New()
	..()
	admission_identity = new /datum

// Direct calls acquire their own operation. A wrapper explicitly passes its
// existing identity; a second backend entry is rejected even with that identity.
/map_storage/proc/run_world_operation(kind, datum/persistence_world_operation/operation)
	var/owns_operation = !operation
	if(owns_operation) operation = begin_persistence_operation(src, kind)
	if(!operation) return FALSE
#ifdef CIV13_HUMAN_SPATIAL_EXPERIMENTAL
	// Direct imports must establish the same source proof before mutation as the
	// ticker wrapper. Historical formats remain subject to existing validation.
	if(owns_operation && kind == "load")
		try
			if(!prepare_saved_dimensions(null, operation) || !validate_world_save())
				cleanup_world_operation()
				operation.withdraw()
				return FALSE
		catch(var/exception/direct_preflight_error)
			cleanup_world_operation()
			operation.withdraw()
			throw direct_preflight_error
#endif
	if(!operation.enter_backend(src, kind)) return FALSE
	// A busy/rejected request must not erase the active save's failure context.
	if(kind == "save") last_save_reference_failure = null
#ifdef CIV13_VARIABLE_OBSERVABILITY
	if(kind == "save") last_variable_failure = null
#endif
	var/success = FALSE
	try
		if(kind == "save") success = save_world_contents(operation)
		else success = load_world_contents(operation)
#ifdef CIV13_HUMAN_SPATIAL_EXPERIMENTAL
		if(owns_operation && kind == "load" && success && operation.human_direct_restores.len) operation.validate_human_direct_restores()
#endif
	catch(var/exception/e)
		if(kind == "save") record_save_outcome(FALSE)
		if(owns_operation)
			cleanup_world_operation()
			operation.finish(FALSE)
		throw e
	if(kind == "save") record_save_outcome(success)
	if(owns_operation)
		if(!success) cleanup_world_operation()
		operation.finish(success)
	return success

// Count only admitted backend attempts, including direct Save_World calls.
// Keep notifications bounded and use the existing log/admin destinations.
/map_storage/proc/save_failure_alert_due(success)
	if(success)
		src.consecutive_save_failures = 0
		return FALSE
	src.consecutive_save_failures++
	return src.consecutive_save_failures == 3 || src.consecutive_save_failures % 10 == 0

/map_storage/proc/record_save_outcome(success)
	if(!save_failure_alert_due(success)) return
	try
		var/context = "no reference diagnostic"
		var/list/failure = last_save_reference_failure
		if(islist(failure))
			var/list/source = failure["source"]
			var/list/target = failure["target"]
			if(islist(source) && islist(target))
				context = "kind=[failure["kind"]] source=[source["type"]] field=[source["field"]] target=[target["type"]] saved_z=[failure["saved_z"]] target_z=[target["native_z"]]"
		var/message = "World save has failed [consecutive_save_failures] consecutive times: [context]. Inspect map_storage.last_save_reference_failure."
		world.log << message
		message_admins(message)
	catch
		// An unavailable notification sink must not strand save admission or
		// replace the original export exception. No lookup refs are published.
		world.log << "World-save failure alert could not be delivered."

// Cleanup can dispatch subtype code. Keep admission until every attempted
// cleanup finishes, and contain cleanup exceptions so release still occurs.
/map_storage/proc/cleanup_world_operation()
	clear_saved_zones()
	clear_zone_export()
	clear_saved_roof_areas()
	try
		clear_bookkeeping()
	catch(var/exception/e)
		restore_cleanup_error = "[restore_cleanup_error]; [e]"
		world.log << "World-save bookkeeping cleanup failed: [e]"
	try
		release_durable_world()
	catch(var/exception/durable_error)
		world.log << "World-save durable cleanup failed: [durable_error]"

/map_storage
	var/compiled_maxz = 0
	var/validation_maxz = 0
	var/dimension_bootstrap_busy = FALSE
	var/dimension_recovery_required = FALSE
	var/dimension_budget_hold = FALSE
	var/datum/new_z_reservation/dimension_reservation

/map_storage/proc/record_compiled_dimensions()
	if(!compiled_maxz) compiled_maxz = building_base_maxz()
	world_z_budget.record_compiled_dimensions()

/map_storage/proc/save_validation_maxz()
	return validation_maxz ? validation_maxz : world.maxz

/map_storage/proc/save_validation_coordinate(x, y, z)
	return isnum(x) && isnum(y) && isnum(z) && x == round(x) && y == round(y) && z == round(z) && x >= 1 && x <= world.maxx && y >= 1 && y <= world.maxy && z >= 1 && z <= save_validation_maxz()

/map_storage/proc/save_validation_area_type(x, y, z)
	if(!save_validation_coordinate(x, y, z)) return null
	if(validated_zone_state)
		var/list/zone = validated_zones[saved_zone_id(x, y, z)]
		return text2path(zone["type"])
	var/list/roof = validated_roof_areas["[x],[y],[z]"]
	if(roof && roof["area"]) return roof["area"]
	if(z > world.maxz) return world.area
	var/turf/T = locate(x, y, z)
	return T ? T.loc.type : null

/map_storage/proc/save_validation_area_key(x, y, z)
	if(!save_validation_coordinate(x, y, z)) return null
	if(validated_zone_state) return "zone:[saved_zone_id(x, y, z)]"
	var/area_type = save_validation_area_type(x, y, z)
	if(validated_roof_types["[area_type]"]) return "roof:[area_type]"
	if(z <= world.maxz)
		var/turf/T = locate(x, y, z)
		return T ? "\ref[T.loc]" : null
	var/area/A = locate(world.area)
	return A ? "\ref[A]" : "prospective:[world.area]"

/datum/controller/gameticker/proc/savemap(datum/persistence_restart_transaction/transaction)
	// A lobby/setting-up world has no round to persist; restored rounds are PLAYING.
	if(current_state < GAME_STATE_PLAYING)
		return FALSE
	var/datum/persistence_world_operation/operation = begin_persistence_operation(map_storage, "save", transaction)
	if(!operation) return FALSE
	try
		var/watch = start_watch()
		sleep(5)
		if(!map_storage.run_world_operation("save", operation))
			throw EXCEPTION("Save_World did not complete")
		log_startup_progress("	Saved the map in [stop_watch(watch)]s.")
	catch(var/exception/e)
		map_storage.cleanup_world_operation()
		map_storage.last_error = "[e] on [e.file]:[e.line]"
		operation.finish(FALSE)
		world.log << "World-save export failed: [map_storage.last_error]"
		message_admins("EXCEPTION IN MAP SAVING!! [e] on [e.file]:[e.line]")
		return 0
	operation.finish(TRUE)
	last_persistence_save_time = world.time
	return 1

/map_storage
	var/tmp/datum/persistence_restore_policy/restore_policy
	var/tmp/restore_cleanup_error

// Wrapper custody only. No production provider or full restore proof exists.
/datum/persistence_restore_policy
	should_save = FALSE
	// A provider owns cleanup until it returns an attempt bound to both arguments.
	proc/begin_attempt(map_storage/storage)
		return null

/datum/persistence_restore_attempt
	should_save = FALSE
	var/map_storage/storage
	var/datum/persistence_restore_policy/policy
	proc/before_mutation()
		return FALSE
	proc/fail(phase, original_failure, mutation_started)
		return null
	proc/release_transients()
		// This never authorizes releasing recovery custody or publishing success.
		return FALSE
	persistence_runtime_var(key)
		return (key in list("storage", "policy")) || ..()

/datum/persistence_restore_failure
	should_save = FALSE
	var/datum/persistence_restore_attempt/attempt
	var/recovery_retained = FALSE
	persistence_runtime_var(key)
		return key == "attempt" || ..()

// Admission and restart ownership enclose optional extraction recovery custody.
/datum/controller/gameticker/proc/loadmap(datum/persistence_restart_transaction/transaction, list/expected_intent)
	var/map_storage/storage = map_storage
	var/datum/persistence_world_operation/operation = begin_persistence_operation(storage, "load", transaction)
	if(!operation) return FALSE
	operation.restart_transaction = transaction
	var/datum/persistence_restore_policy/policy = storage.restore_policy
	operation.restore_policy = policy
	var/datum/persistence_restore_attempt/attempt
	var/attempt_owned = FALSE
	var/release_attempted = FALSE
	var/phase = "preflight"
	operation.diagnostic_phase = "preflight"
	storage.restore_cleanup_error = null
	try
		if(policy)
			attempt = policy.begin_attempt(storage)
			if(!istype(attempt) || attempt.storage != storage || attempt.policy != policy)
				throw EXCEPTION("Restore provider unavailable or returned an unowned attempt")
			attempt_owned = TRUE
			operation.restore_attempt = attempt
		if(operation.restore_policy != policy || storage.restore_policy != policy || !operation.current(storage, "load"))
			throw EXCEPTION("Restore attempt binding changed before preflight")
		if(!storage.prepare_saved_dimensions(expected_intent, operation) || !storage.validate_world_save())
			throw EXCEPTION(storage.last_error ? storage.last_error : "World-save preflight rejected")
		if(expected_intent && (!transaction || !transaction.matches(expected_intent, transaction.current_identity())))
			throw EXCEPTION("Restart intent does not match the completed generation")
		var/watch = start_watch()
		log_startup_progress("Starting map load...")
		var/list/saved_round = storage.read_round_state()
		if(transaction && saved_round["generation"] != transaction.expected_generation)
			throw EXCEPTION("Restart generation changed before import")
		storage.require_durable_world_idle()
		operation.authorize_restore_mutation(storage)
		phase = "clear"
		operation.diagnostic_phase = "restore"
		operation.mutation_started = TRUE
		if(transaction) transaction.import_started = TRUE
		// Validated geography must be authoritative before replacement constructors.
		map.restore_elevation_snapshot(saved_round, world.maxx, world.maxy, storage.save_validation_maxz())
		storage.begin_zone_restore(operation)
		storage.reset_player_restoration()
		storage.suspend_durable_world()
		invalidate_persistence_area_snapshots()
		storage.ClearMap()
		phase = "world"
		if(!storage.run_world_operation("load", operation))
			throw EXCEPTION(storage.last_error ? storage.last_error : "World-save restoration rejected")
		phase = "metadata"
		operation.diagnostic_phase = "metadata"
		if(storage.load_map_metadata() != TRUE)
			throw EXCEPTION("World metadata restoration rejected")
		storage.restore_durable_world()
		// Apply the date floor after both legacy and durable metadata restoration.
		map.apply_persistence_age_floor()
		storage.restore_round_state(src, saved_round)
		storage.restore_zone_spawns()
		if(attempt_owned)
			phase = "release"
			release_attempted = TRUE
			if(attempt.release_transients() != TRUE)
				throw EXCEPTION("Restore transient release rejected")
#ifdef CIV13_HUMAN_SPATIAL_EXPERIMENTAL
		if(operation.human_direct_restores.len) operation.validate_human_direct_restores()
#endif
		if(!transaction)
			phase = "players"
			operation.diagnostic_phase = "players"
			operation.restoring_players = TRUE
			if(!storage.finish_player_restoration())
				throw EXCEPTION("Player restoration readiness was not confirmed")
#ifdef CIV13_HUMAN_SPATIAL_EXPERIMENTAL
		if(operation.human_direct_restores.len) operation.validate_human_direct_restores()
#endif
		log_startup_progress("\tLoaded the map in [stop_watch(watch)]s.")
	catch(var/exception/e)
		var/primary_failure = "[e] on [e.file]:[e.line]"
		if(attempt_owned)
			try
				var/datum/persistence_restore_failure/outcome = attempt.fail(phase, primary_failure, operation.mutation_started)
				if(!istype(outcome) || outcome.attempt != attempt || (operation.mutation_started && outcome.recovery_retained != TRUE))
					throw EXCEPTION("Restore failure did not confirm retained recovery custody")
			catch(var/exception/failure_error)
				storage.restore_cleanup_error = "[failure_error]"
			if(!release_attempted)
				release_attempted = TRUE
				try
					if(attempt.release_transients() != TRUE)
						throw EXCEPTION("Restore transient cleanup rejected")
				catch(var/exception/release_error)
					storage.restore_cleanup_error = "[storage.restore_cleanup_error]; [release_error]"
		storage.cleanup_world_operation()
		try
			if(operation.mutation_started)
				storage.reset_player_restoration()
		catch(var/exception/reset_error)
			world.log << "World-save player cleanup failed: [reset_error]"
		storage.last_error = primary_failure
		operation.finish(FALSE)
		world.log << "World-save import failed: [storage.last_error]"
		message_admins("Import failed during restoration; restart from the original map before retrying: [e]")
		return FALSE
	operation.finish(TRUE)
	persistence_startup_recovery_status = null
	// Restart recovery reclaims waiting clients after consuming its intent.
	return 1

// The completion marker and each level carry the same generation nonce. Legacy
// markers have no historical round identity/clock; owned bodies allow a bounded
// phase-only fallback after the rest of their world has loaded successfully.
/map_storage/proc/capture_round_state(generation)
	if(ticker && ticker.current_state == GAME_STATE_SETTING_UP)
		throw EXCEPTION("Cannot save during fresh round setup")
	var/elapsed = (round_start_time || round_elapsed_offset) ? max(0, world.time - round_start_time) + round_elapsed_offset : 0
	var/phase = ticker ? ticker.current_state : GAME_STATE_PREGAME
	return list("version" = 1, "generation" = generation, "map" = map.ID, "maxx" = world.maxx, "maxy" = world.maxy, "maxz" = world.maxz, "game_id" = global.game_id, "state" = phase, "elapsed" = phase == GAME_STATE_PREGAME ? 0 : elapsed, "roundstart_time" = phase == GAME_STATE_PREGAME ? 0 : roundstart_time, "elevation" = map.elevation_snapshot())

/map_storage/proc/read_round_state()
	var/marker = trim(file2text("map_saves/save_complete.txt"))
	var/version = copytext(marker, 1, 10) == "round-v2:" ? 2 : 1
	if(copytext(marker, 1, 10) != "round-v1:" && version != 2) return list()
	if(!fexists("map_saves/round.json"))
		throw EXCEPTION("Completed generation is missing round state")
	var/list/state = json_decode(file2text("map_saves/round.json"))
	var/has_elevation = islist(state) && ("elevation" in state)
	var/has_level_links = islist(state) && ("level_links" in state)
	if(!islist(state) || state.len != (version == 2 ? 12 : 11) + has_elevation + has_level_links || state["version"] != version || state["generation"] != marker || state["metadata"] != md5(file2text("map_saves/map.txt")) || state["map"] != map.ID || state["maxx"] != world.maxx || state["maxy"] != world.maxy || state["maxz"] != save_validation_maxz())
		throw EXCEPTION("Round state does not match completed generation")
	if(has_elevation)
		elevation_profile_from_snapshot(state["elevation"], world.maxx, world.maxy, save_validation_maxz())
	if(has_level_links) validate_level_link_rows(state["level_links"])
	if(version == 2 && !islist(state["world_state"]))
		throw EXCEPTION("Completed generation is missing durable world state")
	if(!istext(state["game_id"]) || !length(state["game_id"]) || length(state["game_id"]) > 128)
		throw EXCEPTION("Invalid saved round identity")
	if(!(state["state"] in list(GAME_STATE_PREGAME, GAME_STATE_PLAYING, GAME_STATE_FINISHED)))
		throw EXCEPTION("Invalid saved round phase")
	for(var/key in list("elapsed", "roundstart_time"))
		var/value = state[key]
		if(!isnum(value) || value < 0 || value > 1e15)
			throw EXCEPTION("Invalid saved round clock")
	if(state["state"] == GAME_STATE_PREGAME && (state["elapsed"] || state["roundstart_time"]))
		throw EXCEPTION("Unstarted round has an active clock")
	return state

/map_storage/proc/restore_round_state(datum/controller/gameticker/target, list/state)
	if(!state.len)
		// Owned characters establish a previously playable legacy generation,
		// but cannot reconstruct its historical ID or elapsed time.
		var/legacy_player = FALSE
		for(var/account in persistence_restored_bodies)
			var/list/bodies = persistence_restored_bodies[account]
			if(bodies.len != 1) continue
			var/mob/living/human/H = bodies[1]
			if(H && H.persistence_restored && H.persistence_owner_ckey == account && get_turf(H) && H.stat != DEAD)
				legacy_player = TRUE
				break
		if(!legacy_player) return
		world.log << "Legacy player save: resuming active phase; historical round ID and duration unavailable."
		if(!round_start_time) round_start_time = world.time
		if(!roundstart_time) roundstart_time = world.realtime
		job_master.initialize_position_limits()
		round_restored = TRUE
		target.current_state = GAME_STATE_PLAYING
		stop_lobby_music()
		target.finished = FALSE
		target.minds = list()
		target.collect_minds()
		TOD_loop()
		apply_restored_lighting()
		return
	global.game_id = state["game_id"]
	round_elapsed_offset = state["elapsed"]
	round_start_time = state["state"] == GAME_STATE_PREGAME ? 0 : world.time
	roundstart_time = state["roundstart_time"]
	next_duration_update = 0
	next_duration_update_days = 0
	last_roundduration2text = 0
	last_roundduration2text_days = 0
	if(processes.ticker) processes.ticker.playtime_elapsed = state["elapsed"]
	round_restored = state["state"] != GAME_STATE_PREGAME
	target.current_state = state["state"]
	if(round_restored) stop_lobby_music()
	target.finished = state["state"] == GAME_STATE_FINISHED
	if(round_restored)
		job_master.initialize_position_limits()
		target.minds = list()
		target.collect_minds()
		TOD_loop()
		apply_restored_lighting()

/datum/proc/before_save_context(map_storage/exporter, datum/save_export_frame/frame)
	return before_save()

/turf/var/tmp/datum/save_export_frame/persistence_export_frame

/datum/save_export_frame
	var/map_storage/exporter
	var/savefile/file
	var/datum/source
	var/source_identity
	var/current_field
	var/entry
	var/accepts_children = FALSE
	var/active = TRUE
	var/list/content_refs = list()
	var/list/content_seen = list()
	var/list/declared_children = list()
	var/list/declared_seen = list()
	var/declared_cursor = 1
	var/list/tickets = list()
#ifdef CIV13_HUMAN_SPATIAL_EXPERIMENTAL
	var/human_legacy_aligned = FALSE
#endif
#ifdef CIV13_HUMAN_SUBTILE_CAPTURE_SOURCE
	// Only a validated human save request may install these frame-local values.
	var/datum/human_subtile_save_request/human_spatial_request
	var/list/human_spatial_position
#endif

/datum/save_transfer
	var/datum/save_export_frame/producer
	var/datum/save_export_frame/parent
	var/atom/origin
	var/turf/destination
	var/list/items = list()
	var/committed = FALSE

// Native matrix reference-string conversion can consume an entire tick.
// Direct matrix keys retain identity; all other entry keys keep their contract.
// This key is process-local only: on-disk entries still use numeric IDs.
/map_storage/proc/save_entry_identity(datum/A)
	if(istype(A, /matrix)) return A
	return "\ref[A]"

/map_storage/proc/require_export_frame(datum/save_export_frame/frame)
	if(!frame || !frame.active || frame.exporter != src || !frame.source || save_entry_identity(frame.source) != frame.source_identity || saving_references[frame.source_identity] != frame.entry || saving_reference_pins[frame.entry] != frame.source || saving_export_frames["[frame.entry]"] != frame)
		throw EXCEPTION("Save export frame is no longer valid")
#ifdef CIV13_HUMAN_SUBTILE_CAPTURE_SOURCE
	if(frame.human_spatial_request && (!frame.human_spatial_request.captured || !frame.human_spatial_request.actor || frame.human_spatial_request.actor != frame.source || frame.human_spatial_request.actor.human_subtile_save_request != frame.human_spatial_request || !frame.human_spatial_request.operation || !frame.human_spatial_request.operation.current(src, "save")))
		throw EXCEPTION("Human spatial request lost its operation owner")
#endif
	if(isturf(frame.source) && frame.source:persistence_export_frame != frame)
		throw EXCEPTION("Save export turf was replaced")
	return TRUE

/map_storage/proc/prepare_save_transfer(datum/save_export_frame/frame, atom/origin, turf/destination, list/items)
	require_export_frame(frame)
	if(saving_export_stack[saving_export_stack.len] != frame || !istype(frame.source, /atom/movable) || !origin || origin.loc != frame.source || !destination)
		throw EXCEPTION("Save transfer requires the current producer and its owned storage")
	var/atom/movable/producer = frame.source
	var/parent_ref = saving_references["\ref[destination]"]
	var/datum/save_export_frame/parent = saving_export_frames["[parent_ref]"]
	if(!parent || parent == frame || parent.file != frame.file || !parent.accepts_children || parent.source != destination || producer.loc != destination)
		throw EXCEPTION("Save transfer requires an active direct owning turf")
	require_export_frame(parent)
	if(frame.tickets.len || !islist(items) || !items.len || items.len > 12)
		throw EXCEPTION("Save transfer exceeds its twelve-item bound")
	var/datum/save_transfer/ticket = new
	ticket.producer = frame
	ticket.parent = parent
	ticket.origin = origin
	ticket.destination = destination
	var/list/seen = list()
	for(var/obj/item/I in items)
		if(!I || I.loc != origin || !I.should_save || saving_references["\ref[I]"])
			throw EXCEPTION("Save transfer item is unavailable or already captured")
		for(var/ignored in ignore_types)
			if(istype(I, ignored))
				throw EXCEPTION("Save transfer item is excluded from persistence")
		var/identity = "\ref[I]"
		if(!seen[identity])
			seen[identity] = TRUE
			ticket.items += I
	if(ticket.items.len != items.len)
		throw EXCEPTION("Save transfer requires unique item handles")
	frame.tickets += ticket
	return ticket

/map_storage/proc/commit_save_transfer(datum/save_transfer/ticket)
	if(!ticket)
		throw EXCEPTION("Missing save transfer ticket")
	require_export_frame(ticket.producer)
	require_export_frame(ticket.parent)
	if(saving_export_stack[saving_export_stack.len] != ticket.producer || ticket.producer.source:loc != ticket.destination || !(ticket in ticket.producer.tickets) || !ticket.origin || ticket.origin.loc != ticket.producer.source || ticket.destination != ticket.parent.source)
		throw EXCEPTION("Save transfer ticket is not owned by the current hook")
	for(var/obj/item/I in ticket.items)
		if(!I || I.loc != ticket.destination)
			throw EXCEPTION("Paid save transfer did not reach its declared turf")
	if(ticket.committed)
		return TRUE
	for(var/obj/item/I in ticket.items)
		var/identity = "\ref[I]"
		if(!ticket.parent.declared_seen[identity])
			ticket.parent.declared_seen[identity] = I
			ticket.parent.declared_children += I
	ticket.committed = TRUE
	return TRUE

/map_storage/proc/add_export_content(datum/save_export_frame/frame, ref)
	if(!ref) return
	var/datum/child = saving_reference_pins[ref]
#ifdef CIV13_HUMAN_SPATIAL_EXPERIMENTAL
	var/list/human_root = child ? human_save_roots[save_entry_identity(child)] : null
	if(human_root && human_root["mode"] == "spatial" && human_root["ref"] == ref && frame.source != human_root["origin"])
		if(!isturf(frame.source)) throw EXCEPTION("Human save root entered a captured container")
		return // The saved origin receives the only spatial edge during drain.
	if(human_root && human_root["mode"] == "legacy" && human_root["ref"] == ref)
		var/atom/legacy_parent = human_root["origin"]
		var/turf/parent_turf = human_save_containment_turf(legacy_parent)
		if(!legacy_parent || isDeleted(legacy_parent) || save_entry_identity(legacy_parent) != human_root["origin_identity"] || !parent_turf || parent_turf.z != human_root["z"]) throw EXCEPTION("Legacy human captured parent changed")
		if(frame.source != legacy_parent) return // Drain attaches the captured parent.
		if(!human_save_parent_captured(legacy_parent, human_root["z"], frame.entry)) throw EXCEPTION("Legacy human parent was not captured")
#endif
	var/list/moving_root = child ? moving_save_roots["\ref[child]"] : null
	if(moving_root && moving_root["ref"] == ref && frame.source != moving_root["origin"])
		if(!isturf(frame.source)) throw EXCEPTION("Moving save root entered a captured container")
		return // The frozen origin owns this root; roster drain will attach it.
	var/key = "[ref]"
	// Keep the first captured edge if a completed child later moves.
	var/owner = saving_content_owners[key]
	if(owner && owner != frame.entry)
#ifdef CIV13_HUMAN_SPATIAL_EXPERIMENTAL
		if(human_root && human_root["mode"] == "legacy") human_root["parent_attached"] = TRUE
#endif
		return
	saving_content_owners[key] = frame.entry
#ifdef CIV13_HUMAN_SPATIAL_EXPERIMENTAL
	if(human_root && human_root["mode"] == "legacy") human_root["parent_attached"] = TRUE
#endif
	if(!frame.content_seen[key])
		frame.content_seen[key] = TRUE
		frame.content_refs += key

/map_storage/proc/drain_save_transfers(datum/save_export_frame/frame)
	require_export_frame(frame)
	while(frame.declared_cursor <= frame.declared_children.len)
		var/obj/item/I = frame.declared_children[frame.declared_cursor++]
		if(!I || I.loc != frame.source)
			throw EXCEPTION("Declared paid child moved or disappeared during export")
		var/ref = BuildVarDirectory(frame.file, I, 1)
		require_export_frame(frame)
		if(!I || I.loc != frame.source || !ref)
			throw EXCEPTION("Declared paid child could not be saved in its owning turf")
		add_export_content(frame, ref)
	for(var/obj/item/I in frame.declared_children)
		if(!I || I.loc != frame.source)
			throw EXCEPTION("Declared paid child changed before content publication")
	return TRUE

/map_storage/proc/release_export_frame(datum/save_export_frame/frame)
	if(!frame) return
	if(isturf(frame.source) && frame.source:persistence_export_frame == frame)
		frame.source:persistence_export_frame = null
	if(saving_export_frames["[frame.entry]"] == frame)
		saving_export_frames -= "[frame.entry]"
	saving_export_stack -= frame
	for(var/datum/save_transfer/ticket in frame.tickets)
		ticket.producer = null
		ticket.parent = null
		ticket.origin = null
		ticket.destination = null
		ticket.items = list()
	frame.tickets = list()
#ifdef CIV13_HUMAN_SUBTILE_CAPTURE_SOURCE
	frame.human_spatial_request = null
	frame.human_spatial_position = null
#endif
	frame.declared_children = list()
	frame.declared_seen = list()
	frame.content_refs = list()
	frame.content_seen = list()
	frame.active = FALSE
	frame.source = null
	frame.source_identity = null
	frame.current_field = null
	frame.file = null
	frame.exporter = null

// A candidate validation context describes prospective empty levels without
// allocating turfs. Normal validation continues to use actual world dimensions.
/map_storage/proc/saved_dimension_target()
	if(!fexists("map_saves/save_complete.txt") || !fexists("map_saves/map.txt"))
		throw EXCEPTION("Dimension bootstrap requires a completed generation")
	var/marker = trim(file2text("map_saves/save_complete.txt"))
	if(copytext(marker, 1, 10) != "round-v2:" && copytext(marker, 1, 10) != "round-v1:")
		return world.maxz // Historical map-only saves retain the exact old path.
	var/list/R = json_decode(file2text("map_saves/round.json"))
	if(!islist(R) || R["maxx"] != world.maxx || R["maxy"] != world.maxy)
		throw EXCEPTION("Saved horizontal dimensions differ from the compiled map")
	var/z = R["maxz"]
	if(z == world.maxz) return z // Matching saves need no expansion policy or allocator.
	if(!isnum(z) || z != round(z) || z < world.maxz || z > BUILDING_MAX_Z || !compiled_maxz || z > compiled_maxz + BUILDING_EXTRA_LEVELS)
		throw EXCEPTION("Saved level count exceeds the building expansion policy")
	if(z > world.maxz && world.maxx * world.maxy > BUILDING_MAX_LEVEL_CELLS)
		throw EXCEPTION("Saved added level exceeds the building cell budget")
	return z

/map_storage/proc/allocate_saved_level(target_z)
	return building_allocate_level(target_z, TRUE, dimension_reservation)

/map_storage/proc/prepare_saved_dimensions(list/expected_intent, datum/persistence_world_operation/operation)
	if(dimension_budget_hold)
		// Admission failed before native growth. Preserve its original diagnostic;
		// never let a failed automatic import later overwrite the saved world.
		return FALSE
	if(dimension_recovery_required)
		last_error = "Saved level allocation previously failed; restart from the original map before retrying"
		return FALSE
	if(!persistence_save_in_progress || dimension_bootstrap_busy || validation_maxz || building_allocating_z)
		last_error = "Dimension validation already owns recovery"
		return FALSE
	dimension_bootstrap_busy = TRUE
	var/target_z
	try
		if(expected_intent && (expected_intent["generation"] != trim(file2text("map_saves/save_complete.txt")) || expected_intent["metadata"] != md5(file2text("map_saves/map.txt")) || expected_intent["round"] != md5(file2text("map_saves/round.json"))))
			throw EXCEPTION("Restart intent differs before dimension allocation")
		target_z = saved_dimension_target()
		if(target_z == world.maxz)
			dimension_bootstrap_busy = FALSE
			return TRUE
		// Reserve the complete target before validation yields or any native growth.
		dimension_reservation = world_z_budget.reserve(target_z, "restore")
		if(!dimension_reservation)
			dimension_budget_hold = TRUE
			throw EXCEPTION("Saved world held without resizing or modifying files: [world_z_budget.last_error]")
		validation_maxz = target_z
		var/valid = validate_world_save()
		validation_maxz = 0
		if(!valid) throw EXCEPTION("Prospective saved world failed validation: [last_error]")
		// Full structural/coordinate/metadata validation has completed before the
		// first allocation. Allocation may append only, never replace mapped turfs.
		if(operation) operation.authorize_restore_mutation(src)
		dimension_recovery_required = TRUE
		if(operation)
			operation.mutation_started = TRUE
			operation.diagnostic_phase = "allocate_levels"
			if(operation.restart_transaction) operation.restart_transaction.import_started = TRUE
		for(var/z = world.maxz + 1, z <= target_z, z++)
			if(!allocate_saved_level(z) || world.maxz != z)
				throw EXCEPTION("Saved level allocation failed; preserve files and restart before retrying")
		if(operation) operation.diagnostic_phase = "preflight"
		if(!validate_world_save())
			throw EXCEPTION("Allocated saved world failed exact validation: [last_error]")
		if(!world_z_budget.finish(dimension_reservation, TRUE))
			throw EXCEPTION("Saved level reservation could not complete; restart recovery")
		dimension_reservation = null
		dimension_recovery_required = FALSE
		dimension_bootstrap_busy = FALSE
		return TRUE
	catch(var/exception/e)
		world_z_budget.finish(dimension_reservation, FALSE)
		dimension_reservation = null
		validation_maxz = 0
		dimension_bootstrap_busy = FALSE
		release_durable_world()
		last_error = "[e] on [e.file]:[e.line]"
		return FALSE
