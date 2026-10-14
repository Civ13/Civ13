// Feasibility experiment only. Not included by civ13.dme or the active saver.
// No hooks, disk writes, generation publication or committed-cutoff promotion.
// Limits bound admitted graph/work and reject an over-budget completed capture;
// they cannot preempt a single native operation or prove resident-memory bounds.
/datum/immutable_world_capture
	var/max_nodes = 4096
	var/max_edges = 16384
	var/max_variables = 512
	var/max_depth = 64
	var/max_reserved_bytes = 1048576
	var/max_pause_deciseconds = 2
	var/max_tick_usage = 90
	// Trusted, audited exact-type field projections. No inherited admission and
	// no calls to source.get_saved_vars or source.persistence_runtime_var.
	// Empty by default: complete production field coverage is not established.
	var/list/projection_manifest = list()
	var/error
	var/captured_text
	var/elapsed_deciseconds = 0
	var/node_count = 0
	var/edge_count = 0
	var/reserved_bytes = 0
	var/tmp/start_tick
	var/tmp/start_clock
	var/tmp/list/nodes
	var/tmp/list/identities
	var/tmp/list/pins
	var/tmp/active = FALSE

/datum/immutable_world_capture/proc/clock_now()
	return world.timeofday

/datum/immutable_world_capture/proc/check_budget()
	if(!active || world.time != start_tick)
		throw EXCEPTION("Capture detected a tick transition or was cancelled")
	elapsed_deciseconds = (clock_now() - start_clock + 864000) % 864000
	if(elapsed_deciseconds > max_pause_deciseconds || world.tick_usage > max_tick_usage)
		throw EXCEPTION("Capture pause/work budget exceeded")
	if(node_count > max_nodes || edge_count > max_edges || reserved_bytes > max_reserved_bytes)
		throw EXCEPTION("Capture graph/allocation reservation exceeded")

/datum/immutable_world_capture/proc/reserve(bytes, edges = 1)
	reserved_bytes += bytes
	edge_count += edges
	check_budget()

/datum/immutable_world_capture/proc/reject_hook(datum/source)
	// All current mutating paid-object hooks must have pure projections before
	// admission. Reject ancestors too, without invoking even their base hook.
	for(var/path_text in list("/obj/structure/loom", "/obj/structure/mill", "/obj/structure/dehydrator", "/obj/structure/oilwell", "/obj/structure/compost", "/obj/structure/sawmill", "/obj/structure/drill"))
		var/path = text2path(path_text)
		if(path && istype(source, path))
			throw EXCEPTION("Capture has no pure projection for [path_text]")
	// The movable base hook updates corpse age. Omitting it changes saved
	// semantics, so a body with an active record is currently unsupported.
	if(source.vars.Find("corpse_decay_record") && source.vars["corpse_decay_record"])
		throw EXCEPTION("Capture has no pure corpse-age projection")

/datum/immutable_world_capture/proc/new_node(value, kind)
	node_count++
	reserve(256)
	var/id = nodes.len + 1
	identities["\ref[value]"] = id
	pins += list(value)
	var/list/node = list("kind" = kind, "id" = id)
	nodes += list(node)
	return node

/datum/immutable_world_capture/proc/encode(value, depth = 0)
	check_budget()
	if(depth > max_depth) throw EXCEPTION("Capture depth exceeded")
	reserve(64)
	if(isnull(value) || isnum(value)) return list("kind" = "value", "value" = value)
	if(istext(value))
		reserve(4 * length(value), 0)
		return list("kind" = "value", "value" = value)
	if(ispath(value)) return list("kind" = "path", "value" = "[value]")
	if(!islist(value) && !istype(value, /datum)) throw EXCEPTION("Unsupported capture value")
	var/id = identities["\ref[value]"]
	if(id && pins[id] == value) return list("kind" = "ref", "id" = id)
	if(islist(value))
		var/list/input = value
		// Reserve before Copy or row allocation. This is logical accounting,
		// not an assertion about allocator/GC/OS overhead.
		if(input.len > max_edges - edge_count) throw EXCEPTION("Capture list edge bound exceeded")
		reserve(64 * input.len, 0)
		var/list/node = new_node(input, "list")
		var/list/rows = list()
		node["rows"] = rows
		var/list/snapshot = input.Copy()
		for(var/i = 1, i <= snapshot.len, i++)
			var/key = snapshot[i]
			var/list/row = list("key" = encode(key, depth + 1), "value" = encode((isnum(key) || isnull(key)) ? null : snapshot[key], depth + 1))
			rows += list(row)
		return list("kind" = "ref", "id" = node["id"])
	var/datum/source = value
	if(istype(source, /client) || !source.should_save) throw EXCEPTION("Unsupported unsaved capture reference")
	reject_hook(source)
	if(source.vars.len > max_variables) throw EXCEPTION("Capture variable bound exceeded")
	var/list/node = new_node(source, "datum")
	node["type"] = "[source.type]"
	var/list/fields = list()
	node["fields"] = fields
	var/list/saved = projection_manifest["[source.type]"]
	if(!islist(saved)) throw EXCEPTION("No audited exact-type capture projection")
	check_budget()
	if(saved.len > max_variables) throw EXCEPTION("Capture saved-variable bound exceeded")
	for(var/key in saved)
		check_budget()
		if(key in list("loc", "locs", "pixloc", "contents", "vars", "type", "parent_type", "x", "y", "z", "vis_locs", "client", "key", "ckey")) throw EXCEPTION("Runtime field in capture projection")
		if(!source.vars.Find(key)) throw EXCEPTION("Capture field disappeared")
		reserve(4 * length("[key]"), 0)
		fields[key] = encode(source.vars[key], depth + 1)
	if(istype(source, /atom))
		var/atom/A = source
		if(isturf(A))
			node["position"] = list(A.x, A.y, A.z)
		if(A.load_contents)
			if(A.contents.len > max_edges - edge_count) throw EXCEPTION("Capture contents bound exceeded")
			var/list/children = list()
			node["contents"] = children
			for(var/atom/movable/child in A.contents)
				if(child.loc != A) throw EXCEPTION("Capture child ownership changed")
				children += list(encode(child, depth + 1))
	check_budget()
	return list("kind" = "ref", "id" = node["id"])

/datum/immutable_world_capture/proc/capture(list/roots, begin_tick = null, begin_clock = null)
	if(active) return FALSE
	error = null
	captured_text = null
	node_count = 0
	edge_count = 0
	reserved_bytes = 0
	nodes = list()
	identities = list()
	pins = list()
	start_tick = isnull(begin_tick) ? world.time : begin_tick
	start_clock = isnull(begin_clock) ? clock_now() : begin_clock
	active = TRUE
	try
		if(!islist(roots) || roots.len > max_nodes) throw EXCEPTION("Capture root bound exceeded")
		reserve(64 * roots.len, 0)
		var/list/root_refs = list()
		for(var/root in roots) root_refs += list(encode(root))
		check_budget()
		var/text = json_encode(list("schema" = "immutable-capture-experiment-v1", "world_dimensions" = list(world.maxx, world.maxy, world.maxz), "roots" = root_refs, "nodes" = nodes))
		reserve(4 * length(text), 0)
		check_budget()
		// Only the detached immutable string escapes. Async writers need no
		// live atom/list access. This is not a generation receipt or cutoff.
		captured_text = text
	catch(var/exception/E)
		error = "[E]"
	active = FALSE
	nodes = null
	identities = null
	pins = null
	return !isnull(captured_text)

/datum/immutable_world_capture/proc/capture_world()
	if(active) return FALSE
	captured_text = null
	var/begin_tick = world.time
	var/begin_clock = clock_now()
	var/root_bound = world.maxx * world.maxy * world.maxz + 1
	if(!map || root_bound > max_nodes || 64 * root_bound > max_reserved_bytes)
		error = "Whole-world root reservation exceeded or metadata absent"
		return FALSE
	var/list/roots = list()
	for(var/turf/T in world)
		if(world.time != begin_tick || (clock_now() - begin_clock + 864000) % 864000 > max_pause_deciseconds)
			error = "World enumeration crossed a tick or exceeded pause budget"
			return FALSE
		roots += T
	roots += map
	// Capture includes enumeration time. No disk or live-state mutation occurs.
	return capture(roots, begin_tick, begin_clock)
