#include "../../code/modules/1713/extraction/account_store.dm"
#include "../../code/modules/1713/extraction/transactions.dm"
#include "../../code/modules/1713/extraction/settlement.dm"

/world/OpenPort(port)
	if (port == "none") return ..()
	return FALSE

var/shared_failures = 0

/datum/shared_gate_observer
	var/list/parts
	var/checks = 0
	proc/check(datum/extraction_service/S)
		checks++
		return !S.open("alice") && !S.open("bob") && !S.sessions["carol"].active() && !S.settlement.submit(1, parts)
/proc/shared_assert(condition, message)
	if (!condition)
		shared_failures++
		world.log << "FAIL: [message]"

/proc/shared_service(root)
	var/datum/extraction_service/S = new
	S.store.root = root
	shared_assert(S.settlement_ready(), "shared service initial state")
	return S

/proc/shared_parts(datum/extraction_service/S)
	var/list/A = S.store.load_profile("alice")
	var/list/B = S.store.load_profile("bob")
	A["credits"] = 0
	B["credits"] = 100
	A["stash"] = list(list("id" = "gun1", "equipment" = list("schema" = 2, "nodes" = list(list("id" = "gun1", "condition" = 75), list("id" = "optic1", "found_in_raid" = FALSE)))))
	shared_assert(S.store.commit_profile("alice", A) && S.store.commit_profile("bob", B), "provision shared participants")
	var/list/nextA = json_decode(json_encode(A))
	var/list/nextB = json_decode(json_encode(B))
	nextA["revision"]++
	nextB["revision"]++
	nextA["stash"] = list()
	nextB["stash"] = json_decode(json_encode(A["stash"]))
	nextA["credits"] = 100
	nextB["credits"] = 0
	return list(list("owner" = "alice", "before" = A, "after" = nextA), list("owner" = "bob", "before" = B, "after" = nextB))

/world/New()
	world.OpenPort("none")
	var/phase = world.params["phase"]
	if (phase == "write")
		var/list/plans = list()
		var/list/cuts = list("before_receipt", "after_receipt", "before_apply1", "after_apply1", "before_apply2", "after_apply2", "before_finalize", "after_finalize", "participant_intent", "participant_snapshot", "receipt_snapshot", "finalize_intent", "finalize_snapshot")
		for (var/i in 1 to cuts.len)
			var/cut = cuts[i]
			var/root = "data/shared[i]/"
			var/datum/extraction_service/S = shared_service(root)
			var/list/parts = shared_parts(S)
			var/datum/extraction_session/observer = S.open("carol")
			var/datum/shared_gate_observer/gate = new
			gate.parts = parts
			S.settlement.test_access_observer = gate
			S.settlement.test_fail_at = cut
			if (cut == "participant_intent") S.store.test_fail_at = "intent"
			if (cut == "participant_snapshot") S.store.test_fail_at = "snapshot"
			if (cut == "receipt_snapshot") S.settlement.journal.test_fail_at = "snapshot"
			shared_assert(!S.settlement.submit(1, parts), "injected [cut] did not report commitment")
			if (cut != "before_receipt")
				shared_assert(!S.open("alice") && !S.open("bob") && !observer.active() && !observer.checkpoint_home(list()), "[cut] hides partial state from all service readers/actions")
			else
				shared_assert(S.store.load_profile("alice")["credits"] == 0 && S.store.load_profile("bob")["credits"] == 100, "before receipt has no effects")
			plans += list(list("root" = root, "cut" = cut, "parts" = parts))
		text2file(json_encode(plans), "shared_plans.json")
		shared_negative_controls()
		shared_budget_controls()
		var/datum/extraction_service/unreceived = shared_service("data/unreceived/")
		var/list/unreceived_parts = shared_parts(unreceived)
		unreceived.settlement.journal.test_fail_at = "intent"
		shared_assert(!unreceived.settlement.submit(1, unreceived_parts), "missing initial receipt snapshot rejects submission")
	else
		var/datum/extraction_service/unreceived = new
		unreceived.store.root = "data/unreceived/"
		shared_assert(!unreceived.settlement_ready() && !unreceived.open("alice"), "unknown receipt intent remains gated after restart")
		shared_assert(unreceived.store.load_profile("alice")["credits"] == 0 && unreceived.store.load_profile("bob")["credits"] == 100, "unknown receipt intent never applies account effects")
		var/list/plans = json_decode(file2text("shared_plans.json"))
		for (var/list/plan in plans)
			var/datum/extraction_service/S = shared_service(plan["root"])
			if (phase == "reload" && plan["cut"] == "before_receipt")
				shared_assert(S.store.load_profile("alice")["credits"] == 0, "untouched cut remains unpaid on process reopen")
				shared_assert(S.settlement.submit(1, plan["parts"]), "uncommitted request can be submitted once")
			var/datum/extraction_session/A = S.open("alice")
			var/datum/extraction_session/B = S.open("bob")
			shared_assert(A && B && A.profile["credits"] == 100 && B.profile["credits"] == 0 && !A.profile["stash"].len && B.profile["stash"].len == 1, "[plan["cut"]] reopened only complete ownership/payment")
			shared_assert(!S.open("alice"), "duplicate participant login rejected")
			shared_assert(S.settlement.submit(1, plan["parts"]), "exact committed replay is acknowledged without apply")
			shared_assert(A.profile["credits"] == 100 && B.profile["credits"] == 0, "replay never pays twice")
			var/list/changed = json_decode(json_encode(plan["parts"]))
			changed[1]["after"]["credits"] = 101
			shared_assert(!S.settlement.submit(1, changed), "changed bytes cannot replay a settled sequence")
			shared_assert(!S.settlement.submit(2, plan["parts"]), "active/stale participants cannot settle again")
			shared_assert(S.settlement.profile["history"].len == 1 && S.settlement.profile["phase"] == "committed" && !S.settlement.profile["participants"], "final receipt bounded and pending full graphs retired")
	text2file(shared_failures ? "FAIL: [shared_failures] shared assertions" : "PASS: shared native crash cuts, gated visibility, forward repair, graph and currency conservation, process reopen and replay", "result.txt")
	shutdown()

/proc/shared_negative_controls()
	var/datum/extraction_service/S = shared_service("data/sharednegative/")
	var/list/parts = shared_parts(S)
	var/list/bad = json_decode(json_encode(parts))
	bad[1]["after"]["credits"] = 101
	shared_assert(!S.settlement.submit(1, bad), "currency creation rejected")
	bad = json_decode(json_encode(parts))
	bad[1]["after"]["stash"] = json_decode(json_encode(parts[1]["before"]["stash"]))
	shared_assert(!S.settlement.submit(1, bad), "duplicate graph ownership rejected")
	bad = json_decode(json_encode(parts))
	bad[2]["after"]["stash"][1]["equipment"]["nodes"][1]["condition"] = 999
	shared_assert(!S.settlement.submit(1, bad), "same ID cannot forge equipment condition")
	var/datum/extraction_session/A = S.open("alice")
	shared_assert(!S.settlement.submit(1, parts), "live materialized participant rejected")
	A.close()
	var/list/other = S.store.load_profile("other")
	other["stash"] = list(list("id" = "optic1", "equipment" = list()))
	shared_assert(S.store.commit_profile("other", other), "outside ownership conflict fixture")
	shared_assert(!S.settlement.submit(1, parts), "nonparticipant nested ownership conflict rejected")

/proc/shared_budget_controls()
	var/datum/extraction_service/S = shared_service("data/sharedbudget/")
	var/list/parts = shared_parts(S)
	for (var/i in 1 to 130)
		if (i > 1)
			var/list/A = S.store.load_profile("alice")
			var/list/B = S.store.load_profile("bob")
			var/list/nextA = json_decode(json_encode(A))
			var/list/nextB = json_decode(json_encode(B))
			nextA["revision"]++
			nextB["revision"]++
			nextA["stash"] = B["stash"]
			nextB["stash"] = A["stash"]
			nextA["credits"] = B["credits"]
			nextB["credits"] = A["credits"]
			parts = list(list("owner" = "alice", "before" = A, "after" = nextA), list("owner" = "bob", "before" = B, "after" = nextB))
		shared_assert(S.settlement.submit(i, parts), "bounded shared history iteration [i]")
	shared_assert(S.settlement.profile["history"].len == 128 && flist("data/sharedbudget/_settlement/world/").len == 6, "bounded shared history and fixed native slots")
	shared_assert(!S.settlement.submit(1, parts), "retired sequence cannot settle again after history eviction")
