// Explicit world metadata uses a separate graph from per-level object graphs.
// Capture does not construct objects or duplicate leaders stored on another z.
// Entry identities are bound only when that same atom is exported normally.
/datum/durable_save_graph
	var/list/nodes = list()
	var/list/list_ids = list()
	var/list/list_pins = list()
	var/list/atom_ids = list()
	var/list/atom_pins = list()
	var/list/restored = list()
	var/list/entry_targets = list()
	var/budget = 100000

/datum/durable_save_graph/proc/add_node(list/node)
	if(nodes.len >= budget)
		throw EXCEPTION("Durable metadata exceeds its node budget")
	nodes += list(node)
	return nodes.len

/datum/durable_save_graph/proc/encode(value, depth = 0)
	if(depth > 128)
		throw EXCEPTION("Durable metadata exceeds its nesting budget")
	if(isnull(value) || isnum(value) || istext(value))
		if(istext(value) && length(value) > 1048576)
			throw EXCEPTION("Durable metadata text exceeds its size budget")
		return add_node(list("kind" = "value", "value" = value))
	if(ispath(value, /datum))
		return add_node(list("kind" = "path", "type" = "[value]"))
	if(islist(value) || istype(value, /alist))
		var/identity = "\ref[value]"
		if(list_ids[identity]) return list_ids[identity]
		var/list/keys = list()
		var/list/values = list()
		var/is_associative = istype(value, /alist)
		var/id = add_node(list("kind" = is_associative ? "alist" : "list", "keys" = keys, "values" = values))
		list_ids[identity] = id
		list_pins += list(value)
		var/list/source = value
		var/list/snapshot = source.Copy()
		if(is_associative)
			// alist numeric indexing addresses keys, never ordered positions.
			for(var/key in snapshot)
				keys += encode(key, depth + 1)
				values += encode(snapshot[key], depth + 1)
			return id
		for(var/i = 1, i <= snapshot.len, i++)
			var/key = snapshot[i]
			keys += encode(key, depth + 1)
			values += encode((isnum(key) || isnull(key)) ? null : snapshot[key], depth + 1)
		return id
	if(istype(value, /obj/map_metadata))
		if(value != map) throw EXCEPTION("Durable metadata references another map controller")
		return add_node(list("kind" = "map"))
	if(isturf(value) || isarea(value))
		var/turf/T = isturf(value) ? value : (locate(/turf) in value)
		if(!T) throw EXCEPTION("Durable metadata references an unplaced area")
		var/atom/A = value
		return add_node(list("kind" = isturf(value) ? "turf" : "area", "x" = T.x, "y" = T.y, "z" = T.z, "type" = "[A.type]"))
	if(istype(value, /atom/movable))
		var/atom/movable/A = value
		if(!get_turf(A) || !A.should_save || istype(A, /obj/screen) || istype(A, /mob/new_player))
			throw EXCEPTION("Durable metadata references an unsaved or session-owned atom [A.type]")
		var/identity = "\ref[A]"
		if(atom_ids[identity]) return atom_ids[identity]
		var/id = add_node(list("kind" = "entry", "type" = "[A.type]", "z" = 0, "ref" = 0))
		atom_ids[identity] = id
		atom_pins[identity] = A
		return id
	throw EXCEPTION("Unsupported durable metadata value; explicit migration required")

/datum/durable_save_graph/proc/bind_entry(datum/A, z, ref)
	var/identity = "\ref[A]"
	var/id = atom_ids[identity]
	if(!id) return
	if(atom_pins[identity] != A)
		throw EXCEPTION("Durable metadata atom identity changed during export")
	var/list/node = nodes[id]
	if(node["ref"] && (node["ref"] != ref || node["z"] != z))
		var/atom/movable/movable = A
		var/turf/location = get_turf(movable)
		throw EXCEPTION("Durable metadata atom was exported more than once: type=[A.type] first_z=[node["z"]] first_ref=[node["ref"]] current_z=[z] current_ref=[ref] native_z=[movable.z] turf_z=[location ? location.z : 0]")
	node["z"] = z
	node["ref"] = ref

/datum/durable_save_graph/proc/finish_export()
	for(var/list/node in nodes)
		if(node["kind"] == "entry" && !node["ref"])
			throw EXCEPTION("Durable metadata atom is absent from the saved world")
	// The returned graph has no live objects, raw refs or process references.
	atom_ids = list()
	atom_pins = list()
	list_ids = list()
	list_pins = list()
	return nodes

/datum/durable_save_graph/proc/check_index(value)
	if(!isnum(value) || value < 1 || value != round(value) || value > nodes.len)
		throw EXCEPTION("Invalid durable metadata graph reference")

/datum/durable_save_graph/proc/check_fields(list/node, list/fields)
	if(node.len != fields.len)
		throw EXCEPTION("Unexpected durable metadata node fields")
	for(var/key in fields)
		if(!(key in node)) throw EXCEPTION("Missing durable metadata node field")

// Pure preflight: paths are checked, never instantiated; entry bindings refer
// to the same generation's already validated level files. No world mutation.
/datum/durable_save_graph/proc/validate(list/source, generation)
	if(!islist(source) || !source.len || source.len > budget)
		throw EXCEPTION("Invalid durable metadata graph size")
	nodes = source
	entry_targets = list()
	var/edges = 0
	for(var/index = 1, index <= nodes.len, index++)
		if(!islist(nodes[index])) throw EXCEPTION("Invalid durable metadata node")
		var/list/node = nodes[index]
		switch(node["kind"])
			if("value")
				check_fields(node, list("kind", "value"))
				var/value = node["value"]
				if(!isnull(value) && !isnum(value) && !istext(value))
					throw EXCEPTION("Invalid durable metadata scalar")
				if(istext(value) && length(value) > 1048576)
					throw EXCEPTION("Durable metadata text exceeds its size budget")
			if("path")
				check_fields(node, list("kind", "type"))
				if(!istext(node["type"]) || !ispath(text2path(node["type"]), /datum))
					throw EXCEPTION("Invalid durable metadata type path")
			if("map")
				check_fields(node, list("kind"))
			if("list", "alist")
				check_fields(node, list("kind", "keys", "values"))
				var/list/keys = node["keys"]
				var/list/values = node["values"]
				if(!islist(keys) || !islist(values) || keys.len != values.len)
					throw EXCEPTION("Invalid durable metadata list")
				edges += keys.len * 2
				if(edges > budget * 2) throw EXCEPTION("Durable metadata exceeds its edge budget")
				for(var/i = 1, i <= keys.len, i++)
					check_index(keys[i])
					check_index(values[i])
			if("turf", "area")
				check_fields(node, list("kind", "x", "y", "z", "type"))
				for(var/axis in list("x", "y", "z"))
					var/coordinate = node[axis]
					if(!isnum(coordinate) || coordinate < 1 || coordinate != round(coordinate))
						throw EXCEPTION("Invalid durable metadata coordinate")
				var/type = istext(node["type"]) ? text2path(node["type"]) : null
				if(!map_storage.save_validation_coordinate(node["x"], node["y"], node["z"]) || !ispath(type, node["kind"] == "area" ? /area : /turf))
					throw EXCEPTION("Invalid durable metadata location")
				if(node["kind"] == "area" && map_storage.save_validation_area_type(node["x"], node["y"], node["z"]) != type)
					throw EXCEPTION("Durable metadata area differs from the map")
			if("entry")
				check_fields(node, list("kind", "type", "z", "ref"))
				var/z = node["z"]
				var/ref = node["ref"]
				var/type = istext(node["type"]) ? text2path(node["type"]) : null
				if(!isnum(z) || z < 1 || z > map_storage.save_validation_maxz() || z != round(z) || !isnum(ref) || ref < 1 || ref != round(ref) || !ispath(type, /atom/movable) || ispath(type, /obj/screen) || ispath(type, /mob/new_player))
					throw EXCEPTION("Invalid durable metadata entry identity")
				var/savefile/F = new("map_saves/[z].sav")
				if(F["/generation"] != generation || F["[map_storage.entry_path(F, ref)]/type"] != type)
					throw EXCEPTION("Durable metadata entry differs from its completed generation")
				entry_targets["[z]:[ref]"] = TRUE
			else
				throw EXCEPTION("Unknown durable metadata node kind")
	// Validate semantic keys after every node and edge has been checked. Separate
	// scalar nodes can denote the same key; duplicate keys would silently merge.
	for(var/list/node in nodes)
		if(node["kind"] != "alist") continue
		var/list/seen_keys = list()
		var/list/keys = node["keys"]
		for(var/id in keys)
			var/signature = key_signature(id)
			if(signature in seen_keys) throw EXCEPTION("Duplicate durable metadata associative key")
			seen_keys[signature] = TRUE
	return TRUE

/datum/durable_save_graph/proc/key_signature(id)
	var/list/node = nodes[id]
	switch(node["kind"])
		if("value") return json_encode(list("value", node["value"]))
		if("path") return json_encode(list("path", node["type"]))
		if("map") return "map"
		if("entry") return json_encode(list("entry", node["z"], node["ref"]))
		if("turf") return json_encode(list("turf", node["x"], node["y"], node["z"]))
		if("area")
			var/turf/T = locate(node["x"], node["y"], node["z"])
			return "area:\ref[T.loc]"
		if("list", "alist") return "collection:[id]"
	throw EXCEPTION("Invalid durable metadata associative key")

/datum/durable_save_graph/proc/accept_entry(z, ref, datum/A)
	var/key = "[z]:[ref]"
	if(entry_targets[key]) entry_targets[key] = A

// Allocate all lists before linking edges, so aliases and cycles survive.
// This runs after all levels load and never invokes atom constructors.
/datum/durable_save_graph/proc/decode()
	restored = new/list(nodes.len)
	for(var/i = 1, i <= nodes.len, i++)
		var/list/node = nodes[i]
		switch(node["kind"])
			if("value") restored[i] = node["value"]
			if("path") restored[i] = text2path(node["type"])
			if("map") restored[i] = map
			if("list") restored[i] = list()
			if("alist") restored[i] = alist()
			if("turf") restored[i] = locate(node["x"], node["y"], node["z"])
			if("area")
				var/turf/T = locate(node["x"], node["y"], node["z"])
				restored[i] = T.loc
			if("entry")
				var/target = entry_targets["[node["z"]]:[node["ref"]]"]
				if(!istype(target, /atom/movable))
					throw EXCEPTION("Durable metadata target was not restored")
				var/atom/movable/A = target
				if("[A.type]" != node["type"])
					throw EXCEPTION("Durable metadata target was not restored")
				restored[i] = A
	for(var/i = 1, i <= nodes.len, i++)
		var/list/node = nodes[i]
		if(!(node["kind"] in list("list", "alist"))) continue
		var/list/target = restored[i]
		var/list/keys = node["keys"]
		var/list/values = node["values"]
		for(var/j = 1, j <= keys.len, j++)
			var/key = restored[keys[j]]
			if(node["kind"] == "alist")
				target[key] = restored[values[j]]
				continue
			target += list(key)
			if(!isnum(key) && !isnull(key)) target[key] = restored[values[j]]
	return restored
