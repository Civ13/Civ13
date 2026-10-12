// A materialized private car remains part of the same account snapshot as gear.
// Acquisition and raid ownership transitions are separate guarded operations.
/datum/extraction_session
	var/tmp/obj/structure/vehicleparts/axis/garage_vehicle
	var/tmp/list/garage_parts = list()

/obj/map_metadata/extraction_survival
	var/datum/extraction_vehicle_codec/vehicle_codec = new

/obj/map_metadata/extraction_survival/proc/garage_anchor(datum/extraction_session/S)
	if (!S.house) return null
	return locate(S.house.x - 2, S.house.y - 2, S.house.z)

/obj/map_metadata/extraction_survival/proc/garage_record_fits(datum/extraction_session/S, list/record)
	if (!S.house || !vehicle_codec.validate(record)) return FALSE
	var/turf/anchor = garage_anchor(S)
	for (var/list/node in record["nodes"])
		if (node["parent"]) continue
		var/turf/T = locate(anchor.x + node["dx"], anchor.y + node["dy"], anchor.z)
		if (!istype(T, /turf/floor/plating/extraction_house) || get_dist(T, S.house) > 4 || T == get_turf(S.house) || T == get_turf(house_crate(S))) return FALSE
	return TRUE

/obj/map_metadata/extraction_survival/proc/restore_garage(datum/extraction_session/S)
	var/list/garage = S.profile["garage"]
	if (isnull(garage) || !garage.len) return TRUE
	if (S.garage_vehicle || S.garage_parts.len || garage.len != 1 || !garage_record_fits(S, garage[1])) return FALSE
	var/obj/structure/vehicleparts/axis/A = vehicle_codec.decode(garage[1], garage_anchor(S))
	if (!A) return FALSE
	var/datum/extraction_vehicle_transfer/T = new
	if (!T.capture(A, TRUE))
		// Decode has validated a closed car graph. Retire every created top atom
		// by its committed part identity if constructor behavior changed anyway.
		var/list/ids = list()
		for (var/list/node in garage[1]["nodes"]) ids[node["id"]] = TRUE
		var/list/cargo_ids = list()
		for (var/list/entry in garage[1]["cargo"]) cargo_ids[entry["id"]] = TRUE
		for (var/turf/F in range(4, S.house))
			for (var/obj/O in F)
				if (ids[O.extraction_vehicle_part_id])
					for (var/obj/child in O.contents.Copy())
						if (ids[child.extraction_vehicle_part_id]) qdel(child)
					qdel(O)
				else if (istype(O, /obj/item) && cargo_ids[O:extraction_item_id]) qdel(O)
		return FALSE
	S.garage_vehicle = A
	S.garage_parts = T.parts - T.cargo
	return TRUE

/obj/map_metadata/extraction_survival/proc/garage_snapshot(datum/extraction_session/S)
	if (!S.garage_vehicle) return S.garage_parts.len ? null : list()
	var/obj/structure/vehicleparts/axis/A = S.garage_vehicle
	if (!A.loc || !S.house || get_turf(A) != garage_anchor(S)) return null
	var/list/record = vehicle_codec.encode(A)
	if (!record || !garage_record_fits(S, record)) return null
	var/datum/extraction_vehicle_transfer/T = new
	if (!T.capture(A, TRUE)) return null
	var/list/parts = T.parts - T.cargo
	if (parts.len != S.garage_parts.len) return null
	for (var/obj/O in parts)
		if (!(O in S.garage_parts)) return null
	return list(record)

/obj/map_metadata/extraction_survival/proc/retire_garage(datum/extraction_session/S)
	var/datum/extraction_vehicle_transfer/T = new
	if (S.garage_vehicle && T.capture(S.garage_vehicle, TRUE))
		for (var/obj/item/I in T.cargo) qdel(I)
	for (var/obj/O in S.garage_parts.Copy())
		for (var/obj/child in O.contents.Copy())
			if (child.extraction_vehicle_part_id) qdel(child)
		qdel(O)
	S.garage_parts.Cut()
	S.garage_vehicle = null

/obj/map_metadata/extraction_survival/proc/garage_cargo_turf(datum/extraction_session/S, turf/T)
	if (!S.garage_vehicle) return FALSE
	for (var/obj/structure/table/carboot/B in S.garage_parts)
		if (get_turf(B) == T) return TRUE
	return FALSE
