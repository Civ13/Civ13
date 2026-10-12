/datum/group_gate_observer
	proc/check(datum/extraction_service/S)
		return !S.open("groupvisitor") && !S.settlement_ready()

/proc/run_group_process_probe()
	var/completed = FALSE
	try
		GLOB.all_observable_events = list()
		GLOB.global_listen_count = list()
		GLOB.event_sources_count = list()
		GLOB.event_listen_count = list()
		GLOB.dir_set_event = new /decl/observ/dir_set
		GLOB.moved_event = new /decl/observ/moved
		GLOB.destroyed_event = new /decl/observ/destroyed
		var/datum/extraction_equipment_codec/C = new
		var/datum/extraction_vehicle_codec/VC = new
		var/phase = world.params["phase"]
		if (phase == "write")
			var/list/plans = list()
			var/list/cuts = list("after_receipt", "before_apply1", "after_apply1", "account_intent", "account_snapshot", "before_finalize", "finalize_intent", "finalize_snapshot", "after_finalize", "initial_intent", "initial_snapshot")
			for (var/i in 1 to cuts.len)
				var/cut = cuts[i]
				var/datum/extraction_service/S = new
				S.store.root = "data/process_groups[i]/"
				var/list/parts = list()
				for (var/owner in list("groupone", "grouptwo"))
					var/datum/extraction_session/A = S.open(owner)
					var/obj/item/weapon/gun/projectile/pistol/m9beretta/G = new(locate(3,5,1))
					var/list/entry = list("id" = G.extraction_item_id, "equipment" = C.encode(G))
					// Encoding assigns the ID; read it after encoding.
					entry["id"] = G.extraction_item_id
					var/list/stash = list(entry)
					if (owner == "groupone")
						for (var/premium in 1 to 8)
							var/obj/item/extraction_salvage/I = new(locate(3,5,1))
							var/list/graph = C.encode(I)
							stash += list(list("id" = I.extraction_item_id, "equipment" = graph))
							qdel(I)
					var/list/garage = list()
					if (owner == "groupone")
						var/obj/structure/car_workshop/W = new(locate(8,8,1))
						var/obj/effects/premadevehicles/asno/piccolino/template = new(null, TRUE)
						var/obj/structure/vehicleparts/axis/car = W.assemble_layout(template, 3)
						qdel(template)
						var/list/vehicle = VC.encode(car)
						equipment_assert(vehicle, "native group fixture records real car graph")
						garage += list(vehicle)
						var/datum/extraction_vehicle_transfer/T = new
						equipment_assert(T.capture(car, TRUE), "native group fixture owns bounded actual car parts")
						for (var/obj/O in T.parts)
							for (var/obj/child in O.contents.Copy())
								if (child.extraction_vehicle_part_id) qdel(child)
							qdel(O)
						qdel(W)
					equipment_assert(A.checkpoint_home(stash, garage), "group fixture checkpoints real native equipment")
					var/list/before = A.copy_profile()
					var/list/offer = owner == "groupone" ? A.plan_insurance_quote(list(G.extraction_item_id), "group-process-round") : null
					var/list/plan = offer ? A.plan_raid(list(G.extraction_item_id), "PMC", offer["insured"], offer["round"], offer["payment"], before["revision"]) : A.plan_raid(list(G.extraction_item_id), "PMC")
					if (garage.len) plan = A.plan_group_vehicle(plan, garage[1]["id"], md5(json_encode(garage[1])))
					var/list/after = plan["candidate"]
					after["revision"] = before["revision"] + 1
					var/list/part = list("owner" = owner, "before" = before, "after" = after, "selected" = list(G.extraction_item_id), "faction" = "PMC", "issued" = plan["issued"])
					if (offer) part["insurance"] = offer
					if (garage.len) part["vehicle"] = list("id" = garage[1]["id"], "digest" = md5(json_encode(garage[1])))
					parts += list(part)
					qdel(G)
					A.close()
				var/datum/extraction_settlement/groups/J = S.group_journal
				J.test_access_observer = new /datum/group_gate_observer
				J.test_fail_at = cut
				if (cut == "account_intent") S.store.test_fail_at = "intent"
				if (cut == "account_snapshot") S.store.test_fail_at = "snapshot"
				if (cut == "initial_intent") J.journal.test_fail_at = "intent"
				if (cut == "initial_snapshot") J.journal.test_fail_at = "snapshot"
				equipment_assert(!J.submit(1, parts) && !S.open("groupone") && !S.open("grouptwo"), "interrupted group never exposes a partial account set")
				plans += list(list("root" = S.store.root, "cut" = cut, "parts" = parts))
			text2file(json_encode(plans), "group_plans.json")
		else
			var/list/plans = json_decode(file2text("group_plans.json"))
			for (var/list/plan in plans)
				var/datum/extraction_service/S = new
				S.store.root = plan["root"]
				if (plan["cut"] == "initial_intent")
					equipment_assert(!S.open("groupone") && !S.open("grouptwo"), "unknown initial group intent remains blocked rather than inventing a debit")
					continue
				for (var/owner in list("groupone", "grouptwo"))
					var/datum/extraction_session/A = S.open(owner)
					var/list/expected = plan["parts"][owner == "groupone" ? 1 : 2]["after"]
					equipment_assert(A && A.profile["state"] == "home" && A.profile["raid_sequence"] == 1 && json_encode(A.profile["stash"]) == json_encode(expected["stash"]) && json_encode(A.profile["insurance_claims"]) == json_encode(expected["insurance_claims"]), "new process finishes every recorded debit and forfeits interrupted raid without reissuing gear")
					equipment_assert(!A.profile["garage"].len && json_encode(A.profile["vehicle_issued"]) == json_encode(expected["vehicle_issued"]), "native group recovery preserves exact vehicle debit without a second car")
					A.close()
				var/datum/extraction_settlement/groups/J = S.group_journal
				equipment_assert(J.submit(1, plan["parts"]), "exact group receipt replay acknowledged without a second debit")
				var/list/forged = json_decode(json_encode(plan["parts"]))
				forged[1]["after"]["stash"] = forged[1]["before"]["stash"]
				equipment_assert(!J.valid_participants(forged), "forged group projection rejected by planning authority")
				equipment_assert(!J.submit(1, forged) && !J.submit(2, forged), "replayed or new forged group refund rejected")
				var/list/underpaid = json_decode(json_encode(plan["parts"]))
				underpaid[1]["insurance"]["cost"] = 0
				equipment_assert(!J.valid_participants(underpaid), "forged group premium rejected by canonical pricing authority")
				var/list/retained_car = json_decode(json_encode(plan["parts"]))
				retained_car[1]["after"]["garage"] = retained_car[1]["before"]["garage"]
				equipment_assert(!J.valid_participants(retained_car), "forged retained group car rejected by exact debit authority")
		completed = TRUE
	catch (var/exception/E)
		equipment_failures++
		world.log << "FAIL: [E] at [E.file]:[E.line]"
	text2file(completed && !equipment_failures ? "PASS: native group process recovery across eleven interruptions, ownership gates and replay" : "FAIL: native group process verification", "result.txt")
	shutdown()
