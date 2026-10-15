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
			var/datum/extraction_vehicle_transfer/T = new
			equipment_assert(T.capture(A), "native cargo fixture begins with closed car")
			for (var/obj/structure/table/carboot/B in T.parts)
				var/obj/item/extraction_salvage/I = new(get_turf(B))
				I.extraction_found_in_raid = TRUE
				var/datum/extraction_equipment_codec/issuer = new
				equipment_assert(issuer.encode(I), "native cargo fixture explicitly issues initial identity")
			extraction_vehicle_custody_probe(A)
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
			var/datum/extraction_vehicle_transfer/T = new
			equipment_assert(T.capture(A, TRUE) && T.cargo.len == record["cargo"].len && T.cargo.len > 0, "fresh process restores actual bounded boot cargo")
			var/obj/item/I = T.cargo[1]
			equipment_assert(I.extraction_item_id == record["cargo"][1]["id"] && I.extraction_found_in_raid && S.store.recovery_ids(session.profile)[I.extraction_item_id], "native cargo reload retains provenance and account identity")
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
		run_vehicle_raid_process_probe(params["phase"])
		completed = TRUE
	catch (var/exception/E)
		equipment_failures++
		world.log << "FAIL: [E] at [E.file]:[E.line]"
	text2file(completed && !equipment_failures ? "PASS: native vehicle account process reload, condition and removal replay" : "FAIL: native vehicle process verification", "result.txt")
	shutdown()

/proc/run_vehicle_raid_process_probe(phase)
	for (var/scenario in list("debit", "credit", "uncertain"))
		var/datum/extraction_service/R = new
		R.store.root = "data/raid_vehicle_[scenario]/"
		if (phase == "write")
			var/datum/extraction_session/A = R.open("raidcarowner")
			var/list/P = A.copy_profile()
			var/list/record = json_decode(file2text("vehicle_record.json"))
			P["garage"] = list(record)
			equipment_assert(A.commit(P), "restart raid fixture acknowledges original garage")
			var/list/plan = A.plan_vehicle_raid(list(), A.profile["revision"], record["id"], md5(json_encode(record)))
			equipment_assert(plan && A.commit(plan["candidate"]) && !A.profile["garage"].len, "raid garage debit persists before any physical relocation")
			if (scenario != "debit")
				if (scenario == "uncertain") R.store.test_fail_at = "intent"
				var/credited = A.credit_vehicle_extraction(A.profile["raid_sequence"], list(), record)
				equipment_assert(scenario == "credit" ? credited : (!credited && A.locked), "vehicle extraction commit interruption locks uncertain ownership")
			A.close()
		else if (phase == "reload" && scenario == "uncertain")
			equipment_assert(!R.open("raidcarowner"), "uncertain vehicle credit blocks restart materialization")
			var/list/first = R.store.read_slot("raidcarowner", 0)
			var/list/second = R.store.read_slot("raidcarowner", 1)
			var/slot = first["generation"] > second["generation"] ? 0 : 1
			var/list/intent = json_decode(file2text(R.store.path_for("raidcarowner", slot, "intent")))
			var/list/lost = R.store.settle_pending_loss("raidcarowner", intent["generation"], intent["digest"])
			equipment_assert(lost && !lost["garage"].len && !lost["stash"].len, "explicit uncertain-credit forfeiture never resurrects original garage")
		else
			var/datum/extraction_session/A = R.open("raidcarowner")
			equipment_assert(A && A.profile["state"] == "home", "fresh process resolves acknowledged vehicle raid state")
			if (scenario == "credit")
				equipment_assert(A.profile["garage"].len == 1 && A.profile["vehicle_returned"] && A.profile["garage"][1]["cargo"].len > 0, "acknowledged vehicle credit reloads car and cargo after interrupted physical return")
			else equipment_assert(!A.profile["garage"].len, "debit or explicit loss persists without vehicle reissue")
			equipment_assert(!A.credit_vehicle_extraction(A.profile["raid_sequence"], list(), json_decode(file2text("vehicle_record.json"))), "reloaded vehicle credit cannot replay")
			A.close()

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
