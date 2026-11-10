// Bounded physical train wire codec. No arbitrary vars or type construction.
// Capture never deletes objects. The caller owns freezing and ledger custody.
#define TRAIN_TRANSFER_SEGMENTS 64
#define TRAIN_TRANSFER_ENTITIES 256
#define TRAIN_TRANSFER_TEXT 200000
#define TRAIN_TRANSFER_CRATE_ITEMS 60

/atom/movable/var/train_transfer_id = null
// Stable train identity is distinct from a particular trip. A stale replay may
// only remove roots still carrying its exact journey tag.
/atom/movable/var/train_transfer_journey = null
/atom/movable/var/train_transfer_digest = null
/obj/structure/trains/var/train_transfer_built = FALSE

/proc/train_transfer_path(text)
	var/static/list/paths = list(/obj/structure/trains, /obj/structure/trains/storage, /obj/structure/trains/storage/miningcart, /obj/structure/trains/storage/tender, /obj/structure/trains/storage/closed, /obj/structure/trains/transport, /obj/structure/trains/transport/flatbed, /obj/structure/trains/transport/cabin, /obj/structure/trains/locomotive, /obj/structure/trains/locomotive/coal, /obj/structure/trains/platform)
	for(var/path in paths)
		if(text == "[path]") return path
	return null

/proc/train_transfer_fitting_path(text)
	var/static/list/paths = list(/obj/structure/bed, /obj/structure/bed/chair/comfy/blue, /obj/structure/bed/chair/comfy/diner_booth, /obj/structure/table/modern/table)
	for(var/path in paths)
		if(text == "[path]") return path
	return null

/proc/train_transfer_number(value, lo, hi)
	return isnum(value) && value >= lo && value <= hi && value == round(value)

/proc/train_transfer_string(value, limit = 100)
	return istext(value) && length(value) > 0 && length(value) <= limit

// Explicit projection for bounded fittings. Unknown durable fields refuse,
// instead of silently resetting a customized structure to its type defaults.
/proc/train_transfer_structure_fields(path)
	var/list/fields = list("name", "desc", "dir", "color", "icon_state", "anchored", "density", "opacity", "pixel_x", "pixel_y", "layer", "flammable")
	if(path == /obj/structure/closet/crate)
		fields |= list("opened", "welded", "health", "storage_capacity", "custom_code", "locked", "rigged", "storagecap", "icon_closed", "icon_opened", "store_misc", "store_items", "store_mobs", "wall_mounted")
	else if(ispath(path, /obj/structure/bed) && train_transfer_fitting_path("[path]"))
		fields |= list("material", "padding_material", "base_icon", "applies_material_colour", "can_buckle", "buckle_dir", "buckle_lying", "persistence_bed_owner_ckey")
	else if(!train_transfer_fitting_path("[path]"))
		return null
	return fields

/proc/train_transfer_structure_state_valid(path, list/state)
	var/list/fields = train_transfer_structure_fields(path)
	if(!fields || !islist(state) || state.len != fields.len) return FALSE
	for(var/key in fields)
		if(!(key in state)) return FALSE
		var/value = state[key]
		if(key in list("material", "padding_material"))
			if(isnull(value) && key == "padding_material") continue
			if(!istext(value) || !istype(get_material_by_name(value), /material)) return FALSE
		else if(key == "persistence_bed_owner_ckey")
			if(!isnull(value) && !persistence_owner_valid(value)) return FALSE
		else if(key in list("name", "desc", "color", "icon_state", "base_icon", "icon_closed", "icon_opened"))
			if(!isnull(value) && (!istext(value) || length(value) > 2048)) return FALSE
		else if(!isnum(value) || abs(value) > 1000000)
			return FALSE
	return TRUE

/proc/train_transfer_structure_state(obj/structure/A)
	if(!A || QDELETED(A) || A.buckled_mob) return null
	var/list/fields = train_transfer_structure_fields(A.type)
	if(!fields) return null
	if(istype(A, /obj/structure/closet))
		var/obj/structure/closet/C = A
		if(C.breakout) return null
	var/list/ignored = list("train_transfer_id", "train_transfer_journey", "train_transfer_digest", "loc", "locs", "pixloc", "contents", "x", "y", "z")
	for(var/key in A.get_saved_vars())
		if(!(key in fields) && !(key in ignored)) return null
	var/list/state = list()
	for(var/key in fields)
		if(!(key in A.vars)) return null
		var/value = A.vars[key]
		if(key in list("material", "padding_material"))
			var/material/M = value
			if(istype(M) && get_material_by_name(M.name) != M) return null
			state[key] = istype(M) ? M.name : null
		else
			state[key] = value
	return train_transfer_structure_state_valid(A.type, state) ? state : null

/proc/train_transfer_apply_structure_state(obj/structure/A, list/state)
	if(!A || !train_transfer_structure_state_valid(A.type, state)) return FALSE
	for(var/key in train_transfer_structure_fields(A.type))
		var/value = state[key]
		A.vars[key] = (key in list("material", "padding_material")) ? (isnull(value) ? null : get_material_by_name(value)) : value
	if(istype(A, /obj/structure/bed))
		var/obj/structure/bed/B = A
		B.update_icon()
		// update_icon regenerates labels; custom saved labels remain authoritative.
		B.name = state["name"]
		B.desc = state["desc"]
		B.icon_state = state["icon_state"]
	return TRUE

// API result: error, or manifest plus live cars/loads for a caller-owned freeze.
/proc/train_transfer_capture(obj/structure/trains/head, party, source, destination, station, journey = null)
	// Final recapture must retain the journey already bound by the prelease.
	if(!isnull(journey) && !train_transfer_string(journey)) return list("error" = "Invalid train journey identity.")
	if(!isnull(journey))
		for(var/i = 1, i <= length(journey), i++)
			if(!findtext("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_.:@-", copytext(journey, i, i + 1))) return list("error" = "Invalid train journey identity.")
	if(!istype(head) || !party_train_valid_party(party)) return list("error" = "No valid train owner.")
	var/list/cars = list()
	var/obj/structure/trains/car = head
	while(car)
		if(car in cars || cars.len >= TRAIN_TRANSFER_SEGMENTS) return list("error" = "The consist is cyclic or too long.")
		if(!train_transfer_path("[car.type]") || !isturf(car.loc) || length(car.contents)) return list("error" = "This car or its contained load cannot travel yet.")
		if(car.health <= 0) return list("error" = "Repair the train before travelling.")
		if(istype(car, /obj/structure/trains/platform))
			var/obj/structure/trains/platform/P = car
			if(P.braced || P.wrecked) return list("error" = "Unbrace and repair the train first.")
		if(cars.len)
			var/obj/structure/trains/previous = cars[cars.len]
			if(car.dir != head.dir || car.loc != get_step(previous, turn(head.dir, 180))) return list("error" = "Stage the whole train on straight track before travelling.")
		cars += car
		car = car.connected
	if(!head.train_transfer_id)
		head.train_transfer_id = md5("[source]-[world.realtime]-[rand(1, 1000000000)]-\ref[head]")
	var/id = head.train_transfer_id
	if(isnull(journey))
		journey = md5("[id]-[source]-[destination]-[world.realtime]-[rand(1, 1000000000)]")
	var/list/M = list("kind" = "train", "version" = 1, "id" = id, "journey" = journey, "party" = party, "source" = source, "destination" = destination, "station" = station, "segments" = list(), "entities" = list(), "accounts" = list())
	var/list/segments = M["segments"]
	var/list/entities = M["entities"]
	var/list/accounts = M["accounts"]
	var/list/loads = list()
	var/list/claimed = list()
	for(var/i = 1, i <= cars.len, i++)
		car = cars[i]
		var/list/S = list("id" = "[id]:s[i]", "type" = "[car.type]", "dir" = car.dir, "health" = car.health, "on" = !!car.on, "fuel" = 0, "car_kind" = "", "car_id" = "", "seg_index" = 0, "open_doors" = 0)
		var/list/tiles = list(null, car.loc, null)
		if(istype(car, /obj/structure/trains/locomotive))
			var/obj/structure/trains/locomotive/L = car
			S["fuel"] = L.fuel
		if(istype(car, /obj/structure/trains/platform))
			var/obj/structure/trains/platform/P = car
			S["car_kind"] = P.car_kind
			S["car_id"] = P.car_id
			S["seg_index"] = P.seg_index
			S["open_doors"] = P.open_doors
			tiles = train_platform_tiles(car.loc, car.dir)
		segments += list(S)
		for(var/slot in list(2, 1, 3))
			var/turf/T = tiles[slot]
			if(!T) continue
			if(slot != 2 && train_centre_of_other(T, car)) continue
			for(var/atom/movable/A in T)
				if(A in cars || istype(A, /obj/structure/train_part) || claimed[A] || !train_platform_carries(A)) continue
				if(entities.len >= TRAIN_TRANSFER_ENTITIES) return list("error" = "Too many objects aboard.")
				var/list/E = list("id" = "[id]:e[entities.len + 1]", "segment" = i, "slot" = slot, "dir" = A.dir, "anchored" = !!A.anchored)
				if(istype(A, /mob/living/human))
					var/mob/living/human/H = A
					if(H.client) H.record_persistence_owner()
					if(!persistence_owner_valid(H.persistence_owner_ckey) || H.stat != CONSCIOUS || H.health < H.maxHealth || H.restrained() || H.buckled || H.pulling) return list("error" = "All riders must be healthy, unrestrained and unbuckled account-owned characters.")
					if(H.persistence_owner_ckey in accounts) return list("error" = "Duplicate account aboard.")
					var/items = H.region_travel_items()
					if(istext(items)) return list("error" = items)
					E["kind"] = "character"
					E["payload"] = H.region_travel_payload(items, party)
					accounts += H.persistence_owner_ckey
				else if(istype(A, /obj/item))
					E["kind"] = "item"
					E["payload"] = party_freight_encode_item(A)
					if(!E["payload"]) return list("error" = "An item aboard cannot be preserved by the freight codec.")
				else if(istype(A, /obj/structure/closet/crate))
					var/obj/structure/closet/crate/C = A
					if(C.type != /obj/structure/closet/crate || C.opened) return list("error" = "Close cargo crates before travelling.")
					var/list/entries = list()
					for(var/atom/movable/inside in C)
						if(!istype(inside, /obj/item) || entries.len >= TRAIN_TRANSFER_CRATE_ITEMS) return list("error" = "A crate contains an unsupported load.")
						var/list/entry = party_freight_encode_item(inside)
						if(!entry) return list("error" = "A crate item cannot be preserved.")
						entries += list(entry)
					E["kind"] = "crate"
					var/list/state = train_transfer_structure_state(C)
					if(!state) return list("error" = "A crate has unsupported custom state.")
					E["payload"] = list("type" = "[C.type]", "items" = entries, "state" = state)
				else if(train_transfer_fitting_path("[A.type]") && !length(A.contents))
					var/list/state = train_transfer_structure_state(A)
					if(!state) return list("error" = "A fitting has unsupported custom state or is occupied.")
					E["kind"] = "fitting"
					E["payload"] = list("type" = "[A.type]", "state" = state)
				else
					return list("error" = "[A.name] cannot travel in a physical train yet.")
				claimed[A] = TRUE
				loads += A
				entities += list(E)
	if(!train_transfer_decode(json_encode(M))) return list("error" = "The train manifest is unsupported or too large.")
	var/digest = md5(json_encode(M))
	for(var/atom/movable/A in cars + loads)
		A.train_transfer_id = id
		A.train_transfer_journey = journey
		A.train_transfer_digest = digest
	for(var/obj/structure/trains/C in cars) C.train_transfer_built = FALSE
	return list("manifest" = M, "cars" = cars, "loads" = loads)

/proc/train_transfer_decode(text)
	if(!istext(text) || length(text) > TRAIN_TRANSFER_TEXT) return null
	var/list/M
	try
		M = json_decode(text)
	catch
		return null
	if(!islist(M) || M["kind"] != "train" || M["version"] != 1 || !train_transfer_string(M["id"]) || !party_train_valid_party(M["party"])) return null
	for(var/key in list("journey", "source", "destination", "station"))
		if(!train_transfer_string(M[key])) return null
	var/list/segments = M["segments"]
	var/list/entities = M["entities"]
	var/list/accounts = M["accounts"]
	if(!islist(segments) || !segments.len || segments.len > TRAIN_TRANSFER_SEGMENTS || !islist(entities) || entities.len > TRAIN_TRANSFER_ENTITIES || !islist(accounts)) return null
	var/list/ids = list()
	for(var/list/S in segments)
		if(!islist(S) || !train_transfer_string(S["id"]) || S["id"] in ids) return null
		ids += S["id"]
		var/path = train_transfer_path(S["type"])
		if(!path || !(S["dir"] in cardinal) || !train_transfer_number(S["health"], 1, 1500) || !(S["on"] in list(FALSE, TRUE)) || !train_transfer_number(S["fuel"], 0, 100)) return null
		if(path == /obj/structure/trains/platform)
			if(!train_car_layout(S["car_kind"]) || !train_transfer_string(S["car_id"]) || !train_transfer_number(S["seg_index"], 1, 4) || !train_transfer_number(S["open_doors"], 0, 65535)) return null
		else if(S["car_kind"] != "" || S["car_id"] != "" || S["seg_index"] != 0 || S["open_doors"] != 0)
			return null
	// A platform is a complete four-segment car, never a truncated prefix.
	for(var/i = 1, i <= segments.len, i++)
		var/list/S = segments[i]
		if(S["type"] != "/obj/structure/trains/platform") continue
		if(S["seg_index"] != 1 || i + 3 > segments.len) return null
		for(var/j = 1, j <= 4, j++)
			var/list/part = segments[i + j - 1]
			if(part["type"] != S["type"] || part["seg_index"] != j || part["car_id"] != S["car_id"] || part["car_kind"] != S["car_kind"]) return null
		i += 3
	var/list/owners = list()
	for(var/list/E in entities)
		if(!islist(E) || !train_transfer_string(E["id"]) || E["id"] in ids || !train_transfer_number(E["segment"], 1, segments.len) || !train_transfer_number(E["slot"], 1, 3) || !(E["dir"] in cardinal) || !(E["anchored"] in list(FALSE, TRUE))) return null
		ids += E["id"]
		var/list/S = segments[E["segment"]]
		if(S["type"] != "/obj/structure/trains/platform" && E["slot"] != 2) return null
		switch(E["kind"])
			if("character")
				var/list/P = region_travel_decode(E["payload"])
				if(!P || P["owner"] in owners || P["party"] != M["party"]) return null
				owners += P["owner"]
			if("item")
				if(!party_freight_entry_valid(E["payload"])) return null
			if("crate")
				var/list/P = E["payload"]
				if(!islist(P) || !istext(P["type"]) || P["type"] != "/obj/structure/closet/crate" || !islist(P["items"]) || length(P["items"]) > TRAIN_TRANSFER_CRATE_ITEMS || !train_transfer_structure_state_valid(/obj/structure/closet/crate, P["state"])) return null
				for(var/list/entry in P["items"])
					if(!party_freight_entry_valid(entry)) return null
			if("fitting")
				var/list/P = E["payload"]
				if(!islist(P) || !train_transfer_fitting_path(P["type"]) || !train_transfer_structure_state_valid(train_transfer_fitting_path(P["type"]), P["state"])) return null
			else
				return null
	if(accounts.len != owners.len) return null
	var/list/checked_accounts = list()
	for(var/account in accounts)
		if(!(account in owners) || account in checked_accounts) return null
		checked_accounts += account
	return M

// Build only after the caller has reserved all arrival deck tiles. Repeated
// delivery returns the existing consist, never constructs another train.
/proc/train_transfer_build(list/M, list/centres, heading = null)
	M = train_transfer_decode(json_encode(M))
	if(!M || !islist(centres) || centres.len != length(M["segments"])) return null
	// Digest is a local idempotency witness, not a network authentication proof.
	var/digest = md5(json_encode(M))
	var/found_partial = FALSE
	var/obj/structure/trains/completed_head = null
	for(var/atom/movable/existing in world)
		if(existing.train_transfer_id != M["id"]) continue
		if(existing.train_transfer_journey != M["journey"] || existing.train_transfer_digest != digest) return null
		found_partial = TRUE
		if(istype(existing, /obj/structure/trains))
			var/obj/structure/trains/car = existing
			if(car.train_transfer_built)
				if(completed_head) return null
				completed_head = car
	if(completed_head) return completed_head
	if(found_partial) return null
	// region_travel_build can clear another body's account ownership. Refuse
	// that conflict before constructing anything, rather than trying to undo it.
	for(var/mob/living/human/existing_body in human_mob_list)
		if(!QDELETED(existing_body) && existing_body.persistence_owner_ckey in M["accounts"]) return null
	var/list/first_segment = M["segments"][1]
	if(isnull(heading)) heading = first_segment["dir"]
	if(!(heading in cardinal)) return null
	var/list/angles = list("1" = 0, "2" = 180, "4" = -90, "8" = 90)
	var/rotation = angles["[heading]"] - angles["[first_segment["dir"]]"]
	var/list/cars = list()
	var/list/built = list()
	var/list/segments = M["segments"]
	// Validate the complete footprint before constructing even the first car.
	for(var/i = 1, i <= segments.len, i++)
		var/turf/T = centres[i]
		if(!isturf(T)) return null
		var/list/S = segments[i]
		var/list/tiles = train_platform_tiles(T, heading)
		if(S["type"] == "/obj/structure/trains/platform" && (!tiles[1] || !tiles[3])) return null
	for(var/i = 1, i <= segments.len, i++)
		var/list/S = segments[i]
		var/path = train_transfer_path(S["type"])
		var/turf/T = centres[i]
		if(!isturf(T)) return null
		var/obj/structure/trains/car = new path(T)
		built += car
		car.train_transfer_id = M["id"]
		car.train_transfer_journey = M["journey"]
		car.train_transfer_digest = digest
		car.dir = heading
		car.health = S["health"]
		car.on = FALSE
		car.automovement = FALSE
		if(istype(car, /obj/structure/trains/locomotive))
			var/obj/structure/trains/locomotive/L = car
			L.fuel = S["fuel"]
		if(istype(car, /obj/structure/trains/platform))
			var/obj/structure/trains/platform/P = car
			P.car_kind = S["car_kind"]
			P.car_id = S["car_id"]
			P.seg_index = S["seg_index"]
			P.open_doors = S["open_doors"]
			P.apply_layout()
		if(cars.len)
			var/obj/structure/trains/previous = cars[cars.len]
			previous.connected = car
		cars += car
	for(var/list/E in M["entities"])
		var/obj/structure/trains/car = cars[E["segment"]]
		var/list/tiles = train_platform_tiles(car.loc, car.dir)
		var/turf/T = tiles[E["slot"]]
		var/atom/movable/A
		var/list/P = E["payload"]
		switch(E["kind"])
			if("character")
				A = region_travel_build(region_travel_decode(E["payload"]), T)
			if("item")
				A = party_freight_build_item(P, T)
			if("crate")
				var/path = text2path(P["type"])
				A = new path(T)
				train_transfer_apply_structure_state(A, P["state"])
				for(var/list/entry in P["items"])
					if(!party_freight_build_item(entry, A))
						qdel(A)
						for(var/atom/movable/B in built) qdel(B)
						return null
			if("fitting")
				var/path = train_transfer_fitting_path(P["type"])
				A = new path(T)
				train_transfer_apply_structure_state(A, P["state"])
		if(!A)
			for(var/atom/movable/B in built) qdel(B)
			return null
		built += A
		A.train_transfer_id = M["id"]
		A.train_transfer_journey = M["journey"]
		A.train_transfer_digest = digest
		A.dir = turn(E["dir"], rotation)
		A.anchored = E["anchored"]
	var/obj/structure/trains/head = cars[1]
	head.train_transfer_built = TRUE
	return head

// Caller may invoke only after ledger grants source deletion/replay custody.
/proc/train_transfer_remove(id, journey)
	if(!train_transfer_string(id) || !train_transfer_string(journey)) return FALSE
	for(var/atom/movable/A in world)
		if(A.train_transfer_id == id && A.train_transfer_journey == journey) qdel(A)
	return TRUE
