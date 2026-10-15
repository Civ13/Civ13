// Pure paid-component reservation. Commit this snapshot before retiring roots;
// pending purchases already quarantine admission after any interrupted build.
/datum/extraction_session/proc/plan_vehicle_construction(list/payment, expected_revision, list/required)
	if (!active() || profile["state"] != "home" || profile["level"] < 2 || profile["revision"] != expected_revision || !islist(payment) || !payment.len || payment.len > 64 || !islist(required) || required.len != 5 || (islist(profile["garage"]) && profile["garage"].len) || (islist(profile["garage_purchase"]) && profile["garage_purchase"]["status"] == "pending")) return null
	var/obj/structure/car_workshop/native_workshop = new(null)
	var/list/native_cost = native_workshop.costs("ASNO Piccolino")
	qdel(native_workshop)
	for (var/key in native_cost)
		if (required[key] != native_cost[key]) return null
	var/list/wanted = list()
	for (var/id in payment)
		if (!istext(id) || wanted[id]) return null
		wanted[id] = TRUE
	var/list/candidate = copy_profile()
	var/list/retained = list()
	var/list/inputs = list()
	var/list/ids = list()
	var/list/totals = list("steel" = 0, "glass" = 0, "cloth" = 0, "cable" = 0, "wheels" = 0)
	var/datum/extraction_equipment_codec/C = new
	for (var/list/entry in candidate["stash"])
		if (!wanted[entry["id"]])
			retained += list(entry)
			continue
		var/list/graph = entry["equipment"]
		if (!C.validate(graph) || graph["schema"] != 2 || graph["nodes"].len != 1 || entry["secure"]) return null
		var/list/node = graph["nodes"][1]
		if (node["id"] != entry["id"] || node["insurance_token"]) return null
		var/key
		switch (node["type"])
			if ("/obj/item/stack/material/steel") key = "steel"
			if ("/obj/item/stack/material/glass") key = "glass"
			if ("/obj/item/stack/material/cloth") key = "cloth"
			if ("/obj/item/stack/cable_coil") key = "cable"
			if ("/obj/item/extraction_wheel_crate") key = "wheels"
		if (!key) return null
		if (key == "wheels")
			if (node["packed_wheel"]["broken"] || node["packed_wheel"]["config"]["current_health"] <= 0) return null
			totals[key]++
		else totals[key] += node["scalars"]["amount"]
		inputs += list(entry)
		ids += entry["id"]
	if (inputs.len != payment.len) return null
	for (var/key in totals)
		if (!isnum(required[key]) || required[key] <= 0 || totals[key] != required[key]) return null
	candidate["stash"] = retained
	candidate["garage_purchase"] = list("id" = md5("[owner]:assembly:[expected_revision + 1]"), "model" = "piccolino", "kind" = "components", "status" = "pending", "paid_revision" = expected_revision + 1, "payment" = ids, "inputs" = inputs)
	return candidate

// A car dealer consumes home workshop parts before constructing any car.
/datum/extraction_session/proc/plan_vehicle_purchase(list/payment, expected_revision)
	if (!active() || profile["state"] != "home" || profile["level"] < 2 || profile["revision"] != expected_revision || !islist(payment) || payment.len != EXTRACTION_CAR_PRICE || (islist(profile["garage"]) && profile["garage"].len) || (islist(profile["garage_purchase"]) && profile["garage_purchase"]["status"] == "pending")) return null
	var/list/wanted = list()
	for (var/id in payment)
		if (!istext(id) || wanted[id]) return null
		wanted[id] = TRUE
	var/list/candidate = copy_profile()
	var/list/retained = list()
	var/list/matched = list()
	for (var/list/entry in candidate["stash"])
		if (!wanted[entry["id"]])
			retained += list(entry)
			continue
		var/list/graph = entry["equipment"]
		if (!entry["salvage"] || !islist(graph) || !islist(graph["nodes"]) || graph["nodes"].len != 1 || graph["nodes"][1]["type"] != "/obj/item/extraction_salvage" || graph["nodes"][1]["id"] != entry["id"] || graph["nodes"][1]["insurance_token"] || matched[entry["id"]]) return null
		matched[entry["id"]] = TRUE
	if (matched.len != payment.len) return null
	candidate["stash"] = retained
	candidate["garage_purchase"] = list("id" = md5("[owner]:car:[expected_revision + 1]"), "model" = "piccolino", "status" = "pending", "paid_revision" = expected_revision + 1, "payment" = payment.Copy())
	return candidate

/datum/extraction_session/proc/finish_vehicle_purchase(list/record, purchase_id)
	if (!active() || profile["state"] != "home" || !service.store.valid_garage(list(record))) return FALSE
	var/list/purchase = profile["garage_purchase"]
	if (!islist(purchase) || purchase["status"] != "pending" || purchase["id"] != purchase_id || (islist(profile["garage"]) && profile["garage"].len)) return FALSE
	var/list/candidate = copy_profile()
	candidate["garage"] = list(record)
	candidate["garage_purchase"]["status"] = "complete"
	return commit(candidate)

/obj/map_metadata/extraction_survival/proc/car_bay_clear(datum/extraction_session/S)
	var/turf/anchor = garage_anchor(S)
	if (!anchor || S.garage_vehicle || S.garage_parts.len) return FALSE
	for (var/x in anchor.x - 2 to anchor.x)
		for (var/y in anchor.y to anchor.y + 2)
			var/turf/T = locate(x, y, anchor.z)
			if (!istype(T, /turf/floor/plating/extraction_house) || get_dist(T, S.house) > 4) return FALSE
			for (var/atom/movable/O in T)
				if (!istype(O, /atom/movable/lighting_overlay)) return FALSE
	return TRUE

/obj/map_metadata/extraction_survival/proc/confirm_car_purchase(mob/living/human/H)
	return WWinput(H, "Buy a Piccolino for 25 workshop parts? The car has no fuel. Your level-two private bay must be clear. Construction uncertainty locks the account for explicit offline forfeiture; it never reissues a car or refunds parts automatically.", "Private garage", "Cancel", list("Buy car", "Cancel")) == "Buy car"

/obj/map_metadata/extraction_survival/proc/buy_car(mob/living/human/H)
	if (!owned(H) || H.stat != CONSCIOUS) return FALSE
	var/datum/extraction_session/S = H.extraction_session
	if (!S.house || !H.Adjacent(S.house) || S.transitioning || !save_home(S) || !car_bay_clear(S)) return FALSE
	var/list/payment = list()
	var/list/consumed = list()
	for (var/obj/item/extraction_salvage/I in home_roots(S))
		if (I.extraction_insurance_token || I.contents.len || I.extraction_secure_stored) continue
		if (payment.len >= EXTRACTION_CAR_PRICE) break
		payment += I.extraction_item_id
		consumed += I
	var/revision = S.profile["revision"]
	var/list/plan = S.plan_vehicle_purchase(payment, revision)
	if (!plan)
		to_chat(H, "A car needs a level-two house, an empty garage and 25 uninsured workshop parts outside secure storage.")
		return FALSE
	if (!confirm_car_purchase(H) || !owned(H) || H.stat != CONSCIOUS || !H.Adjacent(S.house) || S.transitioning || !car_bay_clear(S) || S.profile["revision"] != revision || json_encode(records(home_roots(S))) != json_encode(S.profile["stash"])) return FALSE
	if (json_encode(S.plan_vehicle_purchase(payment, revision)) != json_encode(plan)) return FALSE
	S.transitioning = TRUE
	if (!S.commit(plan))
		S.transitioning = FALSE
		return FALSE
	// No actor wait after payment. The existing production factory creates an
	// empty-fuel car; pending purchase is durable before its first part appears.
	for (var/obj/item/I in consumed) qdel(I)
	var/turf/anchor = garage_anchor(S)
	var/obj/structure/car_workshop/W = new(null)
	W.should_save = FALSE
	W.loc = locate(anchor.x - 3, anchor.y - 1, anchor.z)
	var/obj/effects/premadevehicles/asno/piccolino/template = new(null, TRUE)
	var/obj/structure/vehicleparts/axis/A
	var/list/record
	var/datum/extraction_vehicle_transfer/T = new
	try
		A = W.assemble_layout(template, 3)
		if (A && T.capture(A))
			S.garage_vehicle = A
			S.garage_parts = T.parts.Copy()
			var/list/snapshot = garage_snapshot(S)
			if (snapshot && snapshot.len) record = snapshot[1]
	catch (var/exception/E)
		world.log << "Extraction car construction quarantined for [S.owner]: [E]"
	qdel(template)
	qdel(W)
	if (!record || !S.finish_vehicle_purchase(record, plan["garage_purchase"]["id"]))
		S.locked = TRUE
		to_chat(H, "Paid car construction is uncertain. Account quarantined for explicit offline forfeiture; no car or payment will be reissued automatically.")
		return FALSE
	S.transitioning = FALSE
	to_chat(H, "Car purchased and saved in your private bay. It has no fuel.")
	return TRUE
