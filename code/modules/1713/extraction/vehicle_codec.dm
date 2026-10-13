// Account vehicles use an explicit bounded graph, never arbitrary world vars.
// Passengers, movement callbacks and external machinery references are omitted
// by policy or rejected before serialization, rather than restored as state.
/obj
	var/tmp/extraction_vehicle_part_id

/obj/effect/get_saved_vars()
	. = ..()
	if (extraction_vehicle_part_id) . |= "extraction_vehicle_part_id"

/datum/extraction_vehicle_codec
	var/last_error
	var/list/objects
	var/list/index
	proc/fail(message)
		last_error = message
		objects = null
		index = null
		return null
	proc/supported(path)
		if (ispath(path, /obj/structure/bed/chair)) return ispath(path, /obj/structure/bed/chair/drivers/car) || ispath(path, /obj/structure/bed/chair/carseat)
		return ispath(path, /obj/structure/vehicleparts/axis/car) || ispath(path, /obj/structure/vehicleparts/frame/car) || ispath(path, /obj/structure/vehicleparts/movement) || ispath(path, /obj/structure/vehicleparts/license_plate) || ispath(path, /obj/structure/engine/internal) || ispath(path, /obj/structure/bed/chair) || ispath(path, /obj/structure/table/carboot) || ispath(path, /obj/item/vehicleparts/wheel/modular) || ispath(path, /obj/item/weapon/reagent_containers/glass/barrel/fueltank) || path == /obj/effect/pseudovehicle
	proc/scalars(path)
		var/list/fields = list("name", "desc", "dir", "color", "icon_state", "anchored", "density", "opacity")
		if (ispath(path, /obj/structure/vehicleparts/axis)) fields |= list("vehicle_type", "speeds", "maxpower", "maxdist", "turntimer", "doorcode", "reg_number", "reverse", "keyed_vehicle_id", "key_generation")
		if (ispath(path, /obj/structure/vehicleparts/frame)) fields |= list("resistance", "doorcode", "noroof", "removesroof", "override_roof_icon", "override_frame_icon", "broken", "override_color", "hasoverlay")
		if (ispath(path, /obj/structure/vehicleparts/movement)) fields |= list("broken", "reversed", "ntype", "base_icon", "movement_icon", "type_name")
		if (ispath(path, /obj/structure/vehicleparts/license_plate)) fields |= "reg_number"
		if (ispath(path, /obj/structure/engine/internal)) fields |= list("engineclass", "broken", "weight", "maxpower", "torque", "fuelefficiency", "enginesize")
		return fields
	proc/references(path)
		var/list/fields = list()
		if (ispath(path, /obj/structure/vehicleparts/axis)) fields |= list("engine", "wheel")
		if (ispath(path, /obj/structure/vehicleparts/frame)) fields |= list("axis", "mwheel")
		if (ispath(path, /obj/structure/vehicleparts/movement)) fields |= list("axis", "connected")
		if (ispath(path, /obj/structure/vehicleparts/license_plate)) fields |= "axis"
		if (ispath(path, /obj/structure/engine/internal)) fields |= "fueltank"
		if (ispath(path, /obj/structure/bed/chair/drivers)) fields |= list("axis", "wheel")
		if (ispath(path, /obj/item/vehicleparts/wheel/modular)) fields |= "control"
		if (path == /obj/effect/pseudovehicle) fields |= "link"
		return fields
	proc/ref_lists(path)
		return ispath(path, /obj/structure/vehicleparts/axis) ? list("components", "wheels") : list()
	proc/value_lists(path)
		return ispath(path, /obj/structure/vehicleparts/frame) ? list("w_front", "w_back", "w_left", "w_right") : list()
	proc/config_fields(kind)
		if (kind == "wheel") return list("name", "type_name", "icon_state", "base_icon_state", "movement_icon_state", "base_speed", "armor", "max_health", "current_health", "position", "side", "is_reversed")
		return list("wall_type", "icon_state", "opacity", "density", "armor", "max_health", "current_health", "can_open", "is_open")
	proc/scalar_valid(key, value)
		if (key == "keyed_vehicle_id") return isnull(value) || (istext(value) && length(value) == 32 && ckey(value) == value)
		if (key == "key_generation") return isnum(value) && round(value) == value && value >= 0 && value <= 1000000
		var/list/text_fields = list("name", "desc", "color", "icon_state", "vehicle_type", "reg_number", "override_roof_icon", "override_frame_icon", "override_color", "hasoverlay", "ntype", "base_icon", "movement_icon", "type_name", "engineclass", "wall_type", "base_icon_state", "movement_icon_state", "position", "side")
		if (isnull(value)) return TRUE
		if (key in text_fields) return istext(value) && length(value) <= 2048
		return isnum(value) && abs(value) <= 1000000
	proc/plain(value, depth = 0)
		if (isnull(value) || isnum(value)) return isnull(value) || abs(value) <= 1000000
		if (istext(value)) return length(value) <= 2048
		if (!islist(value) || depth >= 4) return FALSE
		var/list/L = value
		if (L.len > 32) return FALSE
		for (var/key in L)
			if (!plain(key, depth + 1) || (!isnum(key) && !isnull(key) && !plain(L[key], depth + 1))) return FALSE
		return TRUE
	proc/config(datum/D, kind)
		var/list/result = list()
		for (var/key in config_fields(kind))
			if (!(key in D.vars) || !plain(D.vars[key]) || islist(D.vars[key])) return null
			result[key] = D.vars[key]
		return result
	proc/encode(obj/structure/vehicleparts/axis/A)
		last_error = null
		var/datum/extraction_vehicle_transfer/T = new
		if (!T.capture(A, TRUE)) return fail("Vehicle is not a stopped, unoccupied bounded car: [T.last_error]")
		objects = list(A)
		objects |= T.parts - T.cargo
		for (var/obj/O in T.parts)
			if (O in T.cargo) continue
			for (var/obj/child in O.contents)
				if (!istype(child, /atom/movable/lighting_overlay)) objects |= child
		if (objects.len > 128) return fail("Vehicle exceeds part budget")
		index = list()
		for (var/i in 1 to objects.len) index[objects[i]] = i
		var/list/nodes = list()
		for (var/obj/O in objects)
			if (!supported(O.type)) return fail("Unsupported vehicle part [O.type]")
			O.should_save = FALSE
			if (istype(O, /obj/structure/engine/internal))
				var/obj/structure/engine/internal/engine = O
				if (engine.connections.len) return fail("Engine has external power connections")
			if (!O.extraction_vehicle_part_id) O.extraction_vehicle_part_id = new_extraction_item_id()
			var/list/node = list("type" = "[O.type]", "id" = O.extraction_vehicle_part_id, "parent" = index[O.loc] ? index[O.loc] : 0)
			if (!node["parent"])
				if (O.loc != get_turf(O)) return fail("Vehicle parent is outside the graph")
				node["dx"] = O.x - T.origin.x
				node["dy"] = O.y - T.origin.y
			var/list/values = list()
			for (var/key in scalars(O.type))
				if (!(key in O.vars)) continue
				if (!plain(O.vars[key]) || islist(O.vars[key])) return fail("Unsupported vehicle scalar [key]")
				values[key] = O.vars[key]
			node["scalars"] = values
			var/list/refs = list()
			for (var/key in references(O.type))
				var/obj/target = O.vars[key]
				if (target && !index[target]) return fail("Vehicle reference [key] leaves the graph")
				refs[key] = target ? index[target] : 0
			node["refs"] = refs
			var/list/lists = list()
			for (var/key in ref_lists(O.type))
				var/list/result = list()
				for (var/obj/target in O.vars[key])
					if (!index[target]) return fail("Vehicle list [key] leaves the graph")
					result += index[target]
				lists[key] = result
			for (var/key in value_lists(O.type))
				if (!plain(O.vars[key])) return fail("Invalid wall state")
				lists[key] = O.vars[key].Copy()
			node["lists"] = lists
			if (istype(O, /obj/structure/vehicleparts/movement))
				var/obj/structure/vehicleparts/movement/W = O
				if (W.wconfig) node["wheel_config"] = config(W.wconfig, "wheel")
			if (istype(O, /obj/structure/vehicleparts/frame))
				var/obj/structure/vehicleparts/frame/F = O
				var/list/walls = list()
				for (var/side in list("front", "back", "left", "right")) walls[side] = config(F.walls.vars[side], "wall")
				node["walls"] = walls
			if (istype(O, /obj/item/weapon/reagent_containers/glass/barrel/fueltank))
				var/list/fuel = list()
				for (var/datum/reagent/R in O.reagents.reagent_list)
					if (!plain(R.data)) return fail("Unsupported fuel data")
					fuel += list(list("id" = R.id, "volume" = R.volume, "data" = R.data))
				node["fuel"] = fuel
				node["tank_capacity"] = O.reagents.maximum_volume
			nodes += list(node)
		var/list/record = list("schema" = 1, "id" = A.extraction_vehicle_part_id, "nodes" = nodes, "cargo" = T.cargo_record)
		objects = null
		index = null
		return validate(record) ? record : fail(last_error ? last_error : "Encoded vehicle failed schema validation")
	proc/config_valid(list/C, kind)
		if (!islist(C) || C.len != config_fields(kind).len) return FALSE
		for (var/key in C)
			if (!(key in config_fields(kind)) || !scalar_valid(key, C[key])) return !!fail("Invalid [kind] configuration field [key]")
		return TRUE
	proc/valid_index(value, count)
		return isnum(value) && round(value) == value && value >= 0 && value <= count
	proc/ref_type(key, path)
		switch (key)
			if ("axis", "link") return ispath(path, /obj/structure/vehicleparts/axis/car)
			if ("engine") return ispath(path, /obj/structure/engine/internal)
			if ("wheel") return ispath(path, /obj/item/vehicleparts/wheel/modular)
			if ("mwheel", "wheels") return ispath(path, /obj/structure/vehicleparts/movement)
			if ("fueltank") return ispath(path, /obj/item/weapon/reagent_containers/glass/barrel/fueltank)
			if ("connected", "control") return ispath(path, /obj/structure/vehicleparts/frame/car)
			if ("components") return ispath(path, /obj/structure/vehicleparts/frame/car) || path == /obj/effect/pseudovehicle
		return FALSE
	proc/validate(list/record)
		if (!islist(record) || record["schema"] != 1 || !islist(record["nodes"]) || length(json_encode(record)) > 524288) return FALSE
		var/list/nodes = record["nodes"]
		if (!nodes.len || nodes.len > 128 || !islist(nodes[1]) || !istext(nodes[1]["type"]) || nodes[1]["id"] != record["id"] || !ispath(text2path(nodes[1]["type"]), /obj/structure/vehicleparts/axis/car)) return FALSE
		var/list/ids = list()
		var/axes = 0
		// Check all nodes and parent indexes before following any graph edge.
		for (var/i in 1 to nodes.len)
			var/list/N = nodes[i]
			if (!islist(N) || !valid_index(N["parent"], nodes.len) || !istext(N["type"])) return FALSE
		for (var/i in 1 to nodes.len)
			var/list/N = nodes[i]
			if (!islist(N) || !istext(N["type"]) || !istext(N["id"]) || !length(N["id"]) || length(N["id"]) > 80 || ids[N["id"]]) return FALSE
			ids[N["id"]] = TRUE
			var/path = text2path(N["type"])
			if (!supported(path) || !valid_index(N["parent"], nodes.len)) return FALSE
			if (ispath(path, /obj/structure/vehicleparts/axis)) axes++
			var/parent = i
			for (var/depth in 1 to 9)
				parent = nodes[parent]["parent"]
				if (!parent) break
				if (!valid_index(parent, nodes.len) || parent == i || depth == 9) return FALSE
			if (!N["parent"] && (!isnum(N["dx"]) || !isnum(N["dy"]) || abs(N["dx"]) > 3 || abs(N["dy"]) > 3 || round(N["dx"]) != N["dx"] || round(N["dy"]) != N["dy"])) return FALSE
			var/list/S = N["scalars"]
			var/list/R = N["refs"]
			var/list/L = N["lists"]
			if (!islist(S) || !islist(R) || !islist(L)) return FALSE
			var/legacy_keys = ispath(path, /obj/structure/vehicleparts/axis) && !("keyed_vehicle_id" in S) && !("key_generation" in S)
			if (S.len != scalars(path).len - (legacy_keys ? 2 : 0)) return !!fail("Missing scalar state on [path]")
			if (ispath(path, /obj/structure/vehicleparts/axis) && !legacy_keys)
				if (S["keyed_vehicle_id"])
					if (S["keyed_vehicle_id"] != N["id"] || !vehicle_key_binding_valid(S["keyed_vehicle_id"], S["key_generation"])) return FALSE
				else if (S["key_generation"] != 0) return FALSE
			for (var/key in S)
				if (!(key in scalars(path)) || !scalar_valid(key, S[key])) return !!fail("Invalid scalar [key] on [path]")
			if (R.len != references(path).len || L.len != ref_lists(path).len + value_lists(path).len) return !!fail("Incorrect field count on [path]")
			for (var/key in references(path))
				if (!(key in R) || !valid_index(R[key], nodes.len) || (R[key] && !ref_type(key, text2path(nodes[R[key]]["type"])))) return !!fail("Invalid reference [key] on [path]")
			for (var/key in ref_lists(path))
				var/list/seen = list()
				if (!islist(L[key]) || !L[key].len || L[key].len > 16) return FALSE
				for (var/ref in L[key])
					if (!valid_index(ref, nodes.len) || !ref || seen["[ref]"] || !ref_type(key, text2path(nodes[ref]["type"]))) return FALSE
					seen["[ref]"] = TRUE
			for (var/key in value_lists(path))
				if (!islist(L[key]) || L[key].len < 7 || L[key].len > 8 || !plain(L[key])) return !!fail("Invalid wall list [key] on [path]")
				var/list/wall = L[key]
				if (!istext(wall[1])) return FALSE
				for (var/j in 2 to wall.len)
					if (!isnum(wall[j])) return FALSE
			if (!isnull(N["walls"]) && !ispath(path, /obj/structure/vehicleparts/frame)) return FALSE
			if (ispath(path, /obj/structure/vehicleparts/frame))
				if (!islist(N["walls"]) || N["walls"].len != 4) return FALSE
				for (var/side in list("front", "back", "left", "right"))
					if (!config_valid(N["walls"][side], "wall")) return FALSE
			if (!isnull(N["wheel_config"]) && (!ispath(path, /obj/structure/vehicleparts/movement) || !config_valid(N["wheel_config"], "wheel"))) return FALSE
			if ((!isnull(N["fuel"]) || !isnull(N["tank_capacity"])) && !ispath(path, /obj/item/weapon/reagent_containers/glass/barrel/fueltank)) return FALSE
			if (ispath(path, /obj/item/weapon/reagent_containers/glass/barrel/fueltank))
				if (!islist(chemical_reagents_list)) return FALSE
				if (!islist(N["fuel"]) || N["fuel"].len > 32 || !isnum(N["tank_capacity"]) || N["tank_capacity"] <= 0 || N["tank_capacity"] > 1000) return FALSE
				var/volume = 0
				var/list/fuels = list()
				for (var/fuel_index in 1 to N["fuel"].len)
					var/list/fuel = N["fuel"][fuel_index]
					if (!islist(fuel) || !istext(fuel["id"]) || !chemical_reagents_list[fuel["id"]] || fuels[fuel["id"]] || !isnum(fuel["volume"]) || fuel["volume"] <= 0 || !plain(fuel["data"])) return FALSE
					fuels[fuel["id"]] = TRUE
					volume += fuel["volume"]
				if (volume > N["tank_capacity"]) return FALSE
		if (axes != 1 || !nodes[1]["refs"]["engine"] || !nodes[1]["refs"]["wheel"]) return FALSE
		var/list/root_refs = nodes[1]["refs"]
		var/list/components = nodes[1]["lists"]["components"]
		var/list/wheels = nodes[1]["lists"]["wheels"]
		for (var/i in 1 to nodes.len)
			var/list/N = nodes[i]
			var/path = text2path(N["type"])
			var/list/R = N["refs"]
			var/parent = N["parent"]
			if (i == 1)
				if (!parent || !ispath(text2path(nodes[parent]["type"]), /obj/structure/vehicleparts/frame/car)) return FALSE
			else if (ispath(path, /obj/structure/vehicleparts/movement))
				if (R["axis"] != 1 || !parent || parent != R["connected"] || !(i in wheels)) return FALSE
			else if (ispath(path, /obj/item/vehicleparts/wheel/modular))
				if (i != root_refs["wheel"] || !parent || !ispath(text2path(nodes[parent]["type"]), /obj/structure/bed/chair/drivers/car) || !R["control"] || nodes[R["control"]]["refs"]["axis"] != 1) return FALSE
			else
				if (parent) return FALSE
				if (ispath(path, /obj/structure/vehicleparts/frame/car))
					if (R["axis"] != 1 || !(i in components)) return FALSE
				if (path == /obj/effect/pseudovehicle && (R["link"] != 1 || !(i in components))) return FALSE
				if (ispath(path, /obj/structure/vehicleparts/license_plate) && R["axis"] != 1) return FALSE
				if (ispath(path, /obj/structure/bed/chair/drivers) && (R["axis"] != 1 || R["wheel"] != root_refs["wheel"])) return FALSE
				if (ispath(path, /obj/structure/engine/internal) && (i != root_refs["engine"] || !R["fueltank"])) return FALSE
				if (ispath(path, /obj/item/weapon/reagent_containers/glass/barrel/fueltank) && i != nodes[root_refs["engine"]]["refs"]["fueltank"]) return FALSE
		if (!isnull(record["cargo"]))
			var/datum/extraction_vehicle_cargo/C = new
			if (!C.valid(record["cargo"], nodes)) return FALSE
		return TRUE
	proc/decode(list/record, turf/destination)
		if (!destination || !validate(record)) return null
		var/list/nodes = record["nodes"]
		var/list/targets = list()
		for (var/list/N in nodes)
			if (N["parent"]) continue
			var/turf/T = locate(destination.x + N["dx"], destination.y + N["dy"], destination.z)
			if (!istype(T, /turf/floor) || T.density) return null
			if (!(T in targets))
				for (var/atom/movable/O in T)
					if (!istype(O, /atom/movable/lighting_overlay)) return null
				targets += T
		var/list/created = list()
		for (var/list/N in nodes)
			var/path = text2path(N["type"])
			var/obj/O = new path(null)
			created += O
			O.should_save = FALSE
			for (var/atom/movable/child in O.contents.Copy())
				if (!istype(child, /atom/movable/lighting_overlay)) qdel(child)
		for (var/i in 1 to nodes.len)
			var/list/N = nodes[i]
			var/obj/O = created[i]
			O.extraction_vehicle_part_id = N["id"]
			for (var/key in N["scalars"]) O.vars[key] = N["scalars"][key]
			for (var/key in N["refs"]) O.vars[key] = N["refs"][key] ? created[N["refs"][key]] : null
			for (var/key in ref_lists(O.type))
				var/list/values = list()
				for (var/ref in N["lists"][key]) values += created[ref]
				O.vars[key] = values
			for (var/key in value_lists(O.type)) O.vars[key] = N["lists"][key].Copy()
			if (N["wheel_config"])
				var/obj/structure/vehicleparts/movement/W = O
				for (var/key in N["wheel_config"]) W.wconfig.vars[key] = N["wheel_config"][key]
			if (N["walls"])
				var/obj/structure/vehicleparts/frame/F = O
				for (var/side in N["walls"])
					var/datum/wall_config/C = F.walls.vars[side]
					for (var/key in N["walls"][side]) C.vars[key] = N["walls"][side][key]
			if (N["fuel"])
				O.reagents.clear_reagents()
				O.reagents.maximum_volume = N["tank_capacity"]
				for (var/list/fuel in N["fuel"]) O.reagents.add_reagent(fuel["id"], fuel["volume"], fuel["data"], safety = TRUE)
			O.loc = N["parent"] ? created[N["parent"]] : locate(destination.x + N["dx"], destination.y + N["dy"], destination.z)
		var/obj/structure/vehicleparts/axis/A = created[1]
		A.engine.key_axis = A
		A.engine.on = FALSE
		A.engine.icon = 'icons/obj/vehicles/vehicleparts.dmi'
		A.transporting.Cut()
		A.matrix_current_locs.Cut()
		A.check_corners()
		A.check_matrix()
		for (var/obj/O in created) O.update_icon()
		var/datum/extraction_equipment_codec/cargo_codec = new
		var/list/cargo_created = list()
		for (var/list/E in record["cargo"])
			var/obj/item/I = cargo_codec.decode(E["equipment"], locate(destination.x + E["dx"], destination.y + E["dy"], destination.z))
			if (!I)
				for (var/obj/item/root in cargo_created) qdel(root)
				for (var/obj/O in created) qdel(O)
				return null
			cargo_created += I
		return A
