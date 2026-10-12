// Explicit equipment schema: no mobs, clients, arbitrary variables or world refs.
#define EXTRACTION_EQUIPMENT_NODES 512
#define EXTRACTION_EQUIPMENT_DEPTH 8

/obj/item
	var/tmp/extraction_item_id
	var/tmp/extraction_found_in_raid = FALSE
	var/tmp/extraction_secure_stored = FALSE

var/global/extraction_identity_sequence = 0

/proc/new_extraction_item_id()
	extraction_identity_sequence++
	return md5("[world.realtime]:[rand(1,1000000)]:[extraction_identity_sequence]")

/obj/item/extraction_salvage
	name = "salvaged workshop parts"
	desc = "Useful parts for improving a private safe house."
	icon = 'icons/obj/metallurgy.dmi'
	icon_state = "crude_axehead"
	w_class = ITEM_SIZE_SMALL

/datum/extraction_equipment_codec
	var/last_error
	var/list/items
	var/list/index
	var/list/nodes

/datum/extraction_equipment_codec/proc/supported(path)
	if (!ispath(path, /obj/item)) return FALSE
	if (ispath(path, /obj/item/weapon/gun/projectile/custom)) return FALSE
	if (ispath(path, /obj/item/weapon/key/extraction_room)) return TRUE
	return ispath(path, /obj/item/weapon/gun/projectile) || ispath(path, /obj/item/weapon/attachment) || ispath(path, /obj/item/weapon/gun_mount) || ispath(path, /obj/item/ammo_magazine) || ispath(path, /obj/item/ammo_casing) || ispath(path, /obj/item/projectile) || ispath(path, /obj/item/clothing) || ispath(path, /obj/item/weapon/storage) || ispath(path, /obj/item/weapon/material) || ispath(path, /obj/item/blackpowder_part) || ispath(path, /obj/item/extraction_salvage)

/datum/extraction_equipment_codec/proc/scalar_fields(path)
	var/list/fields = list("name", "desc", "health", "maxhealth", "color", "dir", "weight", "icon_state", "item_state")
	if (ispath(path, /obj/item/weapon/gun)) fields |= list("serial", "sel_mode", "safetyon", "configuration_base_ergonomics", "configuration_base_weight", "attachment_slots")
	if (ispath(path, /obj/item/weapon/attachment)) fields |= list("A_attached", "attachable", "attachment_type", "ergonomics")
	if (ispath(path, /obj/item/ammo_casing)) fields |= list("btype")
	if (ispath(path, /obj/item/weapon/material)) fields |= list("crafting_quality", "tool_head_material", "tool_handle_material", "tool_head_quality", "tool_handle_quality", "tool_head_condition", "tool_handle_condition")
	if (ispath(path, /obj/item/blackpowder_part)) fields |= list("quality", "material_name")
	if (ispath(path, /obj/item/weapon/key/extraction_room)) fields |= "code"
	return fields

/datum/extraction_equipment_codec/proc/reference_fields(path)
	var/list/fields = list()
	if (ispath(path, /obj/item/weapon/gun/projectile)) fields |= list("chambered", "ammo_magazine", "scope", "under", "silencer", "bayonet", "launcher", "optic_rail")
	if (ispath(path, /obj/item/ammo_casing)) fields |= "BB"
	return fields

/datum/extraction_equipment_codec/proc/list_fields(path)
	var/list/fields = list()
	if (ispath(path, /obj/item/weapon/gun/projectile)) fields |= list("loaded", "attachments")
	if (ispath(path, /obj/item/ammo_magazine)) fields |= "stored_ammo"
	return fields

/datum/extraction_equipment_codec/proc/collect(obj/item/I, parent, depth)
	if (!I || !supported(I.type) || items.len >= EXTRACTION_EQUIPMENT_NODES || depth > EXTRACTION_EQUIPMENT_DEPTH || index[I]) return FALSE
	items += I
	index[I] = items.len
	nodes += list(list("type" = "[I.type]", "parent" = parent))
	var/id = items.len
	for (var/atom/movable/child in I.contents)
		if (!istype(child, /obj/item) || !collect(child, id, depth + 1)) return FALSE
	return TRUE

/datum/extraction_equipment_codec/proc/encode(obj/item/root)
	last_error = null
	items = list()
	index = list()
	nodes = list()
	if (!collect(root, 0, 1))
		last_error = "Unsupported equipment, cycle or node/depth budget exceeded"
		clear()
		return null
	for (var/i in 1 to items.len)
		var/obj/item/I = items[i]
		var/list/node = nodes[i]
		if (!I.extraction_item_id) I.extraction_item_id = new_extraction_item_id()
		node["id"] = I.extraction_item_id
		node["found_in_raid"] = I.extraction_found_in_raid
		var/list/scalars = list()
		for (var/key in scalar_fields(I.type))
			if (!(key in I.vars)) continue
			var/value = I.vars[key]
			if (!isnull(value) && !isnum(value) && !istext(value))
				last_error = "Unsupported scalar [key]"
				clear()
				return null
			if (istext(value) && length(value) > 2048)
				clear()
				return null
			scalars[key] = value
		if (istype(I, /obj/item/weapon/material))
			var/obj/item/weapon/material/M = I
			scalars["material_key"] = M.material ? M.material.name : M.default_material
		var/list/refs = list()
		for (var/key in reference_fields(I.type))
			if (!(key in I.vars)) continue
			var/value = I.vars[key]
			if (value && !index[value])
				last_error = "Equipment reference leaves its contained graph"
				clear()
				return null
			refs[key] = value ? index[value] : 0
		var/list/lists = list()
		for (var/key in list_fields(I.type))
			if (!(key in I.vars)) continue
			var/list/value = I.vars[key]
			var/list/encoded = list()
			for (var/entry in value)
				if (!index[entry])
					clear()
					return null
				encoded += index[entry]
			lists[key] = encoded
		node["scalars"] = scalars
		node["refs"] = refs
		node["lists"] = lists
	var/list/result = list("schema" = 2, "nodes" = nodes)
	clear()
	return result

/datum/extraction_equipment_codec/proc/clear()
	items = null
	index = null
	nodes = null

/datum/extraction_equipment_codec/proc/valid_ref(id, count)
	return isnum(id) && round(id) == id && id >= 0 && id <= count

/datum/extraction_equipment_codec/proc/validate(list/record)
	if (!islist(record) || !(record["schema"] in list(1, 2))) return FALSE
	var/list/graph = record["nodes"]
	if (!islist(graph) || graph.len < 1 || graph.len > EXTRACTION_EQUIPMENT_NODES) return FALSE
	var/list/depths = list()
	var/list/identities = list()
	for (var/i in 1 to graph.len)
		var/list/node = graph[i]
		if (!islist(node) || !istext(node["type"])) return FALSE
		if (record["schema"] == 2)
			var/id = node["id"]
			if (!istext(id) || !length(id) || length(id) > 80 || identities[id] || !(node["found_in_raid"] in list(FALSE, TRUE))) return FALSE
			identities[id] = TRUE
		var/path = text2path(node["type"])
		if (!supported(path) || !valid_ref(node["parent"], i - 1) || (i == 1 ? node["parent"] != 0 : node["parent"] == 0)) return FALSE
		var/depth = i == 1 ? 1 : depths[node["parent"]] + 1
		if (depth > EXTRACTION_EQUIPMENT_DEPTH) return FALSE
		depths += depth
		var/list/scalars = node["scalars"]
		var/list/refs = node["refs"]
		var/list/lists = node["lists"]
		if (!islist(scalars) || !islist(refs) || !islist(lists)) return FALSE
		var/list/allowed = scalar_fields(path)
		if (ispath(path, /obj/item/weapon/material)) allowed |= "material_key"
		for (var/key in scalars)
			var/value = scalars[key]
			if (!(key in allowed) || (!isnull(value) && !isnum(value) && !istext(value)) || (istext(value) && length(value) > 2048)) return FALSE
			var/list/text_fields = list("name", "desc", "color", "icon_state", "item_state", "serial", "btype", "material_key", "tool_head_material", "tool_handle_material", "material_name", "attachment_type")
			if (!isnull(value) && (key in text_fields ? !istext(value) : !isnum(value))) return FALSE
		if (ispath(path, /obj/item/weapon/material) && !get_material_by_name(scalars["material_key"])) return FALSE
		for (var/key in refs)
			if (!(key in reference_fields(path)) || !valid_ref(refs[key], graph.len)) return FALSE
			if (refs[key] && !ref_type_valid(key, graph[refs[key]])) return FALSE
		for (var/key in reference_fields(path))
			if (!(key in refs)) return FALSE
		for (var/key in lists)
			if (!(key in list_fields(path))) return FALSE
			var/list/values = lists[key]
			if (!islist(values) || values.len > EXTRACTION_EQUIPMENT_NODES) return FALSE
			for (var/id in values)
				if (!valid_ref(id, graph.len) || !id || !ref_type_valid(key, graph[id])) return FALSE
		for (var/key in list_fields(path))
			if (!(key in lists)) return FALSE
	return TRUE

/datum/extraction_equipment_codec/proc/ref_type_valid(key, list/node)
	if (!islist(node) || !istext(node["type"])) return FALSE
	var/path = text2path(node["type"])
	switch (key)
		if ("chambered", "loaded", "stored_ammo") return ispath(path, /obj/item/ammo_casing)
		if ("ammo_magazine") return ispath(path, /obj/item/ammo_magazine)
		if ("BB") return ispath(path, /obj/item/projectile)
		if ("optic_rail") return ispath(path, /obj/item/weapon/gun_mount)
	return ispath(path, /obj/item/weapon/attachment)

// All shape/type/ref validation completes before constructors run. Callers hold
// the session freeze until the resulting graph has been fully installed.
/datum/extraction_equipment_codec/proc/decode(list/record, atom/destination)
	if (!validate(record)) return null
	var/list/graph = record["nodes"]
	var/list/created = list()
	for (var/i in 1 to graph.len)
		var/list/node = graph[i]
		var/path = text2path(node["type"])
		var/obj/item/I = new path(destination)
		created += I
		// Native constructors may make scopes and bullets. Replace, don't add to
		// those defaults, or a reload would silently manufacture ammunition.
		for (var/atom/movable/A in I.contents.Copy()) qdel(A)
		I.should_save = FALSE
	for (var/i in 1 to graph.len)
		var/list/node = graph[i]
		var/obj/item/I = created[i]
		I.extraction_item_id = record["schema"] == 2 ? node["id"] : new_extraction_item_id()
		I.extraction_found_in_raid = record["schema"] == 2 ? node["found_in_raid"] : FALSE
		var/list/scalars = node["scalars"]
		if (istype(I, /obj/item/weapon/material))
			var/obj/item/weapon/material/M = I
			M.set_material(scalars["material_key"])
		for (var/key in scalars)
			if (key in I.vars) I.vars[key] = scalars[key]
		var/list/refs = node["refs"]
		for (var/key in refs)
			if (key in I.vars) I.vars[key] = refs[key] ? created[refs[key]] : null
		var/list/lists = node["lists"]
		for (var/key in lists)
			var/list/restored = list()
			for (var/id in lists[key]) restored += created[id]
			if (key in I.vars) I.vars[key] = restored
		I.forceMove(node["parent"] ? created[node["parent"]] : destination)
	for (var/obj/item/I in created) I.after_load()
	return created[1]

// Validate the full bounded graph before changing any nested provenance.
/datum/extraction_equipment_codec/proc/set_raid_provenance(obj/item/root, value)
	if (!(value in list(FALSE, TRUE))) return FALSE
	items = list()
	index = list()
	nodes = list()
	if (!collect(root, 0, 1))
		clear()
		return FALSE
	for (var/obj/item/I in items)
		if (!I.extraction_item_id) I.extraction_item_id = new_extraction_item_id()
		I.extraction_found_in_raid = value
	clear()
	return TRUE
