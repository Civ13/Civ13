// Source-side save barrier for whole-train custody. A captured train becomes
// one saved station record synchronously. No network request may submit it
// until a completed world save has included that record. This module is not
// wired to player departure until the complete body codec is accepted.
#define TRAIN_ESCROW_LIMIT 4
var/global/train_escrow_hold_reason = null

/obj/structure/region_gate/var/list/train_escrow_records = list()
/obj/structure/region_gate/var/tmp/list/train_escrow_durable = list()

/obj/structure/region_gate/persistence_runtime_var(key)
	if(key == "train_escrow_durable") return TRUE
	if(key == "train_arrival_durable") return TRUE
	return ..()

/obj/structure/region_gate/after_load()
	..()
	train_arrival_after_load()
	train_escrow_durable = list()
	if(!islist(train_escrow_records) || length(train_escrow_records) > TRAIN_ESCROW_LIMIT)
		train_escrow_hold_reason = "A saved train escrow has an invalid record list."
		return
	for(var/text in train_escrow_records)
		var/list/R = train_escrow_decode(text)
		if(R)
			train_escrow_durable[R["journey"]] = text
		else
			train_escrow_hold_reason = "A saved train escrow is unreadable; account admission remains held."

/proc/train_escrow_decode(text)
	if(!istext(text) || length(text) > 300000) return null
	var/list/R
	try
		R = json_decode(text)
	catch
		return null
	if(!islist(R) || R.len != 5 || R["version"] != 1 || !istext(R["payload"]) || !istext(R["journey"]) || !(R["heading"] in cardinal) || !islist(R["centres"])) return null
	var/list/M = train_transfer_decode(R["payload"])
	if(!M || M["journey"] != R["journey"] || length(R["centres"]) != length(M["segments"])) return null
	for(var/list/position in R["centres"])
		if(position.len != 3) return null
		for(var/value in position)
			if(!isnum(value) || value < 1 || value != round(value) || value > 65535) return null
	return R

// Called synchronously after the save-complete marker, before the agent HTTP
// acknowledgement can yield. Staging is forbidden during saves, so this set
// is exactly the set of records the completed world capture could include.
/proc/train_escrow_saved()
	for(var/obj/structure/region_gate/S in region_gates)
		if(QDELETED(S)) continue
		S.train_escrow_durable = list()
		for(var/text in S.train_escrow_records)
			var/list/R = train_escrow_decode(text)
			if(R) S.train_escrow_durable[R["journey"]] = text

/proc/train_escrow_account_held(account)
	if(train_escrow_hold_reason) return TRUE
	if(!istext(account)) return FALSE
	for(var/obj/structure/region_gate/S in region_gates)
		for(var/text in S.train_escrow_records)
			var/list/R = train_escrow_decode(text)
			if(!R)
				train_escrow_hold_reason = "A train escrow is unreadable; account admission remains held."
				return TRUE
			var/list/M = train_transfer_decode(R["payload"])
			if(account in M["accounts"]) return TRUE
	return FALSE

// A caller must first confirm source HOME for every account, revalidate the
// driver's authority/body ownership, and settle in-flight gameplay actions.
// The coordinator obtains the atomic group lease before destination admission;
// a later home conflict keeps the source record held, never silently releases it.
// No asynchronous request occurs between capture and removing its live roots.
/obj/structure/region_gate/proc/train_escrow_stage(obj/structure/trains/head)
	if(QDELETED(src) || !head || QDELETED(head) || persistence_save_active() || !map || !map.uses_durable_metadata() || !transfer_bridge.ready()) return "The world cannot stage a train now."
	if(!isturf(loc) || !should_save || length(train_escrow_records) >= TRAIN_ESCROW_LIMIT) return "This station's durable train escrow is unavailable or full."
	if(!islist(head.train_route)) return "The train has no route."
	var/list/route = head.train_route
	var/problem = train_route_departure_problem(head, get_turf(head))
	if(problem) return problem
	if(train_route_station(route["source_station"], route["party"]) != src) return "The route belongs to another station."
	// Mandatory integration gate: callers cannot accidentally delete mutable
	// characters with the old character-travel projection.
	return "Whole-train staging awaits the accepted body codec and account lease integration."

// Once the integration gate above is replaced, this helper records an already
// validated synchronous capture. It is intentionally not called by a verb.
/obj/structure/region_gate/proc/train_escrow_record_capture(list/capture)
	if(persistence_save_active() || !islist(capture) || length(train_escrow_records) >= TRAIN_ESCROW_LIMIT) return FALSE
	var/list/M = capture["manifest"]
	var/list/cars = capture["cars"]
	var/list/loads = capture["loads"]
	if(!islist(M) || !islist(cars) || !cars.len || !islist(loads) || !train_transfer_decode(json_encode(M))) return FALSE
	var/list/centres = list()
	for(var/obj/structure/trains/car in cars)
		if(QDELETED(car) || !isturf(car.loc)) return FALSE
		centres += list(list(car.x, car.y, car.z))
	var/obj/structure/trains/head = cars[1]
	var/text = json_encode(list("version" = 1, "journey" = M["journey"], "payload" = json_encode(M), "centres" = centres, "heading" = head.dir))
	if(!train_escrow_decode(text)) return FALSE
	// Do not permit duplicate source records, even while the previous one has
	// not yet crossed the save barrier.
	for(var/old in train_escrow_records)
		var/list/R = train_escrow_decode(old)
		if(!R || R["journey"] == M["journey"]) return FALSE
	train_escrow_records += text
	train_escrow_durable -= M["journey"]
	return TRUE

#undef TRAIN_ESCROW_LIMIT
