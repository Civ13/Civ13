// Destination reservation records, not a player-facing transport switch.
// Admission reserves every tile in the three-wide footprint in one synchronous
// call. Network acceptance must wait for train_arrival_saved(). Movement into
// reserved tiles still needs the integration's global movement guards.
#define TRAIN_ARRIVAL_LIMIT 4
var/global/train_arrival_hold_reason = null

/obj/structure/region_gate/var/list/train_arrival_records = list()
/obj/structure/region_gate/var/tmp/list/train_arrival_durable = list()

/proc/train_arrival_decode(text)
	if(!istext(text) || length(text) > 300000) return null
	var/list/R
	try
		R = json_decode(text)
	catch
		return null
	if(!islist(R) || R.len != 9 || R["version"] != 1 || !istext(R["payload"]) || !train_route_valid_id(R["digest"]) || md5(R["payload"]) != R["digest"] || !train_route_valid_id(R["revision"]) || !train_route_valid_id(R["station"]) || !(R["heading"] in cardinal)) return null
	var/list/M = train_transfer_decode(R["payload"])
	if(!M || M["journey"] != R["journey"] || M["party"] != R["party"] || M["station"] != R["station"]) return null
	var/list/centres = R["centres"]
	if(!islist(centres) || centres.len != length(M["segments"]) || centres.len < 1 || centres.len > 64) return null
	var/list/last = null
	for(var/entry in centres)
		if(!islist(entry)) return null
		var/list/position = entry
		if(position.len != 3) return null
		for(var/value in position)
			if(!isnum(value) || value < 1 || value != round(value) || value > 65535) return null
		if(last)
			var/dx = R["heading"] == EAST ? -1 : (R["heading"] == WEST ? 1 : 0)
			var/dy = R["heading"] == NORTH ? -1 : (R["heading"] == SOUTH ? 1 : 0)
			if(position[1] != last[1] + dx || position[2] != last[2] + dy || position[3] != last[3]) return null
		last = position
	return R

// Keys are coordinates rather than turf refs so overlap survives save/reload.
/proc/train_arrival_footprint(list/R)
	var/list/result = list()
	var/side_x = R["heading"] in list(NORTH, SOUTH) ? 1 : 0
	var/side_y = side_x ? 0 : 1
	for(var/list/P in R["centres"])
		for(var/side = -1, side <= 1, side++)
			var/x = P[1] + side * side_x
			var/y = P[2] + side * side_y
			result["[x],[y],[P[3]]"] = TRUE
	return result

/proc/train_arrival_overlap(list/candidate, ignore_journey = null, ignore_digest = null)
	var/list/footprint = train_arrival_footprint(candidate)
	var/ignored = FALSE
	for(var/obj/structure/region_gate/S in region_gates)
		if(QDELETED(S)) continue
		if(!islist(S.train_arrival_records))
			train_arrival_hold_reason = "An arrival reservation list is unreadable."
			return TRUE
		for(var/text in S.train_arrival_records)
			var/list/R = train_arrival_decode(text)
			if(!R)
				train_arrival_hold_reason = "An arrival reservation is unreadable."
				return TRUE
			if(R["journey"] == ignore_journey && R["digest"] == ignore_digest)
				if(ignored) return TRUE
				ignored = TRUE
				continue
			if(R["journey"] == candidate["journey"]) return TRUE
			var/list/other = train_arrival_footprint(R)
			for(var/key in other)
				if(footprint[key]) return TRUE
	return FALSE

// Revalidate the reserved coordinates, not a freshly selected alternative strip.
/proc/train_arrival_clear(list/R)
	var/obj/structure/region_gate/S = train_route_station(R["station"], R["party"])
	if(!S || train_route_revision(S) != R["revision"]) return FALSE
	var/list/network = train_route_network(S)
	if(!islist(network)) return FALSE
	var/list/centres = R["centres"]
	var/list/tail = centres[centres.len]
	var/turf/edge = locate(tail[1], tail[2], tail[3])
	if(train_route_inward(edge) != R["heading"]) return FALSE
	for(var/list/P in centres)
		var/turf/T = locate(P[1], P[2], P[3])
		if(!T || !network[T] || !train_route_straight_rail(T, R["heading"])) return FALSE
		var/turf/left = get_step(T, turn(R["heading"], 90))
		var/turf/right = get_step(T, turn(R["heading"], -90))
		if(!left || !right) return FALSE
		for(var/turf/D in list(T, left, right))
			if(D.density) return FALSE
			for(var/atom/movable/A in D)
				if(isliving(A) || istype(A, /obj/structure/trains) || istype(A, /obj/structure/train_part) || (A.density && !istype(A, /obj/structure/rails))) return FALSE
	return TRUE

/obj/structure/region_gate/proc/train_arrival_after_load()
	train_arrival_durable = list()
	if(!islist(train_arrival_records) || train_arrival_records.len > TRAIN_ARRIVAL_LIMIT)
		train_arrival_hold_reason = "A saved arrival reservation list is invalid."
		return
	for(var/text in train_arrival_records)
		var/list/R = train_arrival_decode(text)
		if(!R || R["station"] != train_station_id || train_arrival_durable[R["journey"]])
			train_arrival_hold_reason = "A saved arrival reservation is invalid or duplicated."
			return
		train_arrival_durable[R["journey"]] = text

/proc/train_arrival_saved()
	for(var/obj/structure/region_gate/S in region_gates)
		if(!QDELETED(S)) S.train_arrival_after_load()

/obj/structure/region_gate/proc/train_arrival_reserve(payload, revision)
	if(train_arrival_hold_reason || !shard_group || !shard_group.enabled || QDELETED(src) || persistence_save_active() || !map || !map.uses_durable_metadata() || !should_save || !isturf(loc)) return null
	if(!islist(train_arrival_records)) return null
	var/list/M = train_transfer_decode(payload)
	if(!M || M["destination"] != shard_group.region || train_route_station(M["station"], M["party"]) != src || !train_route_valid_id(revision)) return null
	payload = json_encode(M)
	var/digest = md5(payload)
	for(var/text in train_arrival_records)
		var/list/existing = train_arrival_decode(text)
		if(!existing) return null
		if(existing["journey"] == M["journey"])
			if(existing["digest"] != digest || existing["revision"] != revision) return null
			return train_arrival_validate(M["journey"], digest, FALSE)
	if(train_arrival_records.len >= TRAIN_ARRIVAL_LIMIT) return null
	var/list/placement = train_route_arrival_centres(M["station"], M["party"], length(M["segments"]), revision)
	if(!placement) return null
	var/list/coordinates = list()
	for(var/turf/T in placement["centres"])
		coordinates += list(list(T.x, T.y, T.z))
	var/list/R = list("version" = 1, "journey" = M["journey"], "digest" = digest, "payload" = payload, "station" = M["station"], "party" = M["party"], "revision" = revision, "centres" = coordinates, "heading" = placement["heading"])
	var/text = json_encode(R)
	if(!train_arrival_decode(text) || train_arrival_overlap(R) || !train_arrival_clear(R)) return null
	train_arrival_records += text
	train_arrival_durable -= M["journey"]
	return R

/obj/structure/region_gate/proc/train_arrival_validate(journey, digest, require_saved = TRUE)
	if(train_arrival_hold_reason || QDELETED(src) || persistence_save_active() || !islist(train_arrival_records) || !islist(train_arrival_durable)) return null
	for(var/text in train_arrival_records)
		var/list/R = train_arrival_decode(text)
		if(!R) return null
		if(R["journey"] != journey || R["digest"] != digest) continue
		if(R["station"] != train_station_id || (require_saved && train_arrival_durable[journey] != text)) return null
		if(train_arrival_overlap(R, journey, digest) || !train_arrival_clear(R)) return null
		return R
	return null

// Caller must establish authoritative abort/commit resolution before release.
// This only releases geometry; it never deletes or returns transferred objects.
/obj/structure/region_gate/proc/train_arrival_release(journey, digest)
	if(QDELETED(src) || persistence_save_active() || !islist(train_arrival_records)) return FALSE
	for(var/text in train_arrival_records)
		var/list/R = train_arrival_decode(text)
		if(!R) return FALSE
		if(R["journey"] == journey && R["digest"] == digest)
			train_arrival_records -= text
			train_arrival_durable -= journey
			return TRUE
	return FALSE

#undef TRAIN_ARRIVAL_LIMIT
