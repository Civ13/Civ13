// Complete inventories make absence authoritative. Native refs never cross a save.
// This version models native membership only. Independent coordinate-geography
// layers require their own versioned component; IDs here are lineage-local.
var/global/persistence_zones_initialized = FALSE
var/global/persistence_spawns_authoritative = FALSE
var/global/datum/persistence_area_registry_epoch/persistence_area_epoch = new
var/global/datum/persistence_area_startup/persistence_area_startup_token

/datum/persistence_area_registry_epoch
	should_save = FALSE

/proc/invalidate_persistence_area_snapshots()
	persistence_area_epoch = new

/proc/require_persistence_area_snapshot(datum/persistence_area_registry_epoch/epoch)
	require_persistence_area_registry()
	if(!epoch || epoch != persistence_area_epoch) throw EXCEPTION("Area registry snapshot expired")

// Only world/New supplies this one-shot identity to the initial setup pass.
// Public registry admission has no startup bypass argument.
/datum/persistence_area_startup
	should_save = FALSE
	var/used = FALSE
	var/active = FALSE
	var/datum/persistence_area_registry_epoch/epoch
	proc/close()
		active = FALSE
		if(persistence_area_startup_token == src) persistence_area_startup_token = null
	proc/require_owner()
		if(persistence_area_startup_token != src || !active || !used || epoch != persistence_area_epoch || persistence_active_operation || persistence_load_recovery_required || map_storage.dimension_recovery_required || map_storage.dimension_budget_hold) throw EXCEPTION("Initial area pass ownership expired")
	proc/initialize_areas()
		if(used || persistence_area_startup_token != src) throw EXCEPTION("Initial area pass was already consumed")
		used = TRUE
		active = TRUE
		epoch = persistence_area_epoch
		try
			require_owner()
			for(var/area/A in area_list)
				require_owner()
				A.initialize(src)
				require_owner()
		catch(var/exception/E)
			close()
			throw E
		close()

/area/var/tmp/persistence_zone_id
/datum/persistence_world_operation/var/datum/persistence_zone_restore/zone_restore

/proc/initialize_persistence_zones()
	if(persistence_zones_initialized) return
	for(var/area/A in area_list)
		if(A.persistence_zone_id) continue
		// world iteration is coordinate ordered; choose the minimum explicitly.
		var/anchor = 0
		for(var/turf/T in A)
			var/index = ((T.z - 1) * world.maxy + T.y - 1) * world.maxx + T.x
			if(!anchor || index < anchor) anchor = index
		if(anchor) A.persistence_zone_id = "map:[A.type]:[anchor]"
	persistence_zones_initialized = TRUE

/proc/zone_namespace_valid(value)
	if(!istext(value) || length(value) != 41 || !(copytext(value, 1, 10) in list("round-v1:", "round-v2:"))) return FALSE
	for(var/i = 10, i <= 41, i++)
		if(!findtext("0123456789abcdef", copytext(value, i, i+1))) return FALSE
	return TRUE

// Decimal text avoids BYOND numeric integer precision limits.
/proc/zone_counter_valid(value)
	if(!istext(value) || !length(value) || length(value) > 12 || copytext(value, 1, 2) == "0") return FALSE
	for(var/i = 1, i <= length(value), i++)
		if(!findtext("0123456789", copytext(value, i, i+1))) return FALSE
	return TRUE

/proc/zone_counter_after(a, b)
	if(length(a) != length(b)) return length(a) > length(b)
	for(var/i = 1, i <= length(a), i++)
		if(text2ascii(a, i) != text2ascii(b, i)) return text2ascii(a, i) > text2ascii(b, i)
	return FALSE

/proc/zone_counter_increment(value)
	if(!zone_counter_valid(value)) throw EXCEPTION("Invalid zone counter")
	for(var/i = length(value), i >= 1, i--)
		var/digit = text2ascii(value, i) - 48
		if(digit < 9) return "[copytext(value, 1, i)][digit+1][copytext(value, i+1)]"
		value = "[copytext(value, 1, i)]0[copytext(value, i+1)]"
	if(length(value) == 12) throw EXCEPTION("Zone counter exhausted")
	return "1[value]"

/proc/persistence_area_registry_blocked()
	var/datum/persistence_world_operation/P = persistence_active_operation
	var/ready = P && P.kind == "load" && P.restoring_players && (!P.zone_restore || P.zone_restore.committed)
	return persistence_load_recovery_required || map_storage.dimension_recovery_required || map_storage.dimension_budget_hold || persistence_restart.startup_hold || (P && P.kind == "load" && !ready)

/proc/require_persistence_area_registry(datum/persistence_zone_restore/context)
	if(context)
		context.require_owner()
		return
	if(persistence_area_registry_blocked()) throw EXCEPTION("Area registry unavailable during load/recovery")

/proc/persistence_register_area(area/A)
	var/datum/persistence_world_operation/P = persistence_active_operation
	if(P && P.zone_restore && !P.zone_restore.committed)
		P.zone_restore.register(A)
		return
	area_list |= A

/proc/persistence_unregister_area(area/A)
	var/datum/persistence_world_operation/P = persistence_active_operation
	if(P && P.zone_restore && !P.zone_restore.committed)
		P.zone_restore.pending -= A
		return
	area_list -= A

/map_storage
	var/list/validated_zone_state
	var/list/validated_zones = list()
	var/list/validated_zone_grid = list()
	var/list/restored_zones = list()
	var/list/zone_export_state
	var/list/zone_export_zones = list()
	var/list/zone_export_pins = list()
	var/list/zone_export_anchors = list()
	var/list/zone_id_reservations = list()
	var/list/zone_high_water = list()
	var/zone_namespace
	var/zone_next_counter = "1"
	var/zone_export_generation
	var/zone_export_maxz
	var/list/zone_candidate_validation

/proc/persistence_zone_schema()
	var/list/schema = durable_metadata_area_schema()
	schema["name"] = "text"
	schema["icon_state"] = "text"
	schema["location"] = "number"
	schema["dynamic_lighting"] = "flag"
	schema["is_void_area"] = "flag"
	return schema

/map_storage/proc/zone_index(x, y, z)
	return ((z - 1) * world.maxy + y - 1) * world.maxx + x

/map_storage/proc/saved_zone_id(x, y, z)
	if(!validated_zone_state || !save_validation_coordinate(x, y, z)) return null
	return validated_zone_grid[zone_index(x, y, z)]

/map_storage/proc/clear_saved_zones()
	validated_zone_state = null
	validated_zones = list()
	validated_zone_grid = list()
	restored_zones = list()
	var/datum/persistence_world_operation/P = persistence_active_operation
	if(P && P.zone_restore)
		P.zone_restore.owner = null
		P.zone_restore.storage = null
		P.zone_restore.pending = list()
		P.zone_restore = null

/map_storage/proc/clear_zone_export()
	zone_export_state = null
	zone_export_zones = list()
	zone_export_pins = list()
	zone_export_anchors = list()
	zone_id_reservations = list()
	zone_export_generation = null
	zone_export_maxz = null

/map_storage/proc/reserve_zone_id(area/A)
	var/id = A.persistence_zone_id
	if(!id) return
	var/list/reservation = zone_id_reservations[id]
	if(!istext(id) || !length(id) || length(id) > 512 || (reservation && reservation["owner"] != A)) throw EXCEPTION("Duplicate live zone identity")
	// Retain the reservation even if native deletion clears its owner pointer.
	zone_id_reservations[id] = list("owner" = A)

/map_storage/proc/allocate_zone_id(area/A)
	if(!zone_namespace_valid(zone_namespace) || !zone_counter_valid(zone_next_counter)) throw EXCEPTION("Zone allocator is unavailable")
	for(var/attempt = 1, attempt <= 32, attempt++)
		var/id = "zone:[zone_namespace]:[zone_next_counter]"
		zone_next_counter = zone_counter_increment(zone_next_counter)
		zone_high_water[zone_namespace] = zone_next_counter
		if(id in zone_id_reservations) continue
		zone_id_reservations[id] = list("owner" = A)
		A.persistence_zone_id = id
		return id
	throw EXCEPTION("Zone ID collision retry budget exhausted")

/map_storage/proc/capture_zone_descriptor(area/A)
	if(!A || A.gc_destroyed || A.gcDestroyed) throw EXCEPTION("Retired zone cannot be captured")
	reserve_zone_id(A)
	var/id = A.persistence_zone_id ? A.persistence_zone_id : allocate_zone_id(A)
	if(zone_export_pins[id] && zone_export_pins[id] != A) throw EXCEPTION("Duplicate captured zone identity")
	if(!zone_export_zones[id])
		var/list/row = list("id" = id, "type" = "[A.type]", "fields" = durable_metadata_snapshot_fields(A, persistence_zone_schema()))
		zone_export_zones[id] = row
		zone_export_pins[id] = A
		var/list/zones = zone_export_state["zones"]
		zones += list(row)
	return id

/map_storage/proc/capture_zone_spawns(list/source, named = FALSE)
	if(!islist(source) || istype(source, /alist)) throw EXCEPTION("Invalid spawn registry")
	var/list/snapshot = source.Copy()
	var/list/result = list()
	if(named)
		for(var/key in snapshot)
			if(!istext(key) || !length(key) || length(key) > 256) throw EXCEPTION("Invalid spawn group")
			result[key] = capture_zone_spawns(snapshot[key])
			TICK_CHECK
		return result
	var/list/seen = list()
	for(var/i = 1, i <= snapshot.len, i++)
		var/turf/T = snapshot[i]
		if(!isturf(T) || locate(T.x, T.y, T.z) != T || !istype(T.loc, /area)) throw EXCEPTION("Stale spawn destination")
		var/key = "[T.x],[T.y],[T.z]"
		if(seen[key]) throw EXCEPTION("Duplicate spawn destination")
		seen[key] = TRUE
		result += list(list("x" = T.x, "y" = T.y, "z" = T.z, "zone" = capture_zone_descriptor(T.loc)))
		TICK_CHECK
	return result

/map_storage/proc/begin_zone_export(generation)
	clear_zone_export()
	initialize_persistence_zones()
	if(!zone_namespace_valid(generation)) throw EXCEPTION("Invalid zone generation namespace")
	if(!zone_namespace) zone_namespace = generation
	if(!zone_namespace_valid(zone_namespace) || !zone_counter_valid(zone_next_counter)) throw EXCEPTION("Invalid zone allocator state")
	zone_export_generation = generation
	zone_export_maxz = world.maxz
	zone_export_state = list("schema" = 2, "allocator" = null, "zones" = list(), "spawns" = null)
	zone_id_reservations = list()
	var/list/areas = area_list.Copy()
	for(var/area/A in areas)
		if(A.gc_destroyed || A.gcDestroyed) continue
		reserve_zone_id(A)
	for(var/area/A in areas)
		if(A.gc_destroyed || A.gcDestroyed) continue
		capture_zone_descriptor(A)
		TICK_CHECK
	zone_export_state["spawns"] = list("latejoin" = capture_zone_spawns(latejoin_turfs, TRUE), "start" = capture_zone_spawns(newplayer_start), "join" = capture_zone_spawns(latejoin), "paradrop" = capture_zone_spawns(paradrop_landmarks), "supply" = capture_zone_spawns(supplydrop_turfs))

// First turf-frame admission, before recursive contents can yield. Scalars
// live in the level file; full-world membership is never copied into JSON.
/map_storage/proc/capture_zone_turf(savefile/F, datum/save_export_frame/frame)
	if(!zone_export_state || !isturf(frame.source)) return
	require_export_frame(frame)
	var/turf/T = frame.source
	if(T.z != saving_z || world.maxz != zone_export_maxz) throw EXCEPTION("Zone capture dimensions changed")
	var/id = capture_zone_descriptor(T.loc)
	var/path = "/zone_capture/[frame.entry]"
	F["[path]/index"] << zone_index(T.x, T.y, T.z)
	F["[path]/id"] << id
	if(!zone_export_anchors[id]) zone_export_anchors[id] = list("x" = T.x, "y" = T.y, "z" = T.z)

/map_storage/proc/encode_zone_reference(area/A)
	return list("kind" = "zone", "id" = capture_zone_descriptor(A), "type" = A.type)

/map_storage/proc/validate_zone_reference(id, type)
	var/list/row = istext(id) ? validated_zones[id] : null
	if(!validated_zone_state || !row || !ispath(type, /area) || row["type"] != "[type]") throw EXCEPTION("Missing or mismatched saved zone reference")
	return TRUE

/map_storage/proc/finalize_zone_export(list/world_state)
	if(world.maxz != zone_export_maxz) throw EXCEPTION("Zone capture dimensions changed")
	zone_export_state["allocator"] = list("namespace" = zone_namespace, "next" = zone_next_counter)
	var/list/areas = list()
	for(var/id in zone_export_anchors)
		var/list/anchor = zone_export_anchors[id]
		var/list/zone = zone_export_zones[id]
		var/list/source = zone["fields"]
		var/list/fields = list()
		for(var/key in durable_metadata_area_schema()) fields[key] = source[key]
		areas += list(list("x" = anchor["x"], "y" = anchor["y"], "z" = anchor["z"], "type" = zone["type"], "fields" = fields))
		TICK_CHECK
	world_state["areas"] = areas

/map_storage/proc/validate_captured_world_save(list/candidate)
	if(zone_candidate_validation || !persistence_active_operation || !persistence_active_operation.current(src, "save") || candidate["generation"] != zone_export_generation) throw EXCEPTION("Unowned candidate validation")
	zone_candidate_validation = candidate
	var/success
	try
		success = validate_world_save()
	catch(var/exception/candidate_error)
		zone_candidate_validation = null
		throw candidate_error
	zone_candidate_validation = null
	return success

/map_storage/proc/validate_zone_spawns(list/source, named = FALSE)
	if(!islist(source) || istype(source, /alist)) throw EXCEPTION("Invalid saved spawn registry")
	if(named)
		for(var/key in source)
			if(!istext(key) || !length(key) || length(key) > 256) throw EXCEPTION("Invalid saved spawn group")
			validate_zone_spawns(source[key])
		return
	var/datum/durable_save_graph/G = new
	var/list/seen = list()
	for(var/i = 1, i <= source.len, i++)
		var/list/row = source[i]
		G.check_fields(row, list("x", "y", "z", "zone"))
		if(!save_validation_coordinate(row["x"], row["y"], row["z"])) throw EXCEPTION("Spawn outside saved world")
		var/index = zone_index(row["x"], row["y"], row["z"])
		if(!istext(row["zone"]) || validated_zone_grid[index] != row["zone"] || seen["[index]"]) throw EXCEPTION("Duplicate or stale spawn zone")
		seen["[index]"] = TRUE

/map_storage/proc/prepare_saved_zones(list/world_state, generation)
	clear_saved_zones()
	if(!islist(world_state) || world_state["schema"] == 1) return
	if(world_state["schema"] != 2) throw EXCEPTION("Unsupported zone metadata revision")
	var/list/state = world_state["topology"]
	var/datum/durable_save_graph/G = new
	G.check_fields(state, list("schema", "allocator", "zones", "spawns"))
	if(state["schema"] != 2 || !islist(state["zones"])) throw EXCEPTION("Invalid zone topology")
	var/list/allocator = state["allocator"]
	G.check_fields(allocator, list("namespace", "next"))
	if(!zone_namespace_valid(allocator["namespace"]) || !zone_counter_valid(allocator["next"])) throw EXCEPTION("Invalid saved zone allocator")
	var/cells = world.maxx * world.maxy * save_validation_maxz()
	var/list/zones = state["zones"]
	if(!zones.len || zones.len > cells + 4096) throw EXCEPTION("Invalid zone inventory size")
	for(var/i = 1, i <= zones.len, i++)
		var/list/row = zones[i]
		G.check_fields(row, list("id", "type", "fields"))
		var/id = row["id"]
		if(!istext(id) || !length(id) || length(id) > 512 || validated_zones[id] || !istext(row["type"]) || !ispath(text2path(row["type"]), /area)) throw EXCEPTION("Invalid or duplicate zone identity")
		var/prefix = "zone:[allocator["namespace"]]:"
		if(findtext(id, prefix) == 1)
			var/counter = copytext(id, length(prefix)+1)
			if(!zone_counter_valid(counter) || !zone_counter_after(allocator["next"], counter)) throw EXCEPTION("Saved zone counter precedes issued ID")
		durable_metadata_validate_fields(row["fields"], persistence_zone_schema())
		validated_zones[id] = row
		TICK_CHECK
	for(var/z = 1, z <= save_validation_maxz(), z++)
		if(!fexists("map_saves/[z].sav")) throw EXCEPTION("Missing captured zone level")
		var/savefile/F = new("map_saves/[z].sav")
		F.cd = "/"
		for(var/key in list("format_version", "generation", "maxx", "maxy", "maxz", "zone_capture", "map"))
			if(!(key in F.dir)) throw EXCEPTION("Missing zone capture header")
		if(F["/format_version"] != 2 || F["/generation"] != generation || F["/maxx"] != world.maxx || F["/maxy"] != world.maxy || F["/maxz"] != save_validation_maxz()) throw EXCEPTION("Zone capture header differs")
		F.cd = "/zone_capture"
		if(F.dir.len != world.maxx * world.maxy) throw EXCEPTION("Incomplete captured zone level")
		F.cd = "/map"
		if(!("[z]" in F.dir)) throw EXCEPTION("Missing captured zone grid")
		for(var/y = 1, y <= world.maxy, y++)
			F.cd = "/map/[z]"
			if(!("[y]" in F.dir)) throw EXCEPTION("Missing captured zone row")
			for(var/x = 1, x <= world.maxx, x++)
				F.cd = "/map/[z]/[y]"
				if(!("[x]" in F.dir)) throw EXCEPTION("Missing captured turf coordinate")
				var/ref = F["[x]"]
				if(!isnum(ref) || ref < 1 || ref != round(ref)) throw EXCEPTION("Invalid captured turf reference")
				F.cd = "/zone_capture"
				if(!("[ref]" in F.dir)) throw EXCEPTION("Missing captured membership entry")
				F.cd = "/zone_capture/[ref]"
				if(F.dir.len != 2 || !("index" in F.dir) || !("id" in F.dir)) throw EXCEPTION("Missing captured membership")
				var/id = F["id"]
				if(F["index"] != zone_index(x, y, z) || !istext(id) || !validated_zones[id]) throw EXCEPTION("Captured zone membership differs")
				validated_zone_grid += id
				TICK_CHECK
	var/list/spawns = state["spawns"]
	G.check_fields(spawns, list("latejoin", "start", "join", "paradrop", "supply"))
	validate_zone_spawns(spawns["latejoin"], TRUE)
	for(var/key in list("start", "join", "paradrop", "supply")) validate_zone_spawns(spawns[key])
	if(persistence_active_operation && persistence_active_operation.kind == "load") validate_current_zone_identities()
	validated_zone_state = state

/map_storage/proc/validate_current_zone_identities()
	var/list/seen = list()
	var/list/current = area_list.Copy()
	for(var/area/A in world) current |= A
	for(var/area/A in current)
		var/id = A.persistence_zone_id
		if(!id || !validated_zones[id]) continue
		var/list/row = validated_zones[id]
		if(seen[id] || A.type != text2path(row["type"])) throw EXCEPTION("Current zone identity changed")
		seen[id] = TRUE

/map_storage/proc/unique_saved_zone_type(type)
	var/list/found
	for(var/id in validated_zones)
		var/list/row = validated_zones[id]
		if(row["type"] != "[type]") continue
		if(found) throw EXCEPTION("Ambiguous saved roof base zone")
		found = row
	if(!found) throw EXCEPTION("Absent saved roof base zone")
	return found

// Authoritative topology already contains roof membership. Validate the roof's
// direct owner and scalar settings against it, without constructing any area.
/map_storage/proc/prepare_zone_roof(savefile/F, x, y, z, child, type)
	var/path = entry_path(F, child)
	F.cd = path
	if(!("switch_area" in F.dir) || !("current_area_type" in F.dir)) throw EXCEPTION("Missing saved roof settings")
	var/list/switch_value = F["switch_area"]
	var/list/base_value = F["current_area_type"]
	if(!islist(switch_value) || switch_value["kind"] != "value" || !(switch_value["value"] in list(TRUE, FALSE)) || !isnum(switch_value["value"]) || !islist(base_value) || base_value["kind"] != "value" || !ispath(base_value["value"], /area)) throw EXCEPTION("Invalid zone roof settings")
	var/id = saved_zone_id(x, y, z)
	var/list/zone = validated_zones[id]
	if(switch_value["value"])
		var/list/base = unique_saved_zone_type(base_value["value"])
		var/list/fields = base["fields"]
		if(zone["type"] != "[saved_roof_area_type(fields["climate"])]") throw EXCEPTION("Roof differs from saved zone")
	var/list/row = list("x" = x, "y" = y, "z" = z, "entry" = "[child]", "type" = type, "base" = base_value["value"], "unroofed" = text2path(zone["type"]), "area" = null, "switch" = switch_value["value"], "zone" = id)
	validated_roof_areas["[x],[y],[z]"] = row
	validated_roof_entries["[z]:[child]"] = row

/datum/persistence_zone_restore
	should_save = FALSE
	var/datum/persistence_world_operation/owner
	var/map_storage/storage
	var/list/pending = list()
	var/requested_id
	var/requested_type
	var/committed = FALSE
	var/surprise = FALSE
	var/clearing_old_world = TRUE
	proc/require_owner()
		if(!owner || !owner.current(storage, "load") || owner.zone_restore != src) throw EXCEPTION("Zone staging owner changed")
	proc/register(area/A)
		require_owner()
		// ClearMap can restore old roofs' base areas. Quarantine these transient
		// areas too, but only materialization may request a saved identity.
		if(clearing_old_world)
			pending |= A
			return
		if(!requested_id || A.type != requested_type || storage.restored_zones[requested_id])
			surprise = TRUE
			pending |= A
			throw EXCEPTION("Unexpected staged area constructor")
		A.persistence_zone_id = requested_id
		pending |= A
		storage.restored_zones[requested_id] = A
		requested_id = null
		requested_type = null

/map_storage/proc/begin_zone_restore(datum/persistence_world_operation/operation)
	if(!validated_zone_state) return
	if(!operation.current(src, "load") || operation.zone_restore) throw EXCEPTION("Zone staging admission changed")
	var/datum/persistence_zone_restore/C = new
	C.owner = operation
	C.storage = src
	operation.zone_restore = C

/map_storage/proc/restore_zone_topology()
	if(!validated_zone_state) return
	var/datum/persistence_zone_restore/C = persistence_active_operation.zone_restore
	C.require_owner()
	validate_current_zone_identities()
	// Match only durable IDs, never name/type guesses. Inspect all candidates
	// before constructors or membership assignments can change the world.
	var/list/current = area_list.Copy()
	for(var/area/A in world) current |= A
	for(var/area/A in current)
		if(!A.persistence_zone_id || !validated_zones[A.persistence_zone_id]) continue
		var/list/row = validated_zones[A.persistence_zone_id]
		if(A.type != text2path(row["type"]) || restored_zones[A.persistence_zone_id]) throw EXCEPTION("Current zone identity changed")
		restored_zones[A.persistence_zone_id] = A
	for(var/id in validated_zones)
		var/list/row = validated_zones[id]
		var/area/A = restored_zones[id]
		if(!A)
			C.requested_id = id
			C.requested_type = text2path(row["type"])
			var/type = C.requested_type
			A = new type()
			if(C.requested_id || restored_zones[id] != A) throw EXCEPTION("Staged area did not register its identity")
		durable_metadata_restore_fields(A, row["fields"], persistence_zone_schema())
		A.luminosity = !A.dynamic_lighting
	for(var/z = 1, z <= world.maxz, z++)
		for(var/y = 1, y <= world.maxy, y++)
			for(var/x = 1, x <= world.maxx, x++)
				var/turf/T = locate(x, y, z)
				var/area/A = restored_zones[saved_zone_id(x, y, z)]
				A.contents += T
				// Import repairs derived lighting without dispatching occupant events.
				T.window_coeff_dirty = TRUE
				if(A.dynamic_lighting && !(T.z in map.zlevels_without_lighting)) T.lighting_build_overlay()
				else T.lighting_clear_overlay()
				TICK_CHECK

/map_storage/proc/verify_zone_topology()
	var/datum/persistence_zone_restore/C = persistence_active_operation.zone_restore
	C.require_owner()
	if(C.surprise || C.requested_id) throw EXCEPTION("Unvalidated staged area")
	for(var/z = 1, z <= world.maxz, z++)
		for(var/y = 1, y <= world.maxy, y++)
			for(var/x = 1, x <= world.maxx, x++)
				var/turf/T = locate(x, y, z)
				if(T.loc != restored_zones[saved_zone_id(x, y, z)]) throw EXCEPTION("Restored zone membership changed")
				TICK_CHECK

/map_storage/proc/resolve_zone_spawns(list/source, named = FALSE)
	var/list/result = list()
	if(named)
		for(var/key in source) result[key] = resolve_zone_spawns(source[key])
		return result
	for(var/list/row in source)
		var/turf/T = locate(row["x"], row["y"], row["z"])
		if(!T || T.loc != restored_zones[row["zone"]]) throw EXCEPTION("Restored spawn destination changed")
		result += T
	return result

/map_storage/proc/restore_zone_spawns()
	if(!validated_zone_state)
		persistence_spawns_authoritative = FALSE
		return
	var/datum/persistence_zone_restore/C = persistence_active_operation.zone_restore
	C.require_owner()
	verify_zone_topology()
	var/list/current = area_list.Copy()
	var/list/index = list()
	current |= C.pending
	for(var/id in restored_zones) index += restored_zones[id]
	for(var/area/A in current)
		if(A in index) continue
		if(locate(/turf) in A) throw EXCEPTION("Stale zone retained world membership")
		qdel(A)
		if(A && !A.gc_destroyed && !A.gcDestroyed) throw EXCEPTION("Stale zone retirement failed")
		TICK_CHECK
	var/datum/persistence_area_registry_epoch/next_epoch = new
	reconcile_saved_zone_weather(C)
	verify_zone_topology()
	var/list/spawns = validated_zone_state["spawns"]
	var/list/named = resolve_zone_spawns(spawns["latejoin"], TRUE)
	var/list/starts = resolve_zone_spawns(spawns["start"])
	var/list/joins = resolve_zone_spawns(spawns["join"])
	var/list/drops = resolve_zone_spawns(spawns["paradrop"])
	var/list/supply = resolve_zone_spawns(spawns["supply"])
	var/list/allocator = validated_zone_state["allocator"]
	var/ns = allocator["namespace"]
	var/next = allocator["next"]
	if(zone_high_water[ns] && zone_counter_after(zone_high_water[ns], next)) next = zone_high_water[ns]
	// No yields or callbacks after final resolution and before publication.
	zone_namespace = ns
	zone_next_counter = next
	zone_high_water[ns] = next
	persistence_area_epoch = next_epoch
	area_list = index
	latejoin_turfs = named
	newplayer_start = starts
	latejoin = joins
	paradrop_landmarks = drops
	supplydrop_turfs = supply
	persistence_spawns_authoritative = TRUE
	C.committed = TRUE
	clear_saved_zones()

// Preserve saved local weather/intensity, including distinctions which global
// weather cannot reconstruct. Preserve the constructed icon resource.
/map_storage/proc/reconcile_saved_zone_weather(datum/persistence_zone_restore/context)
	context.require_owner()
	for(var/id in restored_zones)
		context.require_owner()
		var/area/A = restored_zones[id]
		var/list/zone = validated_zones[id]
		var/list/fields = zone["fields"]
		if(!A || A.persistence_zone_id != id || A.weather != fields["weather"] || A.weather_intensity != fields["weather_intensity"]) throw EXCEPTION("Restored local weather changed")
		A.icon_state = fields["icon_state"]
		TICK_CHECK
		context.require_owner()
