// Three native processes share only the runner's temporary account files.
/proc/run_vehicle_process_probe()
	var/completed = FALSE
	try
		GLOB.all_observable_events = list()
		GLOB.global_listen_count = list()
		GLOB.event_sources_count = list()
		GLOB.event_listen_count = list()
		GLOB.dir_set_event = new /decl/observ/dir_set
		GLOB.moved_event = new /decl/observ/moved
		GLOB.destroyed_event = new /decl/observ/destroyed
		initialize_chemical_reagents()
		for (var/turf/T in world) T.ChangeTurf(/turf/floor, FALSE, FALSE)
		var/list/params = world.params
		var/datum/extraction_service/S = new
		S.store.root = "data/process_vehicle/"
		var/datum/extraction_session/session = S.open("vehicleowner")
		equipment_assert(session, "native process opens vehicle account")
		var/datum/extraction_vehicle_codec/C = new
		if (params["phase"] == "write")
			var/obj/structure/car_workshop/W = new(locate(5,5,1))
			var/obj/effects/premadevehicles/asno/piccolino/template = new(null, TRUE)
			var/obj/structure/vehicleparts/axis/A = W.assemble_layout(template, 3)
			qdel(template)
			var/obj/structure/engine/internal/E = A.engine
			E.fueltank.reagents.add_reagent(E.fuels[1], 17, safety = TRUE)
			var/obj/structure/vehicleparts/frame/F = A.loc
			F.w_front[5] = 73
			var/list/record = C.encode(A)
			equipment_assert(record, "native process encodes actual assembled car: [C.last_error]")
			var/list/P = session.copy_profile()
			P["garage"] = list(record)
			equipment_assert(session.commit(P), "vehicle account journal commits before process exits")
			text2file(json_encode(record), "vehicle_record.json")
			var/datum/extraction_service/Q = new
			Q.store.root = "data/quarantined_vehicle/"
			var/datum/extraction_session/quarantined = Q.open("uncertainowner")
			P = quarantined.copy_profile()
			P["garage"] = list(record)
			equipment_assert(quarantined.commit(P), "quarantine fixture begins with acknowledged garage and empty stash")
			P = quarantined.copy_profile()
			P["garage"] = list()
			Q.store.test_fail_at = "intent"
			equipment_assert(!quarantined.commit(P) && quarantined.locked, "interrupted garage debit remains quarantined")
			quarantined.close()
		else if (params["phase"] == "reload")
			var/list/record = json_decode(file2text("vehicle_record.json"))
			equipment_assert(json_encode(session.profile["garage"][1]) == json_encode(record), "fresh process reloads exact vehicle account graph")
			var/obj/structure/vehicleparts/axis/A = C.decode(record, locate(12,12,1))
			equipment_assert(A && A.extraction_vehicle_part_id == record["id"] && A.engine.fueltank.reagents.total_volume == 17, "fresh process restores stable identity and paid fuel without constructor additions")
			var/obj/structure/vehicleparts/frame/F = A.loc
			equipment_assert(F.w_front[5] == 73 && A.wheels.len == 4 && A.wheel.control:axis == A, "fresh process preserves damage and native vehicle links")
			var/list/P = session.copy_profile()
			P["garage"] = list()
			equipment_assert(session.commit(P), "garage removal commits to durable account revision")
			var/datum/extraction_service/Q = new
			Q.store.root = "data/quarantined_vehicle/"
			equipment_assert(!Q.open("uncertainowner"), "fresh process cannot expose previous garage behind an incomplete intent")
			var/list/first = Q.store.read_slot("uncertainowner", 0)
			var/list/second = Q.store.read_slot("uncertainowner", 1)
			var/slot = first["generation"] > second["generation"] ? 0 : 1
			var/list/intent = json_decode(file2text(Q.store.path_for("uncertainowner", slot, "intent")))
			var/list/discarded = Q.store.settle_pending_loss("uncertainowner", intent["generation"], intent["digest"])
			equipment_assert(discarded && !discarded["garage"].len && !discarded["stash"].len, "uncertain garage forfeited independently of empty stash")
			equipment_assert(discarded["loss_settlement"]["discarded_intent_digest"] == intent["digest"] && fexists("data/quarantined_vehicle/uncertainowner/recovery.latest.json"), "garage forfeiture preserves exact uncertainty reason and audit receipt")
		else
			equipment_assert(islist(session.profile["garage"]) && !session.profile["garage"].len && !S.store.recovery_ids(session.profile).len, "third process cannot restore removed vehicle from an older account slot")
			var/list/P = session.copy_profile()
			P["garage"] = list(json_decode(file2text("vehicle_record.json")))
			P["revision"]--
			equipment_assert(!session.commit(P), "stale vehicle credit cannot replay an older account revision")
			var/datum/extraction_service/Q = new
			Q.store.root = "data/quarantined_vehicle/"
			var/datum/extraction_session/quarantined = Q.open("uncertainowner")
			equipment_assert(quarantined && !quarantined.profile["garage"].len && quarantined.profile["loss_settlement"], "third process retains explicit forfeiture without reissuing previous garage")
			quarantined.close()
		session.close()
		run_vehicle_purchase_process_probe(params["phase"])
		completed = TRUE
	catch (var/exception/E)
		equipment_failures++
		world.log << "FAIL: [E] at [E.file]:[E.line]"
	text2file(completed && !equipment_failures ? "PASS: native vehicle account process reload, condition and removal replay" : "FAIL: native vehicle process verification", "result.txt")
	shutdown()

/proc/run_vehicle_purchase_process_probe(phase)
	var/datum/extraction_service/S = new
	S.store.root = "data/purchase_vehicle/"
	if (phase == "write")
		var/datum/extraction_session/A = S.open("paidcarowner")
		var/list/P = A.copy_profile()
		P["level"] = 2
		var/list/payment = list()
		var/datum/extraction_equipment_codec/C = new
		for (var/i in 1 to EXTRACTION_CAR_PRICE)
			var/obj/item/extraction_salvage/I = new(locate(3,3,1))
			var/list/graph = C.encode(I)
			P["stash"] += list(list("id" = I.extraction_item_id, "equipment" = graph, "salvage" = TRUE))
			payment += I.extraction_item_id
			qdel(I)
		equipment_assert(A.commit(P), "purchase restart fixture stores real payment graphs")
		var/list/plan = A.plan_vehicle_purchase(payment, A.profile["revision"])
		equipment_assert(plan && A.commit(plan) && !A.profile["stash"].len && A.profile["garage_purchase"]["status"] == "pending", "paid construction intent commits without a visible car")
		A.close()
	else if (phase == "reload")
		equipment_assert(!S.open("paidcarowner"), "fresh process quarantines interrupted paid construction without reissue")
		var/list/P = S.store.load_profile("paidcarowner")
		equipment_assert(P && !P["stash"].len && P["garage_purchase"]["status"] == "pending", "quarantine preserves actual payment debit")
		var/id = P["garage_purchase"]["id"]
		equipment_assert(!S.store.retire_pending_vehicle("paidcarowner", P["revision"] - 1, id) && !S.store.retire_pending_vehicle("paidcarowner", P["revision"], "wrongpurchase"), "offline car forfeiture rejects stale revision and wrong purchase identity")
		P = S.store.retire_pending_vehicle("paidcarowner", P["revision"], id)
		equipment_assert(P && P["garage_purchase"]["status"] == "forfeited" && !P["stash"].len && !P["garage"].len && fexists("data/purchase_vehicle/paidcarowner/garage-recovery.latest.json"), "explicit offline construction forfeiture preserves receipt without refund or car")
	else
		var/datum/extraction_session/A = S.open("paidcarowner")
		equipment_assert(A && A.profile["garage_purchase"]["status"] == "forfeited" && !A.profile["stash"].len && !A.profile["garage"].len, "third process retains paid construction forfeiture without recreation")
		equipment_assert(!S.store.retire_pending_vehicle("paidcarowner", A.profile["revision"], A.profile["garage_purchase"]["id"]), "construction forfeiture cannot replay")
		A.close()
