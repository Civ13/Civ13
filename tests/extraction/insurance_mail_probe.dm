// Fixture-only traversal of known small inventories. Production inspection
// reads one page, and direct claims never traverse the backlog.
/proc/equipment_mail_entries(datum/extraction_service/S, owner)
	var/datum/extraction_mail_store/mail = S.mail_service()
	var/sequence = "1"
	var/list/entries = list()
	for (var/i in 1 to 16)
		var/list/P = mail.page(owner, sequence)
		equipment_assert(P, "fixture reads valid bounded mail page")
		entries.Add(P["entries"])
		if (!P["next"]) return entries
		sequence = P["next"]
	equipment_assert(FALSE, "fixture inventory exceeds explicit 128-root test budget")
	return null

/proc/equipment_insurance_shards_probe(datum/extraction_equipment_codec/C)
	var/datum/extraction_service/S = new
	S.store.root = "data/mail_shards/"
	var/datum/extraction_mail_store/mail = new(S, C)
	var/list/entries = list()
	for (var/i in 1 to 72)
		var/obj/item/weapon/gun/projectile/submachinegun/ak47/G = new(locate(1, 1, 1))
		G.extraction_item_id = "mailgun[i]"
		G.extraction_found_in_raid = i % 2
		G.health = 40
		var/list/graph = C.encode(G)
		equipment_assert(graph, "encode real native return for shard")
		entries += list(list("id" = G.extraction_item_id, "equipment" = graph, "returned_generation" = 1, "eligible_generation" = 2))
		qdel(G)
	var/list/operations = mail.plan_append("mailowner", entries)
	equipment_assert(operations, "plan 72 retained returns beyond former 64 cap")
	var/datum/extraction_account_store/receipt = new
	receipt.root = "data/mail_plan_receipt/"
	var/list/P = receipt.load_profile("world")
	P["operations"] = operations
	equipment_assert(receipt.commit_profile("world", P), "persist shard authority before projections")
	mail.journal.test_fail_at = "intent"
	equipment_assert(!mail.apply(P["operations"]), "interrupt first identity intent")
	mail.journal.test_fail_at = null
	mail = new(S, C)
	P = receipt.load_profile("world")
	equipment_assert(mail.apply(P["operations"]) && mail.apply(P["operations"]), "exact durable shard replay finishes interrupted intent once")
	var/list/first = mail.inspect("mailowner", 0, 1, null)
	equipment_assert(first && first["entries"].len == 8 && first["expiration"] == "to be implemented", "bounded private inspection with explicit expiration placeholder")
	equipment_assert(first["entries"][1]["state"] == "pending" && first["entries"][1]["condition"]["health"] == 40, "pending inspection retains original condition")
	var/cursor = first["next_cursor"]
	var/list/seen = list()
	var/list/result = first
	for (var/i in 1 to 9)
		if (!result) world.log << "Mail page [i] inspection error: [mail.last_error]"
		equipment_assert(result && result["entries"].len == 8, "each page remains bounded at eight")
		for (var/list/E in result["entries"])
			equipment_assert(!seen[E["item_id"]], "pages never duplicate return roots")
			seen[E["item_id"]] = TRUE
		if (result["next_cursor"]) result = mail.inspect("mailowner", 0, 2, result["next_cursor"])
		else equipment_assert(i == 9, "last cursor ends only after all retained pages")
	equipment_assert(seen.len == 72 && result["entries"][1]["state"] == "eligible", "all 72 records retained and generation controls eligibility")
	equipment_assert(!mail.inspect("otherowner", 0, 2, cursor), "cursor cannot expose another owner")
	equipment_assert(!mail.plan_append("mailowner", list(entries[1])), "direct identity ledger rejects duplicate return")
	var/obj/item/weapon/gun/projectile/submachinegun/ak47/next_gun = new(locate(1, 1, 1))
	next_gun.extraction_item_id = "mailgun73"
	var/list/next_entry = list("id" = "mailgun73", "equipment" = C.encode(next_gun), "returned_generation" = 1, "eligible_generation" = 2)
	qdel(next_gun)
	operations = mail.plan_append("mailowner", list(next_entry))
	P["operations"] = operations
	equipment_assert(operations && receipt.commit_profile("world", P) && mail.apply(operations), "append retains existing nine pages without backlog scan")
	equipment_assert(!mail.inspect("mailowner", 0, 2, cursor) && mail.last_error == "stale_cursor", "mutation explicitly rejects stale cursor")
	mail = new(S, C)
	var/list/index = mail.identity("mailgun73")
	equipment_assert(index && index["active"] && index["sequence"] == "10", "new instance reads exact identity shard and tenth page")
	equipment_assert(extraction_mail_next("99999999999999999") == "100000000000000000" && !extraction_mail_next("01"), "text page sequences preserve integer precision")
	equipment_assert(!mail.plan_claim("mailowner", list("mailgun1"), 1) && !mail.plan_claim("otherowner", list("mailgun1"), 2) && !mail.plan_claim("mailowner", list("mailgun1", "mailgun1"), 2), "pending foreign and repeated claims fail before debit")
	var/datum/extraction_session/A = S.open("mailowner")
	equipment_assert(A, "open native account for bounded claim")
	var/list/claim = mail.plan_claim("mailowner", list("mailgun1", "mailgun73"), 2)
	equipment_assert(claim && claim["entries"].len == 2, "direct claim selects two roots across separate pages")
	var/list/after = A.copy_profile()
	for (var/list/E in claim["entries"]) after["stash"] += list(E)
	S.store.test_fail_at = "intent"
	equipment_assert(!mail.transact(A, claim["operations"], after) && A.locked, "account intent interruption locks native claimant before materialization")
	S.store.test_fail_at = null
	A.close()
	mail = new(S, C)
	equipment_assert(mail.ready_owner("mailowner"), "durable claim receipt repairs exact account intent and mail debit")
	A = S.open("mailowner")
	equipment_assert(A && A.profile["stash"].len == 2 && A.profile["stash"][1]["id"] == "mailgun1", "reopen has exactly two original selected identities")
	equipment_assert(!mail.plan_claim("mailowner", list("mailgun1"), 2), "claimed original graph cannot debit twice")
	index = mail.identity("mailgun1")
	equipment_assert(index && !index["active"], "claimed identity ledger releases mail ownership")
	result = mail.inspect("mailowner", A.profile["revision"], 1000000, null)
	equipment_assert(result && result["entries"].len == 7, "large generation retains unclaimed mail without expiration deletion")
	A.close()
	var/datum/extraction_insurance_returns/gate = new(S, C)
	equipment_assert(gate.prepare("fixturelossround", list()), "native completed-round journal reaches loss generation")
	var/datum/extraction_ipc_service/ipc = new(S.store)
	ipc.enabled = TRUE
	ipc.key = "0123456789abcdef0123456789abcdef"
	equipment_assert(ipc.ready(), "isolated insurance IPC journal")
	ipc.profile["links"]["123"] = "mailowner"
	ipc.profile["owners"]["mailowner"] = "123"
	equipment_assert(ipc.commit(json_decode(json_encode(ipc.profile))), "synthetic linked actor is persisted")
	ipc.economic_adapter = new /datum/extraction_ipc_economy(S)
	var/datum/extraction_ipc_spool/spool = new(ipc)
	spool.root = "data/insurance_bot_fixture/spool/"
	spool.enabled = TRUE
	equipment_assert(spool.ready(), "explicit isolated insurance spool")
	var/list/requests = list()
	for (var/phase in list("pending", "eligible"))
		if (phase == "eligible") equipment_assert(gate.prepare("fixtureadditionalround", list()), "additional full native completion advances bot eligibility")
		var/request_id = "insurance-[phase]"
		var/list/current = S.store.load_profile("mailowner")
		var/list/request = economy_request("123", "insurance.inspect", request_id, current["revision"], list("cursor" = null))
		var/file_id = extraction_sha256(request_id)
		equipment_assert(text2file(economy_wire(ipc, request), spool.path(file_id, "request")) && spool.process(file_id, "1000"), "native spool signs authoritative insurance response")
		var/list/snapshot = ipc.profile["receipts"][file_id]["response"]
		equipment_assert(snapshot["status"] == "committed" && snapshot["data"]["entries"][1]["state"] == phase && snapshot["data"]["completed_generation"] == (phase == "pending" ? 1 : 2), "native signed inspection agrees with actual completed-round journal")
		requests[request_id] = file_id
	text2file(json_encode(list("synthetic" = TRUE, "protocol" = "civ13.safehouse.v1", "key" = ipc.key, "clock" = 1000, "requests" = requests)), "data/insurance_bot_fixture/manifest.json")
	spool.release()
