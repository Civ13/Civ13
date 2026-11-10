// Closed-world body adapter for the production persistence graph codec.
// Not a world save, not ExportText, and never an arbitrary ImportText endpoint.
// Local capture-bound quarantine roundtrip only, NOT remote import authority.
// No client/account attachment or source deletion. Not included in production DME.
#define TRAIN_BODY_NODES 1024
#define TRAIN_BODY_EDGES 16384
#define TRAIN_BODY_BYTES 600000

/map_storage/train_body_graph
	var/list/body_members = list()
	var/capture_tick = null
	var/wire_edges = 0
	var/body_error = null
	var/tmp/local_snapshot = null
	var/tmp/local_restore_used = FALSE

/map_storage/train_body_graph/proc/admitted_type(path)
	if(path == /mob/living/human || ispath(path, /mob/living/simple_animal)) return TRUE
	if(ispath(path, /obj/item/organ)) return TRUE
	if(ispath(path, /datum/wound) || ispath(path, /datum/reagent) || path == /datum/reagents || path == /datum/dna || ispath(path, /datum/species) || path == /datum/corpse_decay_record) return TRUE
	var/datum/extraction_equipment_codec/equipment = new
	return equipment.supported(path)

/map_storage/train_body_graph/save_work_check()
	if(!isnull(capture_tick) && world.time != capture_tick)
		throw EXCEPTION("Body capture crossed a tick; source must remain unchanged")
	if(saving_reference_pins.len + saving_list_pins.len > TRAIN_BODY_NODES || wire_edges > TRAIN_BODY_EDGES)
		throw EXCEPTION("Body graph budget exceeded")

// Diagnostic paths/field names only: never character names, values or ckeys.
/map_storage/train_body_graph/proc/body_source_context()
	if(!saving_export_stack.len) return "root"
	var/datum/save_export_frame/frame = saving_export_stack[saving_export_stack.len]
	if(!frame || !frame.source) return "unknown"
	return "[frame.source.type].[frame.current_field]"

/map_storage/train_body_graph/BuildVarDirectory(savefile/F, datum/A, contents = 0, traversal = FALSE, datum/human_request = null)
	save_work_check()
	if(traversal && (istype(A, /atom/movable/lighting_overlay) || istype(A, /atom/movable/lighting_fullbright))) return 0
	if(!A || !admitted_type(A.type)) throw EXCEPTION("Unsupported body graph type: [A ? A.type : null] from [body_source_context()]")
	if(istype(A, /atom/movable) && !body_members[A])
		throw EXCEPTION("Body graph references an external movable")
	if(!A.should_save) throw EXCEPTION("Body graph contains an unsaved datum")
	return ..()

/map_storage/train_body_graph/encode_saved_value(savefile/F, value)
	save_work_check()
	wire_edges++
	if(isturf(value) || isarea(value) || istype(value, /obj/map_metadata) || istype(value, /client))
		throw EXCEPTION("Body graph references external world/session state")
	if(!isnull(value) && !isnum(value) && !istext(value) && !ispath(value) && !islist(value) && !istype(value, /datum))
		throw EXCEPTION("Body graph contains a nonportable resource from [body_source_context()]")
	if(islist(value))
		var/list/L = value
		if(L.len > TRAIN_BODY_EDGES) throw EXCEPTION("Body graph list exceeds budget")
	return ..()

/map_storage/train_body_graph/level_link_target(datum/source, key, value)
	// Keep all supported references inside this one manifest. Never turn an
	// external movable into a world coordinate or another world's level ref.
	return FALSE

/map_storage/train_body_graph/drop_cross_level_reference(atom/movable/target)
	if(!body_members[target]) throw EXCEPTION("Body reference leaves its containment graph")
	return FALSE

/map_storage/train_body_graph/proc/enroll_body(mob/living/body)
	if(!istype(body) || !admitted_type(body.type)) throw EXCEPTION("Unsupported body root")
	var/list/queue = list(body)
	for(var/i = 1, i <= queue.len, i++)
		if(queue.len > TRAIN_BODY_NODES) throw EXCEPTION("Body containment exceeds budget")
		var/atom/movable/A = queue[i]
		if(body_members[A]) throw EXCEPTION("Body containment repeats an atom")
		if(!admitted_type(A.type) || !A.should_save) throw EXCEPTION("Unsupported body inventory: [A.type] in [A.loc ? A.loc.type : null]; should_save=[A.should_save]")
		body_members[A] = TRUE
		for(var/atom/movable/child in A.contents)
			// Lighting overlays are deliberately runtime-only in world saves.
			if(istype(child, /atom/movable/lighting_overlay) || istype(child, /atom/movable/lighting_fullbright)) continue
			queue += child

// Native savefile values are encoded explicitly. A list is rows of keys and
// associations, so numeric keys, nulls and ordered lists never become JSON maps.
/map_storage/train_body_graph/proc/to_wire(value, depth = 0)
	wire_edges++
	if(depth > 32 || wire_edges > TRAIN_BODY_EDGES) throw EXCEPTION("Body wire exceeds budget")
	if(isnull(value) || isnum(value) || istext(value)) return list("tag" = "scalar", "value" = value)
	if(ispath(value)) return list("tag" = "path", "value" = "[value]")
	if(!islist(value)) throw EXCEPTION("Nonportable body save value")
	var/list/input = value
	if(input.len > TRAIN_BODY_EDGES) throw EXCEPTION("Body wire list too large")
	var/list/rows = list()
	for(var/i = 1, i <= input.len, i++)
		var/key = input[i]
		rows += list(list(to_wire(key, depth + 1), to_wire((isnum(key) || isnull(key)) ? null : input[key], depth + 1)))
	return list("tag" = "list", "rows" = rows)

/map_storage/train_body_graph/proc/capture_body(mob/living/body)
	body_error = null
	local_snapshot = null
	local_restore_used = FALSE
	clear_bookkeeping()
	body_members = list()
	wire_edges = 0
	capture_tick = world.time
	try
		if(persistence_save_active()) throw EXCEPTION("World save is active")
		enroll_body(body)
		var/turf/body_turf = get_turf(body)
		saving_z = body_turf ? body_turf.z : 0
		if(!saving_z) throw EXCEPTION("Body is not on a world level")
		var/savefile/F = new
		F["/format_version"] << 3
		F["/value_format"] << 2
		var/root = BuildVarDirectory(F, body, 1)
		if(!root) throw EXCEPTION("Body root was not saved")
		// load_contents=FALSE and debug policies must not silently drop inventory.
		for(var/atom/movable/member in body_members)
			if(!saving_references[member]) throw EXCEPTION("Body containment was omitted by production persistence")
		save_work_check()
		var/list/entries = list()
		var/list/lists = list()
		for(var/i = 1, i <= saving_reference_pins.len, i++)
			var/path = entry_path(F, i)
			F.cd = path
			var/list/fields = list()
			for(var/key in F.dir.Copy()) fields[key] = to_wire(F["[path]/[key]"])
			entries += list(fields)
		for(var/i = 1, i <= saving_list_pins.len, i++)
			var/path = "/lists/[i]"
			var/list/scalars = F[path]
			if(islist(scalars))
				lists += list(list("scalar" = to_wire(scalars)))
			else
				var/count = F["[path]/length"]
				var/list/rows = list()
				for(var/j = 1, j <= count, j++)
					rows += list(list(to_wire(F["[path]/[j]/key"]), to_wire(F["[path]/[j]/value"])))
				lists += list(list("rows" = rows))
		var/text = json_encode(list("schema" = "train-body-1", "root" = root, "entries" = entries, "lists" = lists))
		save_work_check()
		if(length(text) > TRAIN_BODY_BYTES) throw EXCEPTION("Body payload exceeds byte budget")
		capture_tick = null
		local_snapshot = text
		return text
	catch(var/exception/E)
		body_error = "[E]"
		capture_tick = null
		return null

// This is a one-shot capability to round-trip this instance's exact capture.
// It intentionally cannot restore a packet captured on another server/instance.
// A future remote importer needs authenticated custody AND a versioned static
// field/constructor admission profile, not removal of this equality check.
/map_storage/train_body_graph/rejuvenate_unowned_human_on_load()
	return FALSE

/obj/effect/train_body_quarantine
	name = "detached train body quarantine"
	should_save = FALSE
	var/tmp/mob/living/body

/map_storage/train_body_graph/proc/body_ref(ref, limit)
	return isnum(ref) && ref == round(ref) && ref >= 1 && ref <= limit

/map_storage/train_body_graph/proc/read_wire(list/V, depth = 0)
	wire_edges++
	if(!islist(V) || depth > 32 || wire_edges > TRAIN_BODY_EDGES) throw EXCEPTION("Malformed body wire")
	if(V["tag"] == "scalar")
		var/value = V["value"]
		if(!isnull(value) && !isnum(value) && !istext(value)) throw EXCEPTION("Invalid body scalar")
		return value
	if(V["tag"] == "path")
		// Called ONLY after exact local snapshot equality, never on remote input.
		var/path = istext(V["value"]) ? text2path(V["value"]) : null
		if(!ispath(path)) throw EXCEPTION("Unknown captured path")
		return path
	if(V["tag"] != "list" || !islist(V["rows"])) throw EXCEPTION("Malformed body list")
	var/list/out = list()
	for(var/list/row in V["rows"])
		if(!islist(row) || row.len != 2) throw EXCEPTION("Malformed body list row")
		var/key = read_wire(row[1], depth + 1)
		var/value = read_wire(row[2], depth + 1)
		out.len++
		out[out.len] = key
		if(!isnum(key) && !isnull(key)) out[key] = value
	return out

/map_storage/train_body_graph/proc/value_edges(value, entry_count, list_count, list/edges)
	if(!islist(value)) return
	var/list/V = value
	switch(V["kind"])
		if("value")
			if(islist(V["value"]) || istype(V["value"], /datum)) throw EXCEPTION("Invalid scalar envelope")
		if("entry")
			if(!body_ref(V["ref"], entry_count)) throw EXCEPTION("Invalid body entry reference")
			edges |= "e[V["ref"]]"
		if("list")
			if(!body_ref(V["ref"], list_count)) throw EXCEPTION("Invalid body list reference")
			edges |= "l[V["ref"]]"
		else
			throw EXCEPTION("External or unknown body reference")

// Pass one: rebuild native savefile values, check closed references, unique
// containment, rooted graph reachability and exact local capture admission.
// No game-object constructor or lifecycle hook is called in this pass.
/map_storage/train_body_graph/proc/local_restore_preflight(text)
	if(!istext(text) || !istext(local_snapshot) || text != local_snapshot || length(text) > TRAIN_BODY_BYTES || local_restore_used)
		throw EXCEPTION("Restore requires this adapter's unconsumed exact local capture")
	var/list/doc = json_decode(text)
	var/list/entries = doc["entries"]
	var/list/lists = doc["lists"]
	if(doc["schema"] != "train-body-1" || !islist(entries) || !islist(lists) || entries.len + lists.len > TRAIN_BODY_NODES || !body_ref(doc["root"], entries.len))
		throw EXCEPTION("Malformed body graph")
	wire_edges = 0
	var/savefile/F = new
	F["/format_version"] << 3
	F["/value_format"] << 2
	F["/train_body_root"] << doc["root"]
	var/list/graph = list()
	var/list/parents = list()
	var/list/entry_types = list()
	for(var/i = 1, i <= entries.len, i++)
		var/list/fields = entries[i]
		if(!islist(fields) || !fields["type"] || !fields["name"]) throw EXCEPTION("Missing body entry identity")
		var/path = read_wire(fields["type"])
		if(!admitted_type(path)) throw EXCEPTION("Unsupported captured body type")
		entry_types += path
		var/list/edges = list()
		graph["e[i]"] = edges
		var/directory = entry_path(F, i)
		for(var/field in fields)
			if(!istext(field) || field in list("loc", "locs", "pixloc", "contents", "vars", "parent_type", "x", "y", "z", "vis_locs", "client", "key", "ckey", "verbs")) throw EXCEPTION("Forbidden body field")
			var/value = read_wire(fields[field])
			if(field == "content")
				if(!ispath(path, /atom/movable)) throw EXCEPTION("Nonmovable body container")
				for(var/ref_text in saved_content_refs(value, 3))
					var/ref = text2num(ref_text)
					if(!body_ref(ref, entries.len) || parents["[ref]"] || ref == doc["root"]) throw EXCEPTION("Invalid body containment")
					parents["[ref]"] = i
					edges |= "e[ref]"
			else
				value_edges(value, entries.len, lists.len, edges)
			F["[directory]/[field]"] << value
	for(var/i = 1, i <= lists.len, i++)
		var/list/node = lists[i]
		var/list/edges = list()
		graph["l[i]"] = edges
		if(!islist(node)) throw EXCEPTION("Malformed body list node")
		if(node["scalar"])
			var/value = read_wire(node["scalar"])
			F["/lists/[i]"] << value
			if(!saved_scalar_list(F, i)) throw EXCEPTION("Malformed scalar list node")
		else
			var/list/rows = node["rows"]
			if(!islist(rows)) throw EXCEPTION("Malformed body list rows")
			F["/lists/[i]/length"] << rows.len
			for(var/j = 1, j <= rows.len, j++)
				var/list/row = rows[j]
				if(!islist(row) || row.len != 2) throw EXCEPTION("Malformed body list pair")
				var/key = read_wire(row[1])
				var/value = read_wire(row[2])
				value_edges(key, entries.len, lists.len, edges)
				value_edges(value, entries.len, lists.len, edges)
				F["/lists/[i]/[j]/key"] << key
				F["/lists/[i]/[j]/value"] << value
	// Movables form a tree rooted at the body; data/list refs may be cyclic.
	for(var/i = 1, i <= entries.len, i++)
		if(i == doc["root"])
			if(!ispath(entry_types[i], /mob/living)) throw EXCEPTION("Body root is not living-mob type")
			continue
		if(!ispath(entry_types[i], /atom/movable)) continue
		var/current = i
		var/list/seen = list()
		while(current != doc["root"])
			if(seen["[current]"] || !parents["[current]"]) throw EXCEPTION("Detached or cyclic body containment")
			seen["[current]"] = TRUE
			current = parents["[current]"]
	var/list/queue = list("e[doc["root"]]")
	var/list/seen = list()
	for(var/i = 1, i <= queue.len, i++)
		var/node = queue[i]
		if(seen[node]) continue
		seen[node] = TRUE
		for(var/next in graph[node])
			if(!seen[next] && !(next in queue)) queue += next
	if(seen.len != entries.len + lists.len) throw EXCEPTION("Unreachable body graph nodes")
	return F

// Pass two: guarded production construction in a detached, non-saving holder.
// Returns QUARANTINED data, not a playable/registered body. Publication requires
// separate verified custody, lifecycle-finalization and placement procedures.
/map_storage/train_body_graph/proc/restore_local_capture(text)
	body_error = null
	var/obj/effect/train_body_quarantine/Q = null
	try
		if(persistence_save_active()) throw EXCEPTION("World save is active")
		var/savefile/F = local_restore_preflight(text)
		local_restore_used = TRUE
		clear_bookkeeping()
		Q = new(null)
		var/root = F["/train_body_root"]
		var/mob/living/body = Load_Entry(F, root, null, Q)
		if(!istype(body) || body.loc != Q || body.client || body.key) throw EXCEPTION("Invalid quarantine body")
		Q.body = body
		// Deliberately no after_load/restore_finished/account registration yet:
		// callbacks can activate gameplay and need a destination custody commit.
		return Q
	catch(var/exception/E)
		body_error = "[E]"
		// Remove only objects created by this isolated exporter, never sources.
		if(Q)
			for(var/i = all_loaded.len, i >= 1, i--)
				var/datum/D = all_loaded[i]
				if(D) qdel(D)
			qdel(Q)
		return null

#undef TRAIN_BODY_NODES
#undef TRAIN_BODY_EDGES
#undef TRAIN_BODY_BYTES
