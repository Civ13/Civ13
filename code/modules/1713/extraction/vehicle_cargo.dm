// Cargo stays on actual boot tiles, with its existing nested equipment graph.
#define EXTRACTION_CAR_CARGO_ROOTS 8
#define EXTRACTION_CAR_CARGO_UNITS 32

/datum/extraction_vehicle_cargo
	var/last_error
	proc/encode(obj/structure/vehicleparts/axis/A, list/roots)
		if (!A || !get_turf(A) || !islist(roots) || roots.len > EXTRACTION_CAR_CARGO_ROOTS) return null
		var/list/entries = list()
		var/datum/extraction_equipment_codec/C = new
		var/turf/origin = get_turf(A)
		for (var/i in 1 to roots.len)
			var/obj/item/I = roots[i]
			if (!istype(I)) return null
			var/turf/T = get_turf(I)
			if (I.loc != T || !T || !(locate(/obj/structure/table/carboot) in T)) return null
			var/list/graph = C.encode(I)
			if (!graph) return null
			entries += list(list("id" = I.extraction_item_id, "equipment" = graph, "dx" = T.x - origin.x, "dy" = T.y - origin.y))
		return valid(entries) ? entries : null
	proc/valid(list/entries, list/part_nodes)
		if (!islist(entries) || entries.len > EXTRACTION_CAR_CARGO_ROOTS) return FALSE
		var/list/ids = list()
		var/units = 0
		var/nodes_count = 0
		var/datum/extraction_equipment_codec/C = new
		if (part_nodes)
			for (var/list/N in part_nodes) ids[N["id"]] = TRUE
		for (var/i in 1 to entries.len)
			var/list/E = entries[i]
			if (!islist(E) || !istext(E["id"]) || !isnum(E["dx"]) || !isnum(E["dy"]) || abs(E["dx"]) > 3 || abs(E["dy"]) > 3 || round(E["dx"]) != E["dx"] || round(E["dy"]) != E["dy"]) return FALSE
			var/list/graph = E["equipment"]
			if (!C.validate(graph) || graph["schema"] != 2 || graph["nodes"][1]["id"] != E["id"]) return FALSE
			if (part_nodes)
				var/boot = FALSE
				for (var/list/N in part_nodes)
					if (ispath(text2path(N["type"]), /obj/structure/table/carboot) && !N["parent"] && N["dx"] == E["dx"] && N["dy"] == E["dy"]) boot = TRUE
				if (!boot) return FALSE
			for (var/list/N in graph["nodes"])
				if (ids[N["id"]]) return FALSE
				ids[N["id"]] = TRUE
				var/path = text2path(N["type"])
				var/size = initial(path:w_class)
				if (!isnum(size) || size <= 0 || size > EXTRACTION_CAR_CARGO_UNITS) return FALSE
				units += size
				nodes_count++
			if (units > EXTRACTION_CAR_CARGO_UNITS || nodes_count > EXTRACTION_EQUIPMENT_NODES) return FALSE
		return TRUE
