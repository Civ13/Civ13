// Cargo stays on actual boot tiles, with its existing nested equipment graph.
#define EXTRACTION_CAR_CARGO_ROOTS 8
#define EXTRACTION_CAR_CARGO_UNITS 32

/datum/extraction_vehicle_cargo
	var/last_error
	// Installed generators are not portable cargo. Reject before codec collection,
	// which otherwise refreshes their live generator_broken field.
	proc/collect_members(obj/item/I, list/members, list/seen, depth, datum/extraction_equipment_codec/C)
		if (!I || !C.supported(I.type) || seen[I] || members.len >= EXTRACTION_EQUIPMENT_NODES || depth > EXTRACTION_EQUIPMENT_DEPTH) return FALSE
		if (I.type == /obj/item/extraction_generator_kit)
			var/obj/item/extraction_generator_kit/G = I
			if (G.engine) return FALSE
		seen[I] = TRUE
		members += I
		if (I.type == /obj/item/extraction_wheel_crate)
			var/obj/item/extraction_wheel_crate/W = I
			if (!W.wheel || W.wheel.loc != W || seen[W.wheel] || members.len >= EXTRACTION_EQUIPMENT_NODES) return FALSE
			seen[W.wheel] = TRUE
			members += W.wheel
			return TRUE
		for (var/atom/movable/child in I.contents)
			if (!istype(child, /obj/item) || !collect_members(child, members, seen, depth + 1, C)) return FALSE
		return TRUE
	// Issuance is explicit at callers. Validation passes FALSE and never mints IDs.
	proc/encode(obj/structure/vehicleparts/axis/A, list/roots, assign_new_ids = FALSE, list/roster, mutate_persistence = FALSE)
		if (!A || !get_turf(A) || !islist(roots) || roots.len > EXTRACTION_CAR_CARGO_ROOTS) return null
		var/list/entries = list()
		var/datum/extraction_equipment_codec/C = new
		var/list/seen = list()
		var/list/members = list()
		var/turf/origin = get_turf(A)
		for (var/i in 1 to roots.len)
			var/obj/item/I = roots[i]
			if (!istype(I)) return null
			var/turf/T = get_turf(I)
			if (I.loc != T || !T || !(locate(/obj/structure/table/carboot) in T)) return null
			var/member_start = members.len + 1
			if (!collect_members(I, members, seen, 1, C)) return null
			var/list/graph = C.encode(I, assign_new_ids, mutate_persistence)
			if (!graph) return null
			if (roster)
				for (var/member_index in member_start to members.len)
					var/atom/movable/member = members[member_index]
					var/list/refs = list()
					for (var/key in C.reference_fields(member.type))
						if (key in member.vars) refs[key] = member.vars[key]
					var/list/edges = list()
					for (var/key in C.list_fields(member.type))
						if (!(key in member.vars)) continue
						var/list/value = member.vars[key]
						edges[key] = value ? value.Copy() : list()
					roster += list(list("item" = member, "parent" = member.loc, "refs" = refs, "edges" = edges))
			entries += list(list("id" = I.extraction_item_id, "equipment" = graph, "dx" = T.x - origin.x, "dy" = T.y - origin.y))
		return valid(entries) ? entries : null
	proc/same_roster(list/captured, list/current)
		if (!islist(captured) || !islist(current) || captured.len != current.len || current.len > EXTRACTION_EQUIPMENT_NODES) return FALSE
		for (var/i in 1 to captured.len)
			var/list/old = captured[i]
			var/list/live = current[i]
			if (old["item"] != live["item"] || old["parent"] != live["parent"]) return FALSE
			var/list/old_refs = old["refs"]
			var/list/live_refs = live["refs"]
			if (old_refs.len != live_refs.len) return FALSE
			for (var/key in old_refs)
				if (!(key in live_refs) || old_refs[key] != live_refs[key]) return FALSE
			var/list/old_edges = old["edges"]
			var/list/live_edges = live["edges"]
			if (old_edges.len != live_edges.len) return FALSE
			for (var/key in old_edges)
				if (!(key in live_edges)) return FALSE
				var/list/old_list = old_edges[key]
				var/list/live_list = live_edges[key]
				if (old_list.len != live_list.len) return FALSE
				for (var/j in 1 to old_list.len)
					if (old_list[j] != live_list[j]) return FALSE
		return TRUE
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
