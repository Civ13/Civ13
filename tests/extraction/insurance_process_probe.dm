/proc/run_insurance_process_probe()
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
		var/phase = world.params["phase"]
		if (phase == "write")
			var/list/plans = list()
			var/list/cuts = list("after_prepare", "retirement_intent", "retirement_snapshot", "after_retirement", "apply1", "account_intent", "account_snapshot", "round_intent", "round_snapshot", "finalize_intent", "finalize_snapshot")
			for (var/i in 1 to cuts.len)
				var/cut = cuts[i]
				var/root = "data/process_returns[i]/"
				var/datum/extraction_service/S = new
				S.store.root = root
				var/datum/extraction_session/A = S.open("returnowner")
				var/obj/item/weapon/gun/projectile/pistol/m9beretta/G = new(locate(3,5,1))
				G.ammo_magazine = new /obj/item/ammo_magazine/m9beretta(G)
				var/list/record = C.encode(G)
				var/id = G.extraction_item_id
				qdel(G)
				equipment_assert(A.checkpoint_home(list(list("id" = id, "equipment" = record))), "process fixture stores actual equipment")
				var/list/raid = A.begin_raid(list(id), "PMC", list(id), "processround")
				G = C.decode(raid["issued"][1]["equipment"], locate(3,5,1))
				G.health = 79
				equipment_assert(A.forfeit(raid["sequence"]), "process fixture forfeits before return")
				A.close()
				var/datum/extraction_insurance_returns/returns = new(S, C)
				returns.test_fail_at = cut
				if (cut == "account_intent") S.store.test_fail_at = "intent"
				if (cut == "account_snapshot") S.store.test_fail_at = "snapshot"
				equipment_assert(!returns.prepare("processround", list(G)), "process [cut] withholds completion acknowledgement")
				if (cut != "after_prepare") equipment_assert(!G || !G.loc, "process [cut] retired physical source before any payout")
				plans += list(list("root" = root, "cut" = cut, "id" = id))
			text2file(json_encode(plans), "return_plans.json")
		else
			var/list/plans = json_decode(file2text("return_plans.json"))
			for (var/list/plan in plans)
				var/datum/extraction_service/S = new
				S.store.root = plan["root"]
				var/datum/extraction_insurance_returns/returns = new(S, C)
				if (plan["cut"] == "after_prepare")
					equipment_assert(!returns.ready() && !S.open("returnowner"), "prepared receipt never infers retirement from process restart")
					continue
				equipment_assert(returns.ready(), "native new process finishes physically retired receipt")
				var/datum/extraction_session/A = S.open("returnowner")
				equipment_assert(A && !A.profile["insurance_claims"].len, "new process exposes only resolved claim ownership")
				if (phase == "reload")
					equipment_assert(A.profile["insurance_mailbox"].len == 1 && !A.profile["stash"].len, "one native returned graph before mailbox claim")
					var/list/entry = A.profile["insurance_mailbox"][1]
					var/obj/item/weapon/gun/projectile/pistol/m9beretta/G = C.decode(entry["equipment"], locate(4,5,1))
					equipment_assert(G && G.extraction_item_id == plan["id"] && G.health == 79 && G.ammo_magazine && !G.ammo_magazine.stored_ammo.len, "new-process return retains actual lost condition and empty reusable magazine")
					qdel(G)
					equipment_assert(!A.claim_insurance_mail(list(plan["id"])), "restart cannot unlock mail before another full completed round")
					A.close()
					equipment_assert(returns.prepare("additionalfullround", list()), "separate full completion durably unlocks return")
					A = S.open("returnowner")
					equipment_assert(A.claim_insurance_mail(list(plan["id"])), "new process commits mailbox-to-stash move once")
				equipment_assert(!A.profile["insurance_mailbox"].len && A.profile["stash"].len == 1 && !A.claim_insurance_mail(list(plan["id"])), "third-process replay has one stored graph and no duplicate mailbox delivery")
				A.close()
				equipment_assert(!returns.prepare("processround", list()), "resolved native receipt refuses round replay")
		completed = TRUE
	catch (var/exception/E)
		equipment_failures++
		world.log << "FAIL: [E] at [E.file]:[E.line]"
	text2file(completed && !equipment_failures ? "PASS: native process insurance retirement receipts, forward account repair, mailbox claim and replay" : "FAIL: native insurance process verification", "result.txt")
	shutdown()
