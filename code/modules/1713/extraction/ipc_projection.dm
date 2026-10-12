// Read-only saved graph projections. Never construct equipment or reveal tokens.
/proc/extraction_ipc_node_projection(list/node, index)
	var/list/scalars = node["scalars"]
	var/list/ammo_refs = list()
	for (var/key in list("ammo_magazine", "chambered"))
		if (key in node["refs"]) ammo_refs[key] = node["refs"][key]
	for (var/key in list("loaded", "stored_ammo"))
		if (key in node["lists"]) ammo_refs[key] = node["lists"][key]
	return list("index" = index, "id" = node["id"], "type" = node["type"], "parent" = node["parent"], "found_in_raid" = !!node["found_in_raid"], "condition" = list("health" = scalars["health"], "maxhealth" = scalars["maxhealth"]), "material_key" = scalars["material_key"], "amount" = scalars["amount"], "ammo_refs" = ammo_refs)

/proc/extraction_ipc_root_projection(list/entry)
	var/list/result = list("id" = entry["id"], "secure" = !!entry["secure"], "node_count" = 0, "root" = null)
	var/datum/extraction_equipment_codec/codec = new
	var/list/graph = entry["equipment"]
	if (graph?["schema"] != 2 || !codec.validate(graph))
		result["unavailable"] = TRUE
		return result
	result["node_count"] = length(graph["nodes"])
	result["root"] = extraction_ipc_node_projection(graph["nodes"][1], 1)
	return result

/proc/extraction_ipc_detail_projection(list/account, item_id, page)
	var/list/entry
	for (var/list/candidate in account["stash"])
		if (candidate["id"] == item_id) entry = candidate
	if (!islist(entry)) return null
	var/datum/extraction_equipment_codec/codec = new
	var/list/graph = entry["equipment"]
	if (graph?["schema"] != 2 || !codec.validate(graph)) return null
	var/list/nodes = list()
	var/start = page * 16 + 1
	var/total = length(graph["nodes"])
	for (var/i = start, i <= min(start + 15, total), i++)
		nodes += list(extraction_ipc_node_projection(graph["nodes"][i], i))
	return list("account_revision" = account["revision"], "graph_revision" = account["revision"], "item_id" = item_id, "total_nodes" = total, "nodes" = nodes, "next_page" = start + 16 <= total ? page + 1 : null)
