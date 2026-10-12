// Solo vehicle ownership is debited in the same snapshot as carried equipment.
// The physical controller remains in the raid after death or session release.
/datum/extraction_session
	var/tmp/obj/structure/vehicleparts/axis/raid_vehicle
	var/tmp/list/raid_vehicle_parts = list()

/obj/map_metadata/extraction_survival
	var/list/raid_vehicles = list()

/datum/extraction_session/proc/plan_vehicle_raid(list/selected_ids, expected_revision, vehicle_id, vehicle_digest)
	if (!active() || profile["revision"] != expected_revision || !islist(profile["garage"]) || profile["garage"].len != 1) return null
	var/list/vehicle = profile["garage"][1]
	var/datum/extraction_vehicle_codec/C = new
	if (!C.validate(vehicle)) return null
	if (vehicle["id"] != vehicle_id || md5(json_encode(vehicle)) != vehicle_digest) return null
	var/list/plan = plan_raid(selected_ids, "PMC", expected_revision = expected_revision)
	if (!plan) return null
	var/list/candidate = plan["candidate"]
	candidate["garage"] = list()
	candidate["vehicle_issued"] = list("id" = vehicle_id, "sequence" = plan["sequence"], "digest" = vehicle_digest)
	plan["vehicle"] = json_decode(json_encode(vehicle))
	return plan

/datum/extraction_session/proc/credit_vehicle_extraction(sequence, list/loot, list/vehicle, obj/structure/vehicleparts/axis/source_vehicle)
	var/datum/extraction_vehicle_codec/C = new
	if (!C.validate(vehicle)) return FALSE
	if (!active() || profile["state"] != "raid" || sequence != profile["raid_sequence"] || !valid_entries(loot, 16) || !islist(profile["garage"]) || profile["garage"].len) return FALSE
	var/list/receipt = profile["vehicle_issued"]
	if (source_vehicle)
		var/obj/map_metadata/extraction_survival/M = map
		var/turf/source_turf = get_turf(source_vehicle)
		if (!istype(M) || M.accounts != service || !M.owned(body) || !M.raid_vehicles[source_vehicle] || !source_turf || source_turf.z != 1 || source_vehicle.extraction_vehicle_part_id != vehicle["id"] || json_encode(C.encode(source_vehicle)) != json_encode(vehicle)) return FALSE
	else if (!islist(receipt) || receipt["sequence"] != sequence || receipt["id"] != vehicle["id"]) return FALSE
	var/list/candidate = copy_profile()
	var/list/stash = candidate["stash"]
	for (var/list/entry in loot) stash += list(entry)
	if (!valid_entries(stash, capacity())) return FALSE
	candidate["garage"] = list(vehicle)
	if (!service.store.valid_garage(candidate["garage"]) || !islist(service.store.recovery_ids(candidate))) return FALSE
	if (!record_insurance_recovery(candidate, loot) || !record_insurance_recovery(candidate, vehicle["cargo"])) return FALSE
	if (!service.store.recovery_ownership_clear(owner, candidate)) return FALSE
	candidate["state"] = "home"
	candidate["vehicle_returned"] = list("id" = vehicle["id"], "sequence" = sequence)
	return commit(candidate)

/obj/map_metadata/extraction_survival/proc/vehicle_raid_destination(datum/extraction_vehicle_transfer/T)
	// Search a bounded radius around existing entry points, preserving map atoms.
	for (var/obj/effect/extraction_raid_marker/marker in extraction_raid_markers)
		for (var/turf/F in range(4, marker))
			if (F.z == 1 && T.destination_tiles(F)) return F
	return null

/obj/map_metadata/extraction_survival/proc/nearby_raid_vehicle(mob/living/human/H, obj/effect/extraction_exit/E)
	if (!owned(H) || !E.eligible(H)) return null
	var/obj/structure/vehicleparts/axis/preferred = H.extraction_session.raid_vehicle
	var/obj/structure/vehicleparts/axis/nearest
	var/nearest_distance = 5
	for (var/obj/structure/vehicleparts/axis/A in raid_vehicles)
		var/turf/T = get_turf(A)
		if (!T || T.z != 1 || get_dist(T, E) > 4) continue
		if (A == preferred) return A
		var/distance = get_dist(T, E)
		if (distance < nearest_distance)
			nearest = A
			nearest_distance = distance
	return nearest

/obj/map_metadata/extraction_survival/proc/deploy_vehicle(mob/living/human/H)
	if (!owned(H) || H.stat != CONSCIOUS || raid_vehicles.len >= 32) return FALSE
	var/datum/extraction_session/S = H.extraction_session
	if (S.transitioning || S.profile["state"] != "home" || !S.house || H.z != S.house.z || get_dist(H, S.house) > 4 || !save_home(S)) return FALSE
	var/obj/structure/vehicleparts/axis/A = S.garage_vehicle
	var/datum/extraction_vehicle_transfer/T = new
	if (!A || !T.capture(A, TRUE)) return FALSE
	var/list/carried = player_roots(H)
	var/list/graphs = records(carried)
	var/list/ids = list()
	if (!graphs || carried.len > 16) return FALSE
	var/nodes_count = 0
	for (var/list/entry in graphs)
		ids += entry["id"]
		nodes_count += entry["equipment"]["nodes"].len
	for (var/list/entry in T.cargo_record) nodes_count += entry["equipment"]["nodes"].len
	if (raid_items.len + nodes_count > 2048) return FALSE
	var/turf/destination = vehicle_raid_destination(T)
	if (!destination) return FALSE
	var/list/vehicle = S.profile["garage"][1]
	var/list/plan = S.plan_vehicle_raid(ids, S.profile["revision"], vehicle["id"], md5(json_encode(vehicle)))
	if (!plan) return FALSE
	S.transitioning = TRUE
	if (!S.commit(plan["candidate"]))
		S.transitioning = FALSE
		return FALSE
	if (!T.relocate(destination))
		S.locked = TRUE
		to_chat(H, "Vehicle transfer stopped after durable debit. This session is locked for recovery; the saved garage will not reissue the car.")
		return FALSE
	S.raid_vehicle = A
	S.raid_vehicle_parts = S.garage_parts.Copy()
	raid_vehicles[A] = S.raid_vehicle_parts.Copy()
	S.garage_vehicle = null
	S.garage_parts.Cut()
	leave_party(S.owner)
	for (var/obj/item/I in carried | T.cargo)
		codec.set_raid_provenance(I, FALSE)
		track_loot(I)
	H.forceMove(get_turf(pick(extraction_raid_markers)))
	H.status_flags &= ~GODMODE
	S.transitioning = FALSE
	to_chat(H, "Car and cargo deployed. Park near a vehicle extraction point, stop the engine and leave the seats before extracting. Failed raids forfeit this car.")
	return TRUE

/obj/map_metadata/extraction_survival/proc/extract_vehicle(mob/living/human/H, obj/effect/extraction_exit/E, obj/structure/vehicleparts/axis/chosen_vehicle)
	if (!E?.eligible(H) || E.forbid_backpack || istype(E, /obj/effect/extraction_exit/locked_room)) return FALSE
	var/datum/extraction_session/S = H.extraction_session
	var/obj/structure/vehicleparts/axis/A = chosen_vehicle ? chosen_vehicle : nearby_raid_vehicle(H, E)
	var/turf/vehicle_turf = get_turf(A)
	if (S.transitioning || !A || !raid_vehicles[A] || !vehicle_turf || get_dist(vehicle_turf, E) > 4 || vehicle_turf.z != 1) return FALSE
	var/datum/extraction_vehicle_transfer/T = new
	if (!T.capture(A, TRUE)) return FALSE
	S.transitioning = TRUE
	var/sequence = S.profile["raid_sequence"]
	to_chat(H, "Extracting with parked car. Stay next to this point for ten seconds.")
	if (!wait_for_extraction(H, E) || !E.eligible(H) || S.profile["raid_sequence"] != sequence || !raid_vehicles[A] || get_dist(get_turf(A), E) > 4)
		S.transitioning = FALSE
		return FALSE
	vehicle_turf = get_turf(A)
	if (!vehicle_turf || vehicle_turf.z != 1)
		S.transitioning = FALSE
		return FALSE
	var/list/vehicle = vehicle_codec.encode(A)
	var/list/loot = records(player_roots(H))
	if (!vehicle || !loot || !garage_record_fits(S, vehicle) || !T.capture(A, TRUE) || !T.destination_tiles(garage_anchor(S)))
		S.transitioning = FALSE
		return FALSE
	if (!S.credit_vehicle_extraction(sequence, loot, vehicle, A))
		S.transitioning = FALSE
		return FALSE
	if (!T.relocate(garage_anchor(S)))
		S.locked = TRUE
		to_chat(H, "Vehicle extraction saved but physical transfer stopped. This session is locked for recovery.")
		return FALSE
	S.garage_vehicle = A
	S.garage_parts = T.parts - T.cargo
	for (var/owner in accounts.sessions)
		var/datum/extraction_session/previous = accounts.sessions[owner]
		if (previous == S || previous.raid_vehicle == A)
			previous.raid_vehicle = null
			previous.raid_vehicle_parts.Cut()
	raid_vehicles -= A
	for (var/obj/item/I in player_roots(H) | T.cargo) raid_items -= I
	H.forceMove(get_turf(S.house))
	H.status_flags |= GODMODE
	S.transitioning = FALSE
	to_chat(H, "Car, cargo and carried equipment are committed to your private account.")
	return TRUE

/obj/map_metadata/extraction_survival/proc/retire_raid_vehicles()
	for (var/obj/structure/vehicleparts/axis/A in raid_vehicles)
		if (A.engine) A.engine.on = FALSE
		var/list/parts = raid_vehicles[A]
		for (var/obj/O in parts)
			for (var/obj/child in O.contents.Copy())
				if (child.extraction_vehicle_part_id) qdel(child)
			qdel(O)
	raid_vehicles.Cut()
